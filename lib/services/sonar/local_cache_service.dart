// lib/services/sonar/local_cache_service.dart
import 'dart:async'; // Import for Timer
import 'package:flutter/foundation.dart';
import 'package:freegram/blocs/connectivity_bloc.dart'; // Import for ConnectivityBloc
import 'package:freegram/locator.dart'; // Import for locator
import 'package:freegram/models/hive/nearby_user.dart';
import 'package:freegram/models/hive/user_profile.dart';
import 'package:freegram/models/hive/wave_record.dart';
import 'package:freegram/models/hive/friend_request_record.dart';
import 'package:freegram/services/sync_manager.dart'; // Import for SyncManager
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class LocalCacheService {
  late final Box<NearbyUser> _nearbyUsersBox;
  late final Box<UserProfile> _userProfilesBox;
  late final Box<WaveRecord> _pendingWavesBox;
  late final Box<FriendRequestRecord> _pendingFriendRequestsBox;

  // Cleanup duration for users - keep them for 24 hours after first discovery
  final Duration _userRetentionDuration = const Duration(hours: 24);

  // --- ADDED: Debounce timer for profile sync ---
  Timer? _syncDebounceTimer;
  final Duration _syncDebounceDuration =
      const Duration(milliseconds: 1500); // 1.5 seconds debounce

  LocalCacheService() {
    // Ensure boxes are opened in main.dart before this is instantiated
    _nearbyUsersBox = Hive.box<NearbyUser>('nearbyUsers');
    _userProfilesBox = Hive.box<UserProfile>('userProfiles');
    _pendingWavesBox = Hive.box<WaveRecord>('pendingWaves');
    _pendingFriendRequestsBox =
        Hive.box<FriendRequestRecord>('pendingFriendRequests');
  }

  // --- Nearby User Management ---
  Future<void> storeOrUpdateNearby(
      String uidShort, int gender, double distance) async {
    final now = DateTime.now();
    final existingUser = _nearbyUsersBox.get(uidShort);

    if (existingUser != null) {
      // Update existing user - keep foundAt unchanged, only update lastSeen
      final originalFoundAt = existingUser.foundAt;
      existingUser.distance = distance;
      existingUser.lastSeen = now;

      // Migration: if foundAt is not set (old data), set it to lastSeen
      if (existingUser.internalFoundAt == null) {
        existingUser.foundAt = now;
      }

      await existingUser.save();
      debugPrint(
          "LocalCacheService: UPDATING existing user $uidShort - foundAt unchanged=$originalFoundAt, lastSeen updated=$now");
    } else {
      // Create new user entry - set both foundAt and lastSeen to now
      final newUser = NearbyUser(
        uidShort: uidShort,
        gender: gender,
        distance: distance,
        lastSeen: now,
        foundAt: now, // Set foundAt when first discovered
        profileId: null, // Starts as null
      );
      await _nearbyUsersBox.put(uidShort, newUser);
      debugPrint(
          "LocalCacheService: NEW user discovered $uidShort with foundAt=$now (put complete)");

      // --- START: Profile Sync Delay Fix (#1 & #2) ---
      // When a NEW user is found, check connectivity and trigger sync if online
      final connectivityBloc = locator<ConnectivityBloc>();
      if (connectivityBloc.state is Online) {
        debugPrint(
            "LocalCacheService: New user discovered while online. Debouncing sync trigger.");
        _syncDebounceTimer?.cancel(); // Cancel any previous pending timer
        _syncDebounceTimer = Timer(_syncDebounceDuration, () {
          debugPrint(
              "LocalCacheService: Debounce timer fired. Triggering SyncManager.processQueue().");
          locator<SyncManager>().processQueue(); // Trigger sync after debounce
        });
      } else {
        debugPrint(
            "LocalCacheService: New user discovered while offline. Sync will trigger on reconnect.");
      }
      // --- END: Profile Sync Delay Fix ---
    }
  }

  ValueListenable<Box<NearbyUser>> getNearbyUsersListenable() {
    return _nearbyUsersBox.listenable();
  }

  Future<void> pruneStaleNearbyUsers() async {
    final now = DateTime.now();
    final keysToDelete = _nearbyUsersBox.keys.where((key) {
      final user = _nearbyUsersBox.get(key);
      if (user == null) return false;
      // Delete users older than 24 hours based on when they were first found
      final ageSinceFirstFound = now.difference(user.foundAt);
      return ageSinceFirstFound > _userRetentionDuration;
    }).toList();
    if (keysToDelete.isNotEmpty) {
      await _nearbyUsersBox.deleteAll(keysToDelete);
      debugPrint(
          "LocalCacheService: Pruned ${keysToDelete.length} users older than 24 hours.");
    }
  }

  Future<void> pruneSpecificUser(String uidShort) async {
    await _nearbyUsersBox.delete(uidShort);
    debugPrint("LocalCacheService: Pruned specific user $uidShort");
  }

  NearbyUser? getNearbyUser(String uidShort) {
    return _nearbyUsersBox.get(uidShort);
  }

  Future<void> markNearbyUserSynced(String uidShort, String profileId) async {
    final user = _nearbyUsersBox.get(uidShort);
    if (user != null) {
      user.profileId = profileId;
      await user.save();
      // --- DEBUG ---
      // debugPrint("LocalCacheService: Marked NearbyUser $uidShort as synced with profileId $profileId (save complete)"); // Updated log
      // --- END DEBUG ---
    } else {
      debugPrint(
          "LocalCacheService Warning: Tried to mark non-existent user $uidShort as synced.");
    }
  }

  // *** HELPER: Find user by full profile ID ***
  NearbyUser? getNearbyUserByProfileId(String profileId) {
    if (profileId.isEmpty) return null;

    // CRITICAL FIX: Detect if multiple nearby users have the same profileId!
    final matches = _nearbyUsersBox.values
        .where(
          (user) => user.profileId == profileId,
        )
        .toList();

    if (matches.isEmpty) {
      return null;
    }

    if (matches.length > 1) {
      debugPrint("❌ [CRITICAL BUG] DUPLICATE profileId mapping detected!");
      debugPrint("   profileId: $profileId");
      debugPrint(
          "   Found ${matches.length} nearby users with this profileId:");
      for (var match in matches) {
        debugPrint(
            "      - uidShort: ${match.uidShort}, gender: ${match.gender}, lastSeen: ${match.lastSeen}");
      }
      debugPrint(
          "   ⚠️  This will cause WRONG WAVE TARGETS! Returning the most recently seen one.");

      // Return the most recently seen user as best guess
      matches.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
      return matches.first;
    }

    return matches.first;
  }

  // *** HELPER: Get all users that haven't been synced (Defined in sync_manager.dart now) ***
  // List<NearbyUser> getUnsyncedNearbyUsers() { ... moved ... }
  // *** END HELPERS ***

  // --- User Profile Management ---
  Future<void> storeUserProfile(UserProfile profile) async {
    // --- DEBUG ---
    // debugPrint("LocalCacheService: Storing UserProfile for profileId: ${profile.profileId}, Name: ${profile.name}");
    // --- END DEBUG ---
    await _userProfilesBox.put(profile.profileId, profile);
    // debugPrint("LocalCacheService: Stored UserProfile for ${profile.profileId} (put complete)"); // Added log
  }

  ValueListenable<Box<UserProfile>> getUserProfilesListenable() {
    return _userProfilesBox.listenable();
  }

  UserProfile? getUserProfile(String profileId) {
    return _userProfilesBox.get(profileId);
  }

  // --- Wave Management ---
  Future<void> recordSentWave(
      {required String fromUidFull, required String toUidShort}) async {
    final wave = WaveRecord(
        fromUidFull: fromUidFull,
        toUidShort: toUidShort,
        timestamp: DateTime.now());
    await _pendingWavesBox.put(const Uuid().v4(), wave);
    debugPrint("LocalCacheService: Queued outgoing wave to $toUidShort");
  }

  Future<void> recordReceivedWave(String fromUidShort) {
    debugPrint("LocalCacheService: Logged received wave from $fromUidShort");
    // Maybe store received waves with timestamps for UI display?
    // For now, just logging.
    return Future.value();
  }

  Map<dynamic, WaveRecord> getPendingWaves() {
    return Map<dynamic, WaveRecord>.from(_pendingWavesBox.toMap());
  }

  Future<void> removeSentWave(dynamic key) async {
    await _pendingWavesBox.delete(key);
    debugPrint("LocalCacheService: Removed synced wave record $key");
  }

  // --- Friend Request Management ---
  Future<void> queueFriendRequest(
      {required String fromUserId, required String toUserId}) async {
    debugPrint(
        "LocalCacheService: Queuing friend request - From: $fromUserId, To: $toUserId (Type: ${toUserId.runtimeType})");
    final request = FriendRequestRecord(
        fromUserId: fromUserId, toUserId: toUserId, timestamp: DateTime.now());
    await _pendingFriendRequestsBox.put(const Uuid().v4(), request);
    debugPrint("LocalCacheService: Queued friend request successfully.");
  }

  Map<dynamic, FriendRequestRecord> getPendingFriendRequests() {
    final requests = Map<dynamic, FriendRequestRecord>.from(
        _pendingFriendRequestsBox.toMap());
    // debugPrint("LocalCacheService: Retrieved ${requests.length} pending friend requests.");
    return requests;
  }

  Future<void> removeFriendRequest(dynamic key) async {
    await _pendingFriendRequestsBox.delete(key);
    debugPrint("LocalCacheService: Removed synced friend request record $key");
  }

  // --- ADDED: Dispose method to cancel timer ---
  void dispose() {
    _syncDebounceTimer?.cancel();
    debugPrint("LocalCacheService: Disposed (timer cancelled).");
  }
}
