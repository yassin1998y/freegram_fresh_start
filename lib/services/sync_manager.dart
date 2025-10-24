// lib/services/sync_manager.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/sonar/local_cache_service.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/models/hive/nearby_user.dart';
import 'package:freegram/models/hive/user_profile.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:freegram/services/cache_manager_service.dart';
import 'package:collection/collection.dart';
// ** NEW IMPORT FOR USERMODEL **
import 'package:freegram/models/user_model.dart';


class SyncManager {
  final ConnectivityBloc _connectivityBloc;
  final LocalCacheService _localCacheService = locator<LocalCacheService>();
  final UserRepository _userRepository = locator<UserRepository>();

  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  Timer? _syncDebounceTimer;

  SyncManager({required ConnectivityBloc connectivityBloc})
      : _connectivityBloc = connectivityBloc {
    _connectivitySubscription = _connectivityBloc.stream.listen((state) {
      if (state is Online) {
        _syncDebounceTimer?.cancel();
        // Debounce sync to avoid rapid triggers on flaky connections
        _syncDebounceTimer = Timer(const Duration(seconds: 3), processQueue);
      } else {
        // Cancel any pending sync if connection drops
        _syncDebounceTimer?.cancel();
      }
    });
    // Initial sync check if already online
    if (_connectivityBloc.state is Online) {
      Future.delayed(const Duration(seconds: 5), processQueue);
    }
  }

  Future<void> processQueue() async {
    debugPrint("SyncManager: processQueue called. IsSyncing: $_isSyncing, State: ${_connectivityBloc.state}");

    if (_isSyncing) {
      debugPrint("SyncManager: Sync already in progress. Skipping.");
      return;
    }
    // Double-check connectivity state before starting
    if (_connectivityBloc.state is! Online) {
      debugPrint("SyncManager: Skipping sync, connection lost before starting.");
      return;
    }

    _isSyncing = true;
    debugPrint("SyncManager: Starting sync process...");

    try {
      // Prioritize syncing profiles as other actions might depend on resolved IDs
      await _syncProfiles();
      // Sync friend requests (needs resolved IDs from _syncProfiles)
      await _syncFriendRequests();
      // Sync waves (needs resolved IDs from _syncProfiles)
      await _syncWaves();
      // Add other sync actions here if needed in the future
    } catch (e) {
      debugPrint("SyncManager: Error during sync process: $e");
    } finally {
      _isSyncing = false;
      debugPrint("SyncManager: Sync process finished.");
      // Check if more work remains and schedule another attempt if online
      if (_connectivityBloc.state is Online) {
        if (_localCacheService.getPendingFriendRequests().isNotEmpty ||
            _localCacheService.getPendingWaves().isNotEmpty ||
            _localCacheService.getUnsyncedNearbyUsers().isNotEmpty) {
          debugPrint("SyncManager: Some items failed to sync or new items appeared. Will retry later.");
          // Optionally schedule another check after a delay:
          // _syncDebounceTimer?.cancel();
          // _syncDebounceTimer = Timer(const Duration(seconds: 30), processQueue);
        }
      }
    }
  }

