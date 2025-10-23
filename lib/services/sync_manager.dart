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
        _syncDebounceTimer = Timer(const Duration(seconds: 3), processQueue);
      } else {
        _syncDebounceTimer?.cancel();
      }
    });
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
    if (_connectivityBloc.state is! Online) {
      debugPrint("SyncManager: Skipping sync, connection lost before starting.");
      return;
    }

    _isSyncing = true;
    debugPrint("SyncManager: Starting sync process...");

    try {
      await _syncProfiles();
      await _syncFriendRequests();
      await _syncWaves(); // Waves depend on profile sync to resolve target ID
    } catch (e) {
      debugPrint("SyncManager: Error during sync process: $e");
    } finally {
      _isSyncing = false;
      debugPrint("SyncManager: Sync process finished.");
      if (_connectivityBloc.state is Online) {
        if (_localCacheService.getPendingFriendRequests().isNotEmpty ||
            _localCacheService.getPendingWaves().isNotEmpty ||
            _localCacheService.getUnsyncedNearbyUsers().isNotEmpty) {
          debugPrint("SyncManager: Some items failed to sync or new items appeared. Will retry later.");
        }
      }
    }
  }

  /// Fetches full profiles for locally discovered users from Firestore.
  Future<void> _syncProfiles() async {
    debugPrint("SyncManager: _syncProfiles started.");
    final List<NearbyUser> unsyncedUsers = _localCacheService.getUnsyncedNearbyUsers();
    final List<String> uidShortsToSync = unsyncedUsers.map((user) => user.uidShort).toSet().toList();

    if (uidShortsToSync.isEmpty) {
      debugPrint("SyncManager: No new profiles to sync.");
      return;
    }

    debugPrint("SyncManager: Found ${uidShortsToSync.length} profiles to sync: $uidShortsToSync");

    try {
      // --- REAL FIRESTORE CALL ---
      // Call the new method in UserRepository
      final Map<String, UserModel> fetchedProfiles = await _userRepository.getUsersByUidShorts(uidShortsToSync);
      // --- END REAL FIRESTORE CALL ---

      debugPrint("SyncManager: Received profile data from Firestore: ${fetchedProfiles.length} entries.");

      if (fetchedProfiles.isEmpty) {
        debugPrint("SyncManager: Firestore returned no profile data for requested uidShorts.");
        // Optional: Mark these uidShorts as 'not found' locally to avoid retrying?
        return;
      }

      // 3. Process the response
      for (var entry in fetchedProfiles.entries) {
        // Here, entry.key is uidShort, entry.value is the UserModel
        final uidShort = entry.key;
        final userModel = entry.value;

        debugPrint("SyncManager: Processing profile for uidShort: $uidShort, UserID: ${userModel.id}");

        // Create UserProfile based on the fetched UserModel
        final userProfile = UserProfile(
          profileId: userModel.id, // Use the full ID from UserModel
          name: userModel.username,
          photoUrl: userModel.photoUrl,
          updatedAt: DateTime.now(), // Or use a timestamp from UserModel if available/relevant
          level: userModel.level,
          xp: userModel.xp,
          interests: userModel.interests,
          friends: userModel.friends,
          gender: userModel.gender,
          nearbyStatusMessage: userModel.nearbyStatusMessage,
          nearbyStatusEmoji: userModel.nearbyStatusEmoji,
          friendRequestsSent: userModel.friendRequestsSent,
          friendRequestsReceived: userModel.friendRequestsReceived,
          blockedUsers: userModel.blockedUsers,
        );

        // 5. Store UserProfile in Hive
        await _localCacheService.storeUserProfile(userProfile);

        // 6. Update NearbyUser in Hive to link it
        await _localCacheService.markNearbyUserSynced(uidShort, userModel.id); // Use the full ID

        // 7. Pre-cache the image
        if (userProfile.photoUrl.isNotEmpty) {
          locator<CacheManagerService>().preCacheImage(userProfile.photoUrl);
        }
      }
      debugPrint("SyncManager: Profile sync completed.");

    } catch (e) {
      debugPrint("SyncManager Error: Failed to sync profiles: $e");
    }
  }


  Future<void> _syncFriendRequests() async {
    // ... (This method remains the same as the previous version with the fix for resolving uidShort) ...
    debugPrint("SyncManager: Syncing Friend Requests...");
    final pendingRequests = _localCacheService.getPendingFriendRequests();

    if (pendingRequests.isEmpty) {
      debugPrint("SyncManager: No pending friend requests to sync.");
      return;
    }

    debugPrint("SyncManager: Found ${pendingRequests.length} friend requests to sync.");

    final requestKeys = pendingRequests.keys.toList();

    for (final key in requestKeys) {
      if (_connectivityBloc.state is! Online) {
        debugPrint("SyncManager: Connection lost during friend request sync. Aborting.");
        return;
      }

      final request = pendingRequests[key]!;
      final String fromUserId = request.fromUserId;
      final String targetIdFromQueue = request.toUserId;

      try {
        String targetFullUuid;

        if (targetIdFromQueue.length > 10) {
          targetFullUuid = targetIdFromQueue;
          debugPrint("SyncManager: Friend request target ID $targetFullUuid seems to be a full UUID already.");
        } else {
          final String targetUidShort = targetIdFromQueue;
          debugPrint("SyncManager: Friend request target ID $targetUidShort is a short ID. Resolving...");
          final nearbyUser = _localCacheService.getNearbyUser(targetUidShort);
          if (nearbyUser?.profileId == null) {
            debugPrint("SyncManager Warning: Profile for target uidShort $targetUidShort not synced yet. Skipping friend request (Key: $key). Will retry later.");
            continue;
          }
          targetFullUuid = nearbyUser!.profileId!;
          debugPrint("SyncManager: Resolved uidShort $targetUidShort to full UUID $targetFullUuid.");
        }

        debugPrint("SyncManager: Attempting to sync friend request via repo - From: $fromUserId, To (Resolved): $targetFullUuid");

        await _userRepository.sendFriendRequest(
          fromUserId,
          targetFullUuid,
          isSync: true,
        );
        await _localCacheService.removeFriendRequest(key);
        debugPrint("SyncManager: Successfully synced friend request (Key: $key).");

      } catch (e) {
        debugPrint("SyncManager Error: Failed to sync friend request (Key: $key). Repo Error: $e. It will be retried on next connection.");
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

    final waveKeys = pendingWaves.keys.toList();

    for (final key in waveKeys) {
      if (_connectivityBloc.state is! Online) {
        debugPrint("SyncManager: Connection lost during wave sync. Aborting.");
        return;
      }
      final wave = pendingWaves[key]!;
      final String fromUserId = wave.fromUidFull;
      final String targetUidShort = wave.toUidShort;

      try {
        // --- RESOLVE TARGET ID ---
        debugPrint("SyncManager: Wave target ID $targetUidShort is a short ID. Resolving...");
        final nearbyUser = _localCacheService.getNearbyUser(targetUidShort);
        if (nearbyUser?.profileId == null) {
          debugPrint("SyncManager Warning: Profile for target uidShort $targetUidShort not synced yet. Skipping wave (Key: $key). Will retry later.");
          continue; // Skip this wave for now
        }
        final targetFullUuid = nearbyUser!.profileId!;
        debugPrint("SyncManager: Resolved uidShort $targetUidShort to full UUID $targetFullUuid for wave.");
        // --- END RESOLVE ---


        debugPrint("SyncManager: Syncing wave via repo from $fromUserId to $targetFullUuid");
        // --- CALL USER REPOSITORY'S sendWave ---
        await _userRepository.sendWave(fromUserId, targetFullUuid);
        // --- END CALL ---


        // If successful, remove from local queue
        await _localCacheService.removeSentWave(key);
        debugPrint("SyncManager: Successfully synced wave (Key: $key).");

      } catch (e) {
        debugPrint("SyncManager Error: Failed to sync wave (Key: $key). Error: $e");
        // Keep in queue for retry
      }
    }
    debugPrint("SyncManager: Wave sync completed.");
  }


  void dispose() {
    _connectivitySubscription?.cancel();
    _syncDebounceTimer?.cancel();
  }
}

// Helper extensions remain the same
extension CacheManagerExt on CacheManagerService {
  Future<void> preCacheImage(String url) async {
    if (url.isEmpty) return;
    try {
      await manager.downloadFile(url);
    } catch (e) {
      debugPrint("CacheManagerService: Error pre-caching image $url: $e");
    }
  }
}

extension LocalCacheServiceHelper on LocalCacheService {
  NearbyUser? getNearbyUserByProfileId(String profileId) {
    if (profileId.isEmpty) return null;
    final box = Hive.box<NearbyUser>('nearbyUsers');
    try {
      return box.values.firstWhereOrNull(
            (user) => user.profileId == profileId,
      );
    } catch (e) {
      debugPrint("LocalCacheServiceHelper Error (getNearbyUserByProfileId): $e");
      return null;
    }
  }

  List<NearbyUser> getUnsyncedNearbyUsers() {
    final box = Hive.box<NearbyUser>('nearbyUsers');
    debugPrint("LocalCacheServiceHelper: Checking for unsynced users. Box size: ${box.values.length}");
    final users = box.values.toList();
    final unsynced = <NearbyUser>[];
    for(var user in users) {
      debugPrint("LocalCacheServiceHelper: Checking user ${user.uidShort}, profileId: ${user.profileId}");
      if(user.profileId == null) {
        unsynced.add(user);
      }
    }
    debugPrint("LocalCacheServiceHelper: Found ${unsynced.length} unsynced users.");
    return unsynced;
  }
}