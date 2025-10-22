// lib/services/sonar/local_cache_service.dart
import 'package:flutter/foundation.dart';
import 'package:freegram/models/hive/nearby_user.dart';
import 'package:freegram/models/hive/user_profile.dart';
import 'package:freegram/models/hive/wave_record.dart';
import 'package:freegram/models/hive/friend_request_record.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
// Import collection package for firstWhereOrNull
import 'package:collection/collection.dart';


class LocalCacheService {
  late final Box<NearbyUser> _nearbyUsersBox;
  late final Box<UserProfile> _userProfilesBox;
  late final Box<WaveRecord> _pendingWavesBox;
  late final Box<FriendRequestRecord> _pendingFriendRequestsBox;

  // Cleanup duration for users not seen in BLE scans
  final Duration _staleUserDuration = const Duration(minutes: 1);

  LocalCacheService() {
    // Ensure boxes are opened in main.dart before this is instantiated
    _nearbyUsersBox = Hive.box<NearbyUser>('nearbyUsers');
    _userProfilesBox = Hive.box<UserProfile>('userProfiles');
    _pendingWavesBox = Hive.box<WaveRecord>('pendingWaves');
    _pendingFriendRequestsBox = Hive.box<FriendRequestRecord>('pendingFriendRequests');
  }

  // --- Nearby User Management ---
  Future<void> storeOrUpdateNearby(String uidShort, int gender, double distance) async {
    final now = DateTime.now();
    final existingUser = _nearbyUsersBox.get(uidShort);

    if (existingUser != null) {
      // Update existing user
      existingUser.distance = distance;
      existingUser.lastSeen = now;
      // Don't overwrite profileId
      await existingUser.save();
      // debugPrint("LocalCacheService: Updated NearbyUser $uidShort");
    } else {
      // Create new user entry
      final newUser = NearbyUser(
        uidShort: uidShort,
        gender: gender,
        distance: distance,
        lastSeen: now,
        profileId: null, // Starts as null
      );
      await _nearbyUsersBox.put(uidShort, newUser);
      debugPrint("LocalCacheService: Stored new NearbyUser $uidShort");
    }
  }

  ValueListenable<Box<NearbyUser>> getNearbyUsersListenable() {
    return _nearbyUsersBox.listenable();
  }

  Future<void> pruneStaleNearbyUsers() async {
    final now = DateTime.now();
    final keysToDelete = _nearbyUsersBox.keys.where((key) {
      final user = _nearbyUsersBox.get(key);
      return user != null && now.difference(user.lastSeen) > _staleUserDuration;
    }).toList();
    if (keysToDelete.isNotEmpty) {
      await _nearbyUsersBox.deleteAll(keysToDelete);
      debugPrint("LocalCacheService: Pruned ${keysToDelete.length} stale users.");
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
      debugPrint("LocalCacheService: Marked NearbyUser $uidShort as synced with profileId $profileId");
    } else {
      debugPrint("LocalCacheService Warning: Tried to mark non-existent user $uidShort as synced.");
    }
  }

  // *** HELPER: Find user by full profile ID ***
  NearbyUser? getNearbyUserByProfileId(String profileId) {
    if (profileId.isEmpty) return null;
    // Use firstWhereOrNull for cleaner handling of not found case
    return _nearbyUsersBox.values.firstWhereOrNull(
          (user) => user.profileId == profileId,
    );
  }

  // *** HELPER: Get all users that haven't been synced ***
  List<NearbyUser> getUnsyncedNearbyUsers() {
    return _nearbyUsersBox.values.where((user) => user.profileId == null).toList();
  }
  // *** END HELPERS ***


  // --- User Profile Management ---
  Future<void> storeUserProfile(UserProfile profile) async {
    await _userProfilesBox.put(profile.profileId, profile);
    debugPrint("LocalCacheService: Stored/Updated UserProfile ${profile.profileId}");
  }

  ValueListenable<Box<UserProfile>> getUserProfilesListenable() {
    return _userProfilesBox.listenable();
  }

  UserProfile? getUserProfile(String profileId) {
    return _userProfilesBox.get(profileId);
  }

  // --- Wave Management ---
  Future<void> recordSentWave({required String fromUidFull, required String toUidShort}) async {
    final wave = WaveRecord(fromUidFull: fromUidFull, toUidShort: toUidShort, timestamp: DateTime.now());
    await _pendingWavesBox.put(const Uuid().v4(), wave);
    debugPrint("LocalCacheService: Queued outgoing wave to $toUidShort");
  }

  Future<void> recordReceivedWave(String fromUidShort) {
    debugPrint("LocalCacheService: Logged received wave from $fromUidShort");
    // This is where you might add to a *different* box, e.g., 'wave_history'
    // For now, we only queue outgoing waves, so this does nothing to boxes.
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
  Future<void> queueFriendRequest({required String fromUserId, required String toUserId}) async {
    final request = FriendRequestRecord(fromUserId: fromUserId, toUserId: toUserId, timestamp: DateTime.now());
    await _pendingFriendRequestsBox.put(const Uuid().v4(), request);
    debugPrint("LocalCacheService: Queued friend request from $fromUserId to $toUserId");
  }

  Map<dynamic, FriendRequestRecord> getPendingFriendRequests() {
    return Map<dynamic, FriendRequestRecord>.from(_pendingFriendRequestsBox.toMap());
  }

  Future<void> removeFriendRequest(dynamic key) async {
    await _pendingFriendRequestsBox.delete(key);
    debugPrint("LocalCacheService: Removed synced friend request record $key");
  }
}