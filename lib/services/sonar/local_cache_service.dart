// lib/services/sonar/local_cache_service.dart
import 'package:flutter/foundation.dart';
import 'package:freegram/models/hive/nearby_user.dart';
import 'package:freegram/models/hive/user_profile.dart';
import 'package:freegram/models/hive/wave_record.dart';
import 'package:freegram/models/hive/friend_request_record.dart'; // Import the new model
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class LocalCacheService {
  late final Box<NearbyUser> _nearbyUsersBox;
  late final Box<UserProfile> _userProfilesBox;
  late final Box<WaveRecord> _pendingWavesBox;
  late final Box<FriendRequestRecord> _pendingFriendRequestsBox; // Box for friend requests

  // Constants for stale data cleanup
  final Duration _staleUserDuration = const Duration(minutes: 1); // Remove users not seen for 1 minute

  LocalCacheService() {
    // Boxes are assumed to be opened in main.dart
    _nearbyUsersBox = Hive.box<NearbyUser>('nearbyUsers');
    _userProfilesBox = Hive.box<UserProfile>('userProfiles');
    _pendingWavesBox = Hive.box<WaveRecord>('pendingWaves');
    _pendingFriendRequestsBox = Hive.box<FriendRequestRecord>('pendingFriendRequests'); // Initialize the box
  }

  // --- Nearby User Management ---

  /// Stores or updates a discovered user in the Hive box.
  /// Uses uidShort as the key.
  Future<void> storeOrUpdateNearby(String uidShort, int gender, double distance) async {
    final now = DateTime.now();
    final existingUser = _nearbyUsersBox.get(uidShort);

    if (existingUser != null) {
      // Update existing user
      existingUser.distance = distance;
      existingUser.lastSeen = now;
      // Profile ID remains unchanged here, sync manager updates it
      await existingUser.save();
      debugPrint("LocalCacheService: Updated NearbyUser $uidShort");
    } else {
      // Create new user entry
      final newUser = NearbyUser(
        uidShort: uidShort,
        gender: gender,
        distance: distance,
        lastSeen: now,
        // profileId starts as null
      );
      await _nearbyUsersBox.put(uidShort, newUser);
      debugPrint("LocalCacheService: Stored new NearbyUser $uidShort");
    }
  }

  /// Returns a ValueListenable for the nearbyUsers box, suitable for UI updates.
  ValueListenable<Box<NearbyUser>> getNearbyUsersListenable() {
    return _nearbyUsersBox.listenable();
  }

  /// Removes users who haven't been seen recently.
  Future<void> pruneStaleNearbyUsers() async {
    final now = DateTime.now();
    final List<String> keysToDelete = [];
    for (var key in _nearbyUsersBox.keys) {
      final user = _nearbyUsersBox.get(key);
      if (user != null && now.difference(user.lastSeen) > _staleUserDuration) {
        keysToDelete.add(key as String);
      }
    }
    if (keysToDelete.isNotEmpty) {
      await _nearbyUsersBox.deleteAll(keysToDelete);
      debugPrint("LocalCacheService: Pruned ${keysToDelete.length} stale users.");
    }
  }

  /// Gets a specific nearby user by their short ID.
  NearbyUser? getNearbyUser(String uidShort) {
    return _nearbyUsersBox.get(uidShort);
  }

  /// Updates the profile ID for a nearby user after successful sync.
  Future<void> markNearbyUserSynced(String uidShort, String profileId) async {
    final user = _nearbyUsersBox.get(uidShort);
    if (user != null) {
      user.profileId = profileId;
      await user.save();
      debugPrint("LocalCacheService: Marked NearbyUser $uidShort as synced with profileId $profileId");
    } else {
      debugPrint("LocalCacheService Warning: Tried to mark non-existent user $uidShort as synced.");
    }
  }


  Future<void> pruneSpecificUser(String uidShort) async {
    await _nearbyUsersBox.delete(uidShort);
    debugPrint("LocalCacheService: Pruned specific user $uidShort");
  }


  // --- User Profile Management ---

  /// Stores or updates a full user profile fetched from the server.
  /// Uses the full profileId (UUID) as the key.
  Future<void> storeUserProfile(UserProfile profile) async {
    await _userProfilesBox.put(profile.profileId, profile);
    debugPrint("LocalCacheService: Stored/Updated UserProfile ${profile.profileId}");
  }

  /// Returns a ValueListenable for the userProfiles box.
  ValueListenable<Box<UserProfile>> getUserProfilesListenable() {
    return _userProfilesBox.listenable();
  }

  /// Gets a specific user profile by their full ID.
  UserProfile? getUserProfile(String profileId) {
    return _userProfilesBox.get(profileId);
  }

  // --- Wave Management ---

  /// Records a wave sent by the current user (queued for sync).
  /// Generates a unique key for the record.
  Future<void> recordSentWave({required String fromUidFull, required String toUidShort}) async {
    final wave = WaveRecord(
      fromUidFull: fromUidFull,
      toUidShort: toUidShort,
      timestamp: DateTime.now(),
    );
    // Use a unique key for each pending wave
    await _pendingWavesBox.put(const Uuid().v4(), wave);
    debugPrint("LocalCacheService: Queued outgoing wave to $toUidShort");
  }

  /// Records that a wave was received from a nearby user.
  /// This might be used for local history or rate limiting notifications.
  Future<void> recordReceivedWave(String fromUidShort) async {
    // We aren't storing incoming waves for sync, but could add to a separate
    // 'wave_history' box if needed. For now, just log.
    debugPrint("LocalCacheService: Logged received wave from $fromUidShort");
    // Here you might trigger vibration or sound directly, or pass to NotificationService
  }


  /// Retrieves all pending outgoing waves for the sync manager.
  Map<dynamic, WaveRecord> getPendingWaves() {
    return _pendingWavesBox.toMap().cast<dynamic, WaveRecord>();
  }

  /// Removes a successfully synced wave record from the queue.
  Future<void> removeSentWave(dynamic key) async {
    await _pendingWavesBox.delete(key);
    debugPrint("LocalCacheService: Removed synced wave record $key");
  }

  // --- Friend Request Management (NEW) ---

  /// Queues an outgoing friend request for sync.
  Future<void> queueFriendRequest({required String fromUserId, required String toUserId}) async {
    final request = FriendRequestRecord(
      fromUserId: fromUserId,
      toUserId: toUserId,
      timestamp: DateTime.now(),
    );
    // Use a unique key for each pending request
    await _pendingFriendRequestsBox.put(const Uuid().v4(), request);
    debugPrint("LocalCacheService: Queued friend request from $fromUserId to $toUserId");
  }

  /// Retrieves all pending friend requests for the sync manager.
  Map<dynamic, FriendRequestRecord> getPendingFriendRequests() {
    return _pendingFriendRequestsBox.toMap().cast<dynamic, FriendRequestRecord>();
  }

  /// Removes a successfully synced friend request record from the queue.
  Future<void> removeFriendRequest(dynamic key) async {
    await _pendingFriendRequestsBox.delete(key);
    debugPrint("LocalCacheService: Removed synced friend request record $key");
  }

}