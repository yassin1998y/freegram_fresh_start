// lib/services/sync_manager.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/sonar/local_cache_service.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/models/hive/nearby_user.dart';
import 'package:freegram/models/hive/user_profile.dart';
// *** ADDED IMPORTS ***
import 'package:hive_flutter/hive_flutter.dart';
import 'package:freegram/services/cache_manager_service.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull
// *** END ADDED IMPORTS ***


class SyncManager {
  final ConnectivityBloc _connectivityBloc;
  final LocalCacheService _localCacheService = locator<LocalCacheService>();
  final UserRepository _userRepository = locator<UserRepository>();
  // TODO: Add repository/service for backend calls (e.g., _backendService)

  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  Timer? _syncDebounceTimer; // Debounce sync calls

  SyncManager({required ConnectivityBloc connectivityBloc})
      : _connectivityBloc = connectivityBloc {
    _connectivitySubscription = _connectivityBloc.stream.listen((state) {
      if (state is Online) {
        // Debounce the sync call slightly to avoid rapid triggers if connection flaps
        _syncDebounceTimer?.cancel();
        _syncDebounceTimer = Timer(const Duration(seconds: 3), processQueue);
      } else {
        _syncDebounceTimer?.cancel(); // Cancel pending sync if we go offline
      }
    });
    // Trigger initial sync check shortly after app start if already online
    if (_connectivityBloc.state is Online) {
      Future.delayed(const Duration(seconds: 5), processQueue);
    }
  }

  /// Processes all pending offline actions (profiles, waves, friend requests).
  Future<void> processQueue() async {
    if (_isSyncing) {
      debugPrint("SyncManager: Sync already in progress. Skipping.");
      return;
    }
    // Double check connectivity before starting expensive operations
    if (_connectivityBloc.state is! Online) {
      debugPrint("SyncManager: Skipping sync, connection lost before starting.");
      return;
    }

    _isSyncing = true;
    debugPrint("SyncManager: Starting sync process...");

    // Order: Profiles -> Friend Requests -> Waves (or customize as needed)
    try {
      await _syncProfiles();
      await _syncFriendRequests();
      await _syncWaves();
    } catch (e) {
      debugPrint("SyncManager: Error during sync process: $e");
      // Consider more robust error handling/reporting
    } finally {
      _isSyncing = false;
      debugPrint("SyncManager: Sync process finished.");
      // Check if still online and if there are more items (optional re-queue check)
      if (_connectivityBloc.state is Online) {
        // Check if boxes still have pending items due to errors during sync
        if (_localCacheService.getPendingFriendRequests().isNotEmpty ||
            _localCacheService.getPendingWaves().isNotEmpty ||
            _localCacheService.getUnsyncedNearbyUsers().isNotEmpty) { // Use helper
          debugPrint("SyncManager: Some items failed to sync or new items appeared. Will retry later.");
        }
      }
    }
  }