  /// Fetches full profiles for locally discovered users from Firestore.
  Future<void> _syncProfiles() async {
    debugPrint("SyncManager: _syncProfiles started.");
    final List<NearbyUser> unsyncedUsers = _localCacheService.getUnsyncedNearbyUsers();
    // Get unique short IDs that need syncing
    final List<String> uidShortsToSync = unsyncedUsers.map((user) => user.uidShort).toSet().toList();

    if (uidShortsToSync.isEmpty) {
      debugPrint("SyncManager: No new profiles to sync.");
      return;
    }

    debugPrint("SyncManager: Found ${uidShortsToSync.length} profiles to sync: $uidShortsToSync");

    try {
      // Fetch user data from Firestore using UserRepository
      final Map<String, UserModel> fetchedProfiles = await _userRepository.getUsersByUidShorts(uidShortsToSync);
      debugPrint("SyncManager: Received profile data from Firestore: ${fetchedProfiles.length} entries.");

      if (fetchedProfiles.isEmpty) {
        debugPrint("SyncManager: Firestore returned no profile data for requested uidShorts.");
        // Optional: Mark these uidShorts as 'not found' locally to avoid retrying?
        return;
      }

      // Process the fetched profiles
      for (var entry in fetchedProfiles.entries) {
        final uidShort = entry.key;
        final userModel = entry.value;

        debugPrint("SyncManager: Processing profile for uidShort: $uidShort, UserID: ${userModel.id}");

        // Create UserProfile Hive object
        final userProfile = UserProfile(
          profileId: userModel.id, // Full UUID from server
          name: userModel.username,
          photoUrl: userModel.photoUrl,
          updatedAt: DateTime.now(), // Use current time as update time
          // Map other relevant fields from UserModel
          // Note: Level and XP are removed from UserModel, use defaults or 0 if needed in UserProfile
          level: 0, // Default or remove if not needed in UserProfile
          xp: 0, // Default or remove if not needed in UserProfile
          interests: userModel.interests,
          friends: userModel.friends,
          gender: userModel.gender,
          nearbyStatusMessage: userModel.nearbyStatusMessage,
          nearbyStatusEmoji: userModel.nearbyStatusEmoji,
          friendRequestsSent: userModel.friendRequestsSent,
          friendRequestsReceived: userModel.friendRequestsReceived,
          blockedUsers: userModel.blockedUsers,
        );

        // Store UserProfile in Hive
        await _localCacheService.storeUserProfile(userProfile);

        // Update the corresponding NearbyUser in Hive to link it via profileId
        await _localCacheService.markNearbyUserSynced(uidShort, userModel.id);

        // Pre-cache the profile image
        if (userProfile.photoUrl.isNotEmpty) {
          // Assuming CacheManagerService is accessible via locator
          locator<CacheManagerService>().preCacheImage(userProfile.photoUrl);
        }
      }
      debugPrint("SyncManager: Profile sync completed.");

    } catch (e) {
      debugPrint("SyncManager Error: Failed to sync profiles: $e");
      // Errors here mean profiles remain unsynced and will be retried
    }
  }


  Future<void> _syncFriendRequests() async {
    debugPrint("SyncManager: Syncing Friend Requests...");
    final pendingRequests = _localCacheService.getPendingFriendRequests();

    if (pendingRequests.isEmpty) {
      debugPrint("SyncManager: No pending friend requests to sync.");
      return;
    }

    debugPrint("SyncManager: Found ${pendingRequests.length} friend requests to sync.");

    final requestKeys = pendingRequests.keys.toList(); // Get keys to iterate safely

    for (final key in requestKeys) {
      // Check connection before processing each item
      if (_connectivityBloc.state is! Online) {
        debugPrint("SyncManager: Connection lost during friend request sync. Aborting.");
        return;
      }

      final request = pendingRequests[key]!;
      final String fromUserId = request.fromUserId; // Sender's full UUID
      final String targetIdFromQueue = request.toUserId; // Could be short ID or full UUID

      try {
        String targetFullUuid;

        // Check if the stored ID is already a full UUID (basic length check)
        if (targetIdFromQueue.length > 10) { // Adjust length threshold if needed
          targetFullUuid = targetIdFromQueue;
          debugPrint("SyncManager: Friend request target ID $targetFullUuid seems to be a full UUID already.");
        } else {
          // Assume it's a short ID and resolve it
          final String targetUidShort = targetIdFromQueue;
          debugPrint("SyncManager: Friend request target ID $targetUidShort is a short ID. Resolving...");
          // Find the NearbyUser record using the short ID
          final nearbyUser = _localCacheService.getNearbyUser(targetUidShort);
          // Check if the profile has been synced (profileId is the full UUID)
          if (nearbyUser?.profileId == null) {
            debugPrint("SyncManager Warning: Profile for target uidShort $targetUidShort not synced yet. Skipping friend request (Key: $key). Will retry later.");
            continue; // Skip this request for now, wait for profile sync
          }
          targetFullUuid = nearbyUser!.profileId!; // Use the resolved full UUID
          debugPrint("SyncManager: Resolved uidShort $targetUidShort to full UUID $targetFullUuid.");
        }

        debugPrint("SyncManager: Attempting to sync friend request via repo - From: $fromUserId, To (Resolved): $targetFullUuid");

        // Call UserRepository to send the request using full UUIDs
        await _userRepository.sendFriendRequest(
          fromUserId,
          targetFullUuid, // Pass the resolved full UUID
          isSync: true, // Indicate this is from the sync manager
        );
        // If successful, remove from the local queue
        await _localCacheService.removeFriendRequest(key);
        debugPrint("SyncManager: Successfully synced friend request (Key: $key).");

      } catch (e) {
        // Log the error but keep the item in the queue for the next sync attempt
        debugPrint("SyncManager Error: Failed to sync friend request (Key: $key). Repo Error: $e. It will be retried on next connection.");
        // Consider specific error handling (e.g., if user doesn't exist, remove from queue?)
      }
    }
    debugPrint("SyncManager: Friend request sync completed.");
  }


