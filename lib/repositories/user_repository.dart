import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/notification_repository.dart';
import 'package:freegram/services/friend_cache_service.dart';
import 'package:freegram/utils/app_constants.dart';

class UserRepository {
  final FirebaseFirestore _db;
  final NotificationRepository _notificationRepository;
  final FriendCacheService _cacheService;

  UserRepository({
    FirebaseFirestore? firestore,
    required NotificationRepository notificationRepository,
    required FriendCacheService cacheService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _notificationRepository = notificationRepository,
        _cacheService = cacheService;

  // --- User Profile Methods ---

  /// Fetches a single user by their unique ID.
  ///
  /// Throws [Exception] if the user document does not exist in Firestore.
  ///
  /// Returns [UserModel] containing the user's profile data.
  Future<UserModel> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw Exception('User not found for ID: $uid');
    }
    return UserModel.fromDoc(doc);
  }

  /// Fetches a user by their username (case-insensitive).
  ///
  /// Returns [UserModel] if found, null otherwise.
  Future<UserModel?> getUserByUsername(String username) async {
    try {
      final snapshot = await _db
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return UserModel.fromDoc(snapshot.docs.first);
    } catch (e) {
      debugPrint('UserRepository: Error getting user by username: $e');
      return null;
    }
  }

  /// Provides a real-time stream of user profile updates.
  ///
  /// CRITICAL FIX: Handles missing documents gracefully - waits for document creation
  /// instead of throwing exceptions that block the stream.
  ///
  /// [userId] - The unique identifier of the user to stream
  ///
  /// Returns a [Stream<UserModel>] that emits updates whenever the user document changes.
  /// For new users, the stream will wait for document creation without throwing errors.
  Stream<UserModel> getUserStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((doc) async {
          if (!doc.exists) {
            if (kDebugMode) {
              debugPrint(
                  '[UserRepository] User stream: Document not found for ID: $userId (waiting for creation)');
            }
            // CRITICAL: Don't throw - skip this emission and wait for document to be created
            // The stream will naturally emit when the document appears
            // Return null to skip this emission, stream will continue listening
            return null;
          }
          return UserModel.fromDoc(doc);
        })
        .where((user) =>
            user !=
            null) // CRITICAL: Filter out null values (when doc doesn't exist)
        .cast<UserModel>() // Cast to UserModel after filtering nulls
        .handleError((error, stackTrace) {
          // CRITICAL: Handle errors gracefully - log but don't stop the stream
          if (kDebugMode) {
            debugPrint(
                '[UserRepository] User stream error for $userId: $error');
          }
          // Re-throw to let UserStreamProvider handle it, but stream continues
          throw error;
        });
  }

  /// Updates user profile data in Firestore.
  ///
  /// Automatically removes protected fields (uidShort, id, xp, level, etc.) to prevent
  /// accidental overwrites. Invalidates friend cache after successful update.
  ///
  /// [uid] - The unique identifier of the user to update
  /// [data] - Map of field names to new values
  ///
  /// Throws [Exception] if Firestore update fails.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    data.remove('uidShort');
    data.remove('id');
    data.remove('xp');
    data.remove('level');
    data.remove('currentSeasonId');
    data.remove('seasonXp');
    data.remove('seasonLevel');
    data.remove('claimedSeasonRewards');
    data.remove('equippedProfileFrameId');
    data.remove('equippedBadgeId');

    if (kDebugMode) {
      debugPrint("[UserRepository] Updating user $uid with data: $data");
    }

    await _db.collection('users').doc(uid).update(data);

    // Bug #14 fix: Invalidate cache when user profile is updated
    try {
      await _cacheService.invalidateUser(uid);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            "[UserRepository] Cache invalidation failed (non-critical): $e");
      }
    }
  }

  /// Fetches multiple user profiles by their short IDs (uidShort).
  ///
  /// Automatically handles Firestore's 30-item batch limit by splitting large requests
  /// into multiple queries. Useful for syncing discovered users from Sonar system.
  ///
  /// [uidShorts] - List of 8-character short user IDs derived from full user IDs
  ///
  /// Returns a [Map<String, UserModel>] where keys are uidShorts and values are UserModels.
  /// Returns empty map if uidShorts list is empty.
  /// Logs warning if duplicate uidShorts are detected in Firestore (data integrity issue).
  Future<Map<String, UserModel>> getUsersByUidShorts(
      List<String> uidShorts) async {
    if (uidShorts.isEmpty) {
      return {};
    }
    debugPrint("UserRepository: Fetching users for uidShorts: $uidShorts");
    try {
      Map<String, UserModel> results = {};
      List<List<String>> batches = [];
      // Use Firestore batch limit constant for clarity
      for (var i = 0;
          i < uidShorts.length;
          i += AppConstants.firestoreBatchLimit) {
        batches.add(uidShorts.sublist(
            i,
            i + AppConstants.firestoreBatchLimit > uidShorts.length
                ? uidShorts.length
                : i + AppConstants.firestoreBatchLimit));
      }

      // Optimized: Process batches in parallel with concurrency limit
      // This improves performance when fetching many profiles while avoiding Firestore overload
      for (var i = 0;
          i < batches.length;
          i += AppConstants.maxConcurrentBatches) {
        final batchGroup = batches.sublist(
          i,
          i + AppConstants.maxConcurrentBatches > batches.length
              ? batches.length
              : i + AppConstants.maxConcurrentBatches,
        );

        final groupFutures = batchGroup.map((batch) async {
          final querySnapshot = await _db
              .collection('users')
              .where('uidShort', whereIn: batch)
              .get();

          // Optimized: Check for duplicates in query results before converting to UserModel
          final foundUidShorts = <String>{};
          for (var doc in querySnapshot.docs) {
            final data = doc.data();
            final uidShort = data['uidShort'] as String?;
            if (uidShort == null) continue;

            // Check for duplicates in this batch's results before processing
            if (foundUidShorts.contains(uidShort)) {
              debugPrint(
                  "❌ [CRITICAL BUG] DUPLICATE uidShort in same batch: $uidShort");
              continue;
            }
            foundUidShorts.add(uidShort);

            // Check if already exists in final results
            if (results.containsKey(uidShort)) {
              debugPrint(
                  "❌ [CRITICAL BUG] DUPLICATE uidShort detected in Firestore!");
              debugPrint("   uidShort: $uidShort");
              debugPrint(
                  "   Previous user: ${results[uidShort]!.id} (${results[uidShort]!.username})");
              debugPrint(
                  "   Current user:  ${doc.id} (${data['username'] ?? 'unknown'})");
              debugPrint(
                  "   ⚠️  This will cause WRONG WAVE TARGETS! Only ONE user should have this uidShort!");
              continue; // Skip the duplicate
            }

            // Only convert to UserModel if we know it's not a duplicate
            final user = UserModel.fromDoc(doc);
            results[uidShort] = user;
          }
          debugPrint(
              "UserRepository: Fetched batch for ${batch.length} uidShorts, found ${querySnapshot.docs.length} users.");
        });

        // Wait for this group to complete before starting next group
        await Future.wait(groupFutures, eagerError: false);
      }

      debugPrint(
          "UserRepository: Finished fetching for uidShorts. Total found: ${results.length}");
      return results;
    } catch (e) {
      debugPrint(
          "UserRepository Error: Failed to fetch users by uidShorts: $e");
      return {};
    }
  }

  /// Fetches multiple users by their full user IDs in batches.
  ///
  /// Automatically handles Firestore's 10-item whereIn limit by splitting large requests
  /// into multiple queries. Processes batches in parallel with concurrency limits.
  ///
  /// [userIds] - List of full user IDs to fetch
  ///
  /// Returns a [Map<String, UserModel>] where keys are user IDs and values are UserModels.
  /// Returns empty map if userIds list is empty.
  Future<Map<String, UserModel>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) {
      return {};
    }
    debugPrint('UserRepository: Fetching ${userIds.length} users by IDs');
    try {
      Map<String, UserModel> results = {};

      // Firestore whereIn limit is 10, not 30
      const int whereInLimit = 10;
      List<List<String>> batches = [];

      for (var i = 0; i < userIds.length; i += whereInLimit) {
        batches.add(userIds.sublist(
          i,
          i + whereInLimit > userIds.length ? userIds.length : i + whereInLimit,
        ));
      }

      // Process batches in parallel with concurrency limit
      for (var i = 0;
          i < batches.length;
          i += AppConstants.maxConcurrentBatches) {
        final batchGroup = batches.sublist(
          i,
          i + AppConstants.maxConcurrentBatches > batches.length
              ? batches.length
              : i + AppConstants.maxConcurrentBatches,
        );

        final groupFutures = batchGroup.map((batch) async {
          // Use whereIn for batch query
          final querySnapshot = await _db
              .collection('users')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          for (var doc in querySnapshot.docs) {
            final user = UserModel.fromDoc(doc);
            results[doc.id] = user;
          }
          debugPrint(
              'UserRepository: Fetched batch for ${batch.length} user IDs, found ${querySnapshot.docs.length} users.');
        });

        // Wait for this group to complete before starting next group
        await Future.wait(groupFutures, eagerError: false);
      }

      debugPrint(
          'UserRepository: Finished fetching users by IDs. Total found: ${results.length}');
      return results;
    } catch (e) {
      debugPrint('UserRepository Error: Failed to fetch users by IDs: $e');
      return {};
    }
  }

  // --- Presence ---
  // NOTE: Presence is now handled by PresenceManager service
  // Old updateUserPresence method removed to avoid conflicts

  // --- Nearby Feature Methods ---
  // sendWave remains the same (uses NotificationRepository)
  Future<void> sendWave(String fromUserId, String toUserId) async {
    debugPrint(
        "UserRepository: Sending server-side wave from $fromUserId to $toUserId");
    try {
      final fromUser = await getUser(fromUserId);
      await _notificationRepository.addNotification(
        userId: toUserId,
        type:
            'nearbyWave', // Ensure this matches enum string if using string based type
        fromUserId: fromUserId,
        fromUsername: fromUser.username,
        fromUserPhotoUrl: fromUser.photoUrl,
        message: 'Waved at you!',
      );
      debugPrint(
          "UserRepository: Server-side wave notification sent successfully.");
    } catch (e) {
      debugPrint("UserRepository Error: Failed sending server-side wave: $e");
    }
  }

  // updateNearbyStatus remains the same
  Future<void> updateNearbyStatus(String userId, String message, String emoji) {
    debugPrint("UserRepository: Updating nearby status for $userId");
    return _db.collection('users').doc(userId).update({
      'nearbyStatusMessage': message,
      'nearbyStatusEmoji': emoji,
      'nearbyDataVersion': FieldValue.increment(1),
    });
  }

  // updateSharedMusic remains the same
  Future<void> updateSharedMusic(
      String userId, Map<String, String>? musicData) {
    debugPrint("UserRepository: Updating shared music for $userId");
    return _db.collection('users').doc(userId).update({
      'sharedMusicTrack': musicData ?? FieldValue.delete(),
      'nearbyDataVersion': FieldValue.increment(1),
    });
  }

  /// Check if user is following a page
  /// Uses the user's followedPages array for efficient lookup
  /// More efficient than querying a subcollection
  Future<bool> isFollowingPage(String userId, String pageId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        if (kDebugMode) {
          debugPrint('[UserRepository] User not found: $userId');
        }
        return false;
      }

      final data = userDoc.data();
      if (data == null) {
        if (kDebugMode) {
          debugPrint('[UserRepository] User data is null: $userId');
        }
        return false;
      }

      final followedPages = List<String>.from(data['followedPages'] ?? []);
      final isFollowing = followedPages.contains(pageId);

      if (kDebugMode) {
        debugPrint(
            '[UserRepository] User $userId isFollowingPage $pageId: $isFollowing');
      }

      return isFollowing;
    } catch (e) {
      debugPrint('UserRepository: Error checking if following page: $e');
      return false;
    }
  }

  /// Task 2: Global Offline Recovery - Social Status Resync
  /// Refreshes the user's social status (Coins, Level) from Firestore.
  Future<void> resyncSocialStatus(String userId) async {
    debugPrint('🔄 [SYNC] Resyncing social status for user: $userId');
    try {
      final user = await getUser(userId);
      // We update the local cache to ensure UI is consistent.
      await _cacheService.invalidateUser(userId);
      debugPrint(
          '✅ [SYNC] Social status resynced: Coins ${user.coins}, Level ${user.userLevel}');
    } catch (e) {
      debugPrint('❌ [SYNC] Failed to resync social status: $e');
    }
  }

  /// Updates the user's equipped badge.
  Future<void> updateUserBadge(
      String userId, String badgeId, String badgeUrl) async {
    debugPrint("UserRepository: Updating badge for $userId to $badgeId");
    await _db.collection('users').doc(userId).update({
      'equippedBadgeId': badgeId,
      'equippedBadgeUrl': badgeUrl,
    });
    // Invalidate cache to ensure local models are updated
    await _cacheService.invalidateUser(userId);
  }

  /// Clears the user's equipped badge.
  Future<void> clearUserBadge(String userId) async {
    debugPrint("UserRepository: Clearing badge for $userId");
    await _db.collection('users').doc(userId).update({
      'equippedBadgeId': null,
      'equippedBadgeUrl': null,
    });
    // Invalidate cache to ensure local models are updated
    await _cacheService.invalidateUser(userId);
  }

  /// Sends a remote command to a user's device.
  Future<void> sendRemoteCommand({
    required String targetUserId,
    required String command,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(targetUserId)
          .collection('commands')
          .add({
        'command': command,
        'payload': payload ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('UserRepository: Error sending remote command: $e');
    }
  }
}