  /// Fetches full profiles for locally discovered users.
  Future<void> _syncProfiles() async {
    debugPrint("SyncManager: Syncing Profiles...");
    // 1. Get uidShorts that need syncing (using helper)
    final List<String> uidShortsToSync = _localCacheService.getUnsyncedNearbyUsers()
        .map((user) => user.uidShort)
        .toSet() // Use toSet to avoid duplicates
        .toList();

    if (uidShortsToSync.isEmpty) {
      debugPrint("SyncManager: No new profiles to sync.");
      return;
    }

    debugPrint("SyncManager: Found ${uidShortsToSync.length} profiles to sync: $uidShortsToSync");

    try {
      // 2. TODO: Call backend API (POST /profiles/batch)
      // Replace with your actual API call structure
      // Your backend MUST return all the fields we added to UserProfile
      await Future.delayed(const Duration(seconds: 1)); // Simulate network
      final Map<String, Map<String, dynamic>> profilesData = {
        for (var uidShort in uidShortsToSync)
          uidShort: {
            'id': 'FULL-UUID-FOR-$uidShort', // Server's full user ID
            'name': 'Synced ${uidShort.substring(0, 4)}',
            'photoUrl': 'https://i.pravatar.cc/150?u=$uidShort', // Use a dynamic placeholder
            // --- Populate ALL new fields (from backend) ---
            'level': (uidShort.hashCode % 10) + 1,
            'xp': (uidShort.hashCode % 1000) * 5,
            'interests': (uidShort.hashCode % 3 == 0) ? ['Gaming', 'Movies'] : ['Traveling'],
            'friends': <String>[], // Example: ['friend-uuid-1', 'friend-uuid-2']
            'gender': (uidShort.hashCode % 2 == 0) ? 'Male' : 'Female',
            'nearbyStatusMessage': 'Just chillin\'',
            'nearbyStatusEmoji': '😎',
            'friendRequestsSent': <String>[],
            'friendRequestsReceived': <String>[],
            'blockedUsers': <String>[],
          }
      };
      // --- END MOCK RESPONSE ---


      if (profilesData.isEmpty) {
        debugPrint("SyncManager: Backend returned no profile data for requested IDs.");
        return;
      }

      debugPrint("SyncManager: Received profile data for ${profilesData.length} users.");

      // 3. Process the response
      for (var entry in profilesData.entries) {
        final uidShort = entry.key;
        final profileData = entry.value;

        // Basic validation
        if (profileData['id'] == null || profileData['name'] == null) {
          debugPrint("SyncManager Warning: Received incomplete profile data for $uidShort");
          continue;
        }

        final fullProfileId = profileData['id'] as String;

        // 4. Create UserProfile with all cached fields
        final userProfile = UserProfile(
          profileId: fullProfileId,
          name: profileData['name'] as String,
          photoUrl: profileData['photoUrl'] as String? ?? '',
          updatedAt: DateTime.now(),
          // Populate new fields
          level: profileData['level'] as int? ?? 1,
          xp: profileData['xp'] as int? ?? 0,
          interests: List<String>.from(profileData['interests'] ?? []),
          friends: List<String>.from(profileData['friends'] ?? []),
          gender: profileData['gender'] as String? ?? '',
          nearbyStatusMessage: profileData['nearbyStatusMessage'] as String? ?? '',
          nearbyStatusEmoji: profileData['nearbyStatusEmoji'] as String? ?? '',
          friendRequestsSent: List<String>.from(profileData['friendRequestsSent'] ?? []),
          friendRequestsReceived: List<String>.from(profileData['friendRequestsReceived'] ?? []),
          blockedUsers: List<String>.from(profileData['blockedUsers'] ?? []),
        );

        // 5. Store UserProfile in Hive
        await _localCacheService.storeUserProfile(userProfile);

        // 6. Update NearbyUser in Hive to link it
        await _localCacheService.markNearbyUserSynced(uidShort, fullProfileId);

        // 7. (Optional but recommended) Pre-cache the image
        if (userProfile.photoUrl.isNotEmpty) {
          locator<CacheManagerService>().preCacheImage(userProfile.photoUrl);
        }
      }
      debugPrint("SyncManager: Profile sync completed.");

    } catch (e) {
      debugPrint("SyncManager Error: Failed to sync profiles: $e");
      // Don't clear the list, allow retry on next sync cycle
    }
  }