  /// Sends pending waves to the server by adding Firestore notifications.
  Future<void> _syncWaves() async {
    debugPrint("SyncManager: Syncing Waves...");
    final pendingWaves = _localCacheService.getPendingWaves();

    if (pendingWaves.isEmpty) {
      debugPrint("SyncManager: No pending waves to sync.");
      return;
    }

    debugPrint("SyncManager: Found ${pendingWaves.length} waves to sync.");

    final waveKeys = pendingWaves.keys.toList(); // Get keys for safe iteration

    for (final key in waveKeys) {
      // Check connection status before processing each wave
      if (_connectivityBloc.state is! Online) {
        debugPrint("SyncManager: Connection lost during wave sync. Aborting.");
        return;
      }
      final wave = pendingWaves[key]!;
      final String fromUserId = wave.fromUidFull; // Sender's full UUID
      final String targetUidShort = wave.toUidShort; // Target's short ID

      try {
        // Resolve the target's short ID to a full UUID
        debugPrint("SyncManager: Wave target ID $targetUidShort is a short ID. Resolving...");
        final nearbyUser = _localCacheService.getNearbyUser(targetUidShort);
        // Check if the profile is synced (has profileId/full UUID)
        if (nearbyUser?.profileId == null) {
          debugPrint("SyncManager Warning: Profile for target uidShort $targetUidShort not synced yet. Skipping wave (Key: $key). Will retry later.");
          continue; // Skip this wave, wait for profile sync
        }
        final targetFullUuid = nearbyUser!.profileId!; // Use the resolved full UUID
        debugPrint("SyncManager: Resolved uidShort $targetUidShort to full UUID $targetFullUuid for wave.");

        debugPrint("SyncManager: Syncing wave via repo from $fromUserId to $targetFullUuid");
        // Call UserRepository's sendWave which now handles server notification
        await _userRepository.sendWave(fromUserId, targetFullUuid);

        // If successful, remove the wave from the local pending queue
        await _localCacheService.removeSentWave(key);
        debugPrint("SyncManager: Successfully synced wave (Key: $key).");

      } catch (e) {
        // Log error, keep wave in queue for retry
        debugPrint("SyncManager Error: Failed to sync wave (Key: $key). Error: $e");
      }
    }
    debugPrint("SyncManager: Wave sync completed.");
  }


  void dispose() {
    _connectivitySubscription?.cancel();
    _syncDebounceTimer?.cancel();
    debugPrint("SyncManager: Disposed.");
  }
}

// Helper extensions
extension CacheManagerExt on CacheManagerService {
  Future<void> preCacheImage(String url) async {
    if (url.isEmpty) return;
    try {
      // Use the configured manager from CacheManagerService
      await manager.downloadFile(url);
      // debugPrint("CacheManagerService: Pre-cached image $url"); // Optional success log
    } catch (e) {
      debugPrint("CacheManagerService: Error pre-caching image $url: $e");
    }
  }
}

// Keep this extension with LocalCacheService methods
extension LocalCacheServiceHelper on LocalCacheService {
  // Find a NearbyUser based on their full profile ID (server UUID)
  NearbyUser? getNearbyUserByProfileId(String profileId) {
    if (profileId.isEmpty) return null;
    final box = Hive.box<NearbyUser>('nearbyUsers');
    try {
      // Use collection package's firstWhereOrNull for safety
      return box.values.firstWhereOrNull(
            (user) => user.profileId == profileId,
      );
    } catch (e) {
      // Catch potential Hive errors during access
      debugPrint("LocalCacheServiceHelper Error (getNearbyUserByProfileId): $e");
      return null;
    }
  }

  // Get a list of NearbyUser entries that haven't been linked to a server profile yet
  List<NearbyUser> getUnsyncedNearbyUsers() {
    final box = Hive.box<NearbyUser>('nearbyUsers');
    // Filter users where profileId is null or empty
    final unsynced = box.values.where((user) => user.profileId == null || user.profileId!.isEmpty).toList();
    debugPrint("LocalCacheServiceHelper: Found ${unsynced.length} unsynced users out of ${box.length}.");
    return unsynced;
  }
}