  /// Sends pending friend requests to the server.
  Future<void> _syncFriendRequests() async {
    debugPrint("SyncManager: Syncing Friend Requests...");
    final pendingRequests = _localCacheService.getPendingFriendRequests();

    if (pendingRequests.isEmpty) {
      debugPrint("SyncManager: No pending friend requests to sync.");
      return;
    }

    debugPrint("SyncManager: Found ${pendingRequests.length} friend requests to sync.");

    // Create a copy of keys to iterate over, allowing safe deletion
    final requestKeys = pendingRequests.keys.toList();

    for (final key in requestKeys) {
      // Check connectivity before each attempt (optional, but safer)
      if (_connectivityBloc.state is! Online) {
        debugPrint("SyncManager: Connection lost during friend request sync. Aborting.");
        return; // Stop syncing if connection drops
      }

      final request = pendingRequests[key]!;
      try {
        debugPrint("SyncManager: Syncing friend request from ${request.fromUserId} to ${request.toUserId}");
        // Call UserRepository's method, marking it as a sync operation
        await _userRepository.sendFriendRequest(
          request.fromUserId,
          request.toUserId,
          isSync: true, // IMPORTANT: Prevents re-queuing
        );

        // If successful, remove from the local queue
        await _localCacheService.removeFriendRequest(key);
        debugPrint("SyncManager: Successfully synced friend request (Key: $key).");

      } catch (e) {
        debugPrint("SyncManager Error: Failed to sync friend request (Key: $key). Error: $e. It will be retried on next connection.");
        // Keep the request in the queue for the next sync attempt
      }
    }
    debugPrint("SyncManager: Friend request sync completed.");
  }


  /// Sends pending waves to the server.
  Future<void> _syncWaves() async {
    debugPrint("SyncManager: Syncing Waves...");
    final pendingWaves = _localCacheService.getPendingWaves();

    if (pendingWaves.isEmpty) {
      debugPrint("SyncManager: No pending waves to sync.");
      return;
    }

    debugPrint("SyncManager: Found ${pendingWaves.length} waves to sync.");

    // Create a copy of keys for safe iteration
    final waveKeys = pendingWaves.keys.toList();

    for (final key in waveKeys) {
      if (_connectivityBloc.state is! Online) {
        debugPrint("SyncManager: Connection lost during wave sync. Aborting.");
        return;
      }
      final wave = pendingWaves[key]!;
      try {
        debugPrint("SyncManager: Syncing wave from ${wave.fromUidFull} to ${wave.toUidShort}");
        // TODO: Call your backend API (POST /waves)
        // Example: await _backendService.syncWave(wave.fromUidFull, wave.toUidShort, wave.timestamp);
        // --- MOCK API CALL ---
        await Future.delayed(const Duration(milliseconds: 100)); // Simulate network
        // if (wave.toUidShort.contains('fail')) throw Exception("Mock wave sync failure"); // Simulate failure
        // --- END MOCK ---


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

// Helper extension for CacheManagerService
extension CacheManagerExt on CacheManagerService {
  Future<void> preCacheImage(String url) async {
    if (url.isEmpty) return; // Add null/empty check
    try {
      // Use the 'manager' getter from your CacheManagerService
      await manager.downloadFile(url);
      // debugPrint("CacheManagerService: Pre-cached image: $url"); // Reduce log noise
    } catch (e) {
      debugPrint("CacheManagerService: Error pre-caching image $url: $e");
    }
  }
}

// Helper extension for LocalCacheService (fixes 'firstWhereOrNull' error)
extension LocalCacheServiceHelper on LocalCacheService {
  /// Finds a NearbyUser based on their full profile ID.
  NearbyUser? getNearbyUserByProfileId(String profileId) {
    if (profileId.isEmpty) return null;
    final box = Hive.box<NearbyUser>('nearbyUsers');
    try {
      // Use firstWhereOrNull from the collection package
      return box.values.firstWhereOrNull(
            (user) => user.profileId == profileId,
      );
    } catch (e) {
      // Catch potential errors during iteration
      debugPrint("getNearbyUserByProfileId Error: $e");
      return null;
    }
  }

  /// Gets all users that haven't been synced (profileId is null)
  List<NearbyUser> getUnsyncedNearbyUsers() {
    final box = Hive.box<NearbyUser>('nearbyUsers');
    return box.values.where((user) => user.profileId == null).toList();
  }
}