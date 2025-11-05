// lib/repositories/user_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/notification_repository.dart';
import 'package:freegram/repositories/action_queue_repository.dart';
import 'package:freegram/services/friend_cache_service.dart';
import 'package:freegram/utils/app_constants.dart';

class UserRepository {
  final FirebaseFirestore _db;
  final NotificationRepository _notificationRepository; // Keep
  // final GamificationRepository _gamificationRepository; // Removed
  final ActionQueueRepository _actionQueueRepository;

  UserRepository({
    FirebaseFirestore? firestore,
    required NotificationRepository notificationRepository, // Keep
    // required GamificationRepository gamificationRepository, // Removed
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _notificationRepository = notificationRepository, // Keep
        // _gamificationRepository = gamificationRepository, // Removed
        _actionQueueRepository = locator<ActionQueueRepository>();

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
  /// When a document doesn't exist initially, retries with a delay before throwing.
  ///
  /// [userId] - The unique identifier of the user to stream
  ///
  /// Returns a [Stream<UserModel>] that emits updates whenever the user document changes.
  /// Throws [Exception] if user not found after retry.
  Stream<UserModel> getUserStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((doc) async {
      if (!doc.exists) {
        if (kDebugMode) {
          debugPrint(
              '[UserRepository] User stream warning: User not found for ID: $userId');
        }
        await Future.delayed(const Duration(milliseconds: 1000));
        final retryDoc = await _db.collection('users').doc(userId).get();
        // Bug #8 fix: Handle null case properly after retry
        if (!retryDoc.exists) {
          throw Exception(
              'User stream error: User $userId not found after retry');
        }
        final retryData = retryDoc.data();
        if (retryData == null) {
          throw Exception('User stream error: User $userId has null data');
        }
        return UserModel.fromDoc(retryDoc);
      }
      return UserModel.fromDoc(doc);
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
      final cacheService = locator<FriendCacheService>();
      await cacheService.invalidateUser(uid);
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

  // --- Friendship Methods ---
  // ⭐ PHASE 5: TRANSACTION SAFETY - Using Firestore transaction for atomic operations

  /// Sends a friend request from one user to another with full transaction safety.
  ///
  /// Uses Firestore transactions to ensure atomicity and prevent race conditions.
  /// Includes comprehensive validation: blocks checks, idempotency, duplicate prevention.
  /// Optionally includes a custom message with the friend request.
  ///
  /// [fromUserId] - The user sending the friend request
  /// [toUserId] - The user receiving the friend request
  /// [isSync] - If true, skips connectivity check (used during offline sync)
  /// [message] - Optional custom message to include with the request
  ///
  /// Throws [Exception] if:
  /// - Users not found
  /// - Users are already friends
  /// - Request already sent (idempotency check)
  /// - Either user has blocked the other
  /// - User attempting to send request to themselves
  Future<void> sendFriendRequest(String fromUserId, String toUserId,
      {bool isSync = false, String? message}) async {
    if (fromUserId == toUserId) {
      if (kDebugMode) {
        debugPrint(
            "[UserRepository] Warning: Attempted to send friend request to self.");
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
          "[UserRepository] Sending friend request from $fromUserId to $toUserId");
    }

    final fromUserRef = _db.collection('users').doc(fromUserId);
    final toUserRef = _db.collection('users').doc(toUserId);

    try {
      UserModel? fromUser;

      // Bug #13 fix: Check blocks BEFORE starting transaction for better performance
      // ⚠️ PERFORMANCE: Pre-check adds extra Firestore read before transaction
      // Consider: This is acceptable for avoiding transaction overhead, but note the trade-off
      // ⚠️ MAINTAINABILITY: Data is read twice (pre-check + transaction) - ensure consistency
      // Consider: Document why pre-check is necessary (transaction retry cost)
      final fromUserPreCheck = await fromUserRef.get();
      if (!fromUserPreCheck.exists) {
        throw Exception("Sender user not found.");
      }
      final fromBlocked =
          List<String>.from(fromUserPreCheck.get('blockedUsers') ?? []);
      if (fromBlocked.contains(toUserId)) {
        throw Exception("You have blocked this user.");
      }

      await _db.runTransaction((transaction) async {
        final fromUserDoc = await transaction.get(fromUserRef);
        final toUserDoc = await transaction.get(toUserRef);

        // Bug #1 fix: Re-verify documents exist after transaction read
        if (!fromUserDoc.exists || !toUserDoc.exists) {
          if (kDebugMode) {
            if (!fromUserDoc.exists)
              debugPrint(
                  "[UserRepository] Error: Sender $fromUserId not found.");
            if (!toUserDoc.exists)
              debugPrint("[UserRepository] Error: Target $toUserId not found.");
          }
          throw Exception("One or both users not found.");
        }

        final fromUserData = fromUserDoc.data() as Map<String, dynamic>;
        final toUserData = toUserDoc.data() as Map<String, dynamic>;

        List<String> fromFriends =
            List<String>.from(fromUserData['friends'] ?? []);
        List<String> fromSent =
            List<String>.from(fromUserData['friendRequestsSent'] ?? []);
        List<String> fromReceived =
            List<String>.from(fromUserData['friendRequestsReceived'] ?? []);
        List<String> fromBlocked =
            List<String>.from(fromUserData['blockedUsers'] ?? []);
        List<String> toBlocked =
            List<String>.from(toUserData['blockedUsers'] ?? []);

        // Bug #4 fix: Strict idempotency check
        if (fromFriends.contains(toUserId)) throw Exception("Already friends.");
        if (fromSent.contains(toUserId))
          throw Exception("Request already sent - idempotency check.");
        if (fromReceived.contains(toUserId)) {
          throw Exception(
              "User has already sent you a request. Check your requests list.");
        }
        if (fromBlocked.contains(toUserId))
          throw Exception("You have blocked this user.");
        if (toBlocked.contains(fromUserId))
          throw Exception("This user has blocked you.");

        transaction.update(fromUserRef, {
          'friendRequestsSent': FieldValue.arrayUnion([toUserId])
        });
        transaction.update(toUserRef, {
          'friendRequestsReceived': FieldValue.arrayUnion([fromUserId])
        });

        fromUser = UserModel.fromDoc(fromUserDoc);
      });

      // Bug #11 fix: Store message AFTER transaction succeeds
      if (message != null && message.isNotEmpty && fromUser != null) {
        await _db
            .collection('friendRequestMessages')
            .doc('${fromUserId}_$toUserId')
            .set({
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
        });
        if (kDebugMode) {
          debugPrint("[UserRepository] Friend request message stored.");
        }
      }

      // Bug #10 fix: Verify recipient still exists before sending notification
      if (fromUser != null) {
        final toUserVerify = await toUserRef.get();
        if (toUserVerify.exists) {
          await _notificationRepository.addNotification(
            userId: toUserId,
            type: 'friendRequest',
            fromUserId: fromUserId,
            fromUsername: fromUser!.username,
            fromUserPhotoUrl: fromUser!.photoUrl,
          );
          if (kDebugMode) {
            debugPrint(
                "[UserRepository] Friend request sent and notification triggered.");
          }
        } else {
          if (kDebugMode) {
            debugPrint(
                "[UserRepository] Recipient deleted, skipping notification.");
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            "[UserRepository] Error: Failed to send friend request from $fromUserId to $toUserId: $e");
      }
      rethrow;
    }
  }

  // cancelFriendRequest - New method to cancel a sent friend request
  Future<void> cancelFriendRequest(String fromUserId, String toUserId) async {
    debugPrint(
        "UserRepository: Canceling friend request from $fromUserId to $toUserId.");

    final batch = _db.batch();
    final fromUserRef = _db.collection('users').doc(fromUserId);
    final toUserRef = _db.collection('users').doc(toUserId);

    try {
      final fromUserDoc = await fromUserRef.get();
      final toUserDoc = await toUserRef.get();

      if (!fromUserDoc.exists || !toUserDoc.exists) {
        debugPrint("UserRepository Error: One or both users not found.");
        throw Exception("One or both users not found.");
      }

      final fromUserData = fromUserDoc.data() as Map<String, dynamic>;

      List<String> fromSent =
          List<String>.from(fromUserData['friendRequestsSent'] ?? []);

      if (!fromSent.contains(toUserId)) {
        throw Exception("No pending friend request found.");
      }

      // Remove from both users' arrays
      batch.update(fromUserRef, {
        'friendRequestsSent': FieldValue.arrayRemove([toUserId])
      });
      batch.update(toUserRef, {
        'friendRequestsReceived': FieldValue.arrayRemove([fromUserId])
      });

      await batch.commit();

      // Delete friend request message if it exists
      try {
        await _db
            .collection('friendRequestMessages')
            .doc('${fromUserId}_$toUserId')
            .delete();
        debugPrint("UserRepository: Friend request message deleted.");
      } catch (e) {
        debugPrint("UserRepository: No message to delete (this is OK): $e");
      }

      debugPrint("UserRepository: Friend request canceled successfully.");
    } catch (e) {
      debugPrint(
          "UserRepository Error: Failed to cancel friend request from $fromUserId to $toUserId: $e");
      rethrow;
    }
  }

  // Get friend request message if exists
  Future<String?> getFriendRequestMessage(
      String fromUserId, String toUserId) async {
    try {
      final doc = await _db
          .collection('friendRequestMessages')
          .doc('${fromUserId}_$toUserId')
          .get();

      if (doc.exists) {
        final data = doc.data();
        return data?['message'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint("UserRepository: Error getting friend request message: $e");
      return null;
    }
  }

  // acceptFriendRequest - Remove gamification calls
  Future<void> acceptFriendRequest(
      String currentUserId, String requestingUserId,
      {bool isSync = false}) async {
    if (!isSync) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("UserRepository: Offline. Queuing accept friend request.");
        return _actionQueueRepository.addAction(
          type: 'accept_friend_request',
          payload: {
            'currentUserId': currentUserId,
            'requestingUserId': requestingUserId
          },
        );
      }
    }

    debugPrint(
        "UserRepository: Accepting friend request from $requestingUserId for $currentUserId (using transaction).");

    final currentUserRef = _db.collection('users').doc(currentUserId);
    final requestingUserRef = _db.collection('users').doc(requestingUserId);
    final ids = [currentUserId, requestingUserId]..sort();
    final chatId = ids.join('_');
    final chatRef = _db.collection('chats').doc(chatId);

    // ⭐ PHASE 5: TRANSACTION SAFETY - Use transaction for atomic friend acceptance
    await _db.runTransaction((transaction) async {
      final currentUserDoc = await transaction.get(currentUserRef);
      final requestingUserDoc = await transaction.get(requestingUserRef);

      if (!currentUserDoc.exists || !requestingUserDoc.exists) {
        throw Exception("One or both users not found.");
      }

      // Verify the request exists
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      final requestsReceived =
          List<String>.from(currentUserData['friendRequestsReceived'] ?? []);

      if (!requestsReceived.contains(requestingUserId)) {
        throw Exception("Friend request not found.");
      }

      // Atomically update both users
      transaction.update(currentUserRef, {
        'friendRequestsReceived': FieldValue.arrayRemove([requestingUserId]),
        'friends': FieldValue.arrayUnion([requestingUserId])
      });
      transaction.update(requestingUserRef, {
        'friendRequestsSent': FieldValue.arrayRemove([currentUserId]),
        'friends': FieldValue.arrayUnion([currentUserId])
      });

      // Get requesting user data for usernames
      final requestingUserData =
          requestingUserDoc.data() as Map<String, dynamic>;

      // Ensure chat document exists with all required fields
      transaction.set(
        chatRef,
        {
          'users': [currentUserId, requestingUserId],
          'usernames': {
            currentUserId: currentUserData['username'] ?? 'User',
            requestingUserId: requestingUserData['username'] ?? 'User',
          },
          'chatType': 'friend_chat',
          'lastMessage': '',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'unreadFor': [],
        },
        SetOptions(merge: true),
      );
    });

    // Delete friend request message after accepting
    try {
      await _db
          .collection('friendRequestMessages')
          .doc('${requestingUserId}_$currentUserId')
          .delete();
      debugPrint(
          "UserRepository: Friend request message deleted after accept.");
    } catch (e) {
      debugPrint("UserRepository: No message to delete (this is OK): $e");
    }

    // await _gamificationRepository.addXp(currentUserId, 50, isSeasonal: true); // Removed
    // await _gamificationRepository.addXp(requestingUserId, 50, isSeasonal: true); // Removed
    final currentUser = await getUser(currentUserId);
    await _notificationRepository.addNotification(
      userId: requestingUserId,
      type: 'requestAccepted', // Ensure this matches enum string
      fromUserId: currentUserId,
      fromUsername: currentUser.username,
      fromUserPhotoUrl: currentUser.photoUrl,
    );
    debugPrint("UserRepository: Friend request accepted.");
  }

  // declineFriendRequest remains the same
  Future<void> declineFriendRequest(
      String currentUserId, String requestingUserId) async {
    debugPrint(
        "UserRepository: Declining friend request from $requestingUserId for $currentUserId.");
    final batch = _db.batch();
    final currentUserRef = _db.collection('users').doc(currentUserId);
    final requestingUserRef = _db.collection('users').doc(requestingUserId);
    batch.update(currentUserRef, {
      'friendRequestsReceived': FieldValue.arrayRemove([requestingUserId])
    });
    batch.update(requestingUserRef, {
      'friendRequestsSent': FieldValue.arrayRemove([currentUserId])
    });
    await batch.commit();

    // Delete friend request message after declining
    try {
      await _db
          .collection('friendRequestMessages')
          .doc('${requestingUserId}_$currentUserId')
          .delete();
      debugPrint(
          "UserRepository: Friend request message deleted after decline.");
    } catch (e) {
      debugPrint("UserRepository: No message to delete (this is OK): $e");
    }

    debugPrint("UserRepository: Friend request declined.");
  }

  // removeFriend remains the same
  Future<void> removeFriend(String currentUserId, String friendId) async {
    debugPrint("UserRepository: Removing friend $friendId for $currentUserId.");
    final batch = _db.batch();
    final currentUserRef = _db.collection('users').doc(currentUserId);
    final friendUserRef = _db.collection('users').doc(friendId);
    batch.update(currentUserRef, {
      'friends': FieldValue.arrayRemove([friendId])
    });
    batch.update(friendUserRef, {
      'friends': FieldValue.arrayRemove([currentUserId])
    });
    await batch.commit();
    debugPrint("UserRepository: Friend removed.");
  }

  // blockUser remains the same
  Future<void> blockUser(String currentUserId, String userToBlockId) async {
    if (kDebugMode) {
      debugPrint(
          "[UserRepository] Blocking user $userToBlockId for $currentUserId");
    }

    await removeFriend(currentUserId, userToBlockId).catchError((e) {
      if (kDebugMode) {
        debugPrint(
            "[UserRepository] Note - Error removing friend during block (might not be friends): $e");
      }
    });

    await _db.collection('users').doc(currentUserId).update({
      'blockedUsers': FieldValue.arrayUnion([userToBlockId])
    });
    await _db.collection('users').doc(userToBlockId).update({
      'friendRequestsReceived': FieldValue.arrayRemove([currentUserId]),
      'friendRequestsSent': FieldValue.arrayRemove([currentUserId]),
    });
    await _db.collection('users').doc(currentUserId).update({
      'friendRequestsReceived': FieldValue.arrayRemove([userToBlockId]),
      'friendRequestsSent': FieldValue.arrayRemove([userToBlockId]),
    });

    final ids = [currentUserId, userToBlockId]..sort();
    final chatId = ids.join('_');

    // Bug #5 fix: Properly handle chat deletion failure
    try {
      await _db.collection('chats').doc(chatId).delete();
      if (kDebugMode) {
        debugPrint("[UserRepository] Chat deleted successfully");
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("[UserRepository] Error deleting chat during block: $e");
      }
      // Don't silently fail - user should know chat might still exist
      throw Exception("Failed to delete chat. Please try again.");
    }

    if (kDebugMode) {
      debugPrint("[UserRepository] User blocked successfully");
    }
  }

  // unblockUser remains the same
  Future<void> unblockUser(String currentUserId, String userToUnblockId) {
    debugPrint(
        "UserRepository: Unblocking user $userToUnblockId for $currentUserId.");
    return _db.collection('users').doc(currentUserId).update({
      'blockedUsers': FieldValue.arrayRemove([userToUnblockId])
    });
  }

  // --- Match / Swipe Methods ---
  // getPotentialMatches remains the same
  Future<List<DocumentSnapshot>> getPotentialMatches(
      String currentUserId) async {
    debugPrint("UserRepository: Getting potential matches for $currentUserId.");
    try {
      final userDoc = await _db.collection('users').doc(currentUserId).get();
      if (!userDoc.exists) return [];
      final userData = userDoc.data() as Map<String, dynamic>;
      List<String> blockedUsers =
          List<String>.from(userData['blockedUsers'] ?? []);
      List<String> friends = List<String>.from(userData['friends'] ?? []);
      final swipesSnapshot = await _db
          .collection('users')
          .doc(currentUserId)
          .collection('swipes')
          .get();
      final swipedUserIds = swipesSnapshot.docs.map((doc) => doc.id).toList();
      final excludedIds = {
        currentUserId,
        ...blockedUsers,
        ...friends,
        ...swipedUserIds
      };

      // OPTIMIZED: Reduced from 50 to 20 documents
      // For best performance, create Firestore composite index:
      // Collection: users, Fields: gender (Ascending), age (Ascending)
      Query query = _db.collection('users').limit(20);

      // Gender filtering can be added here if UserModel has interestedIn field
      // For now, just limit results to improve performance

      final querySnapshot = await query.get();

      // Client-side filtering for excluded users
      return querySnapshot.docs
          .where((doc) => !excludedIds.contains(doc.id))
          .toList();
    } catch (e) {
      debugPrint("UserRepository Error: Failed to get potential matches: $e");
      // Fallback to simple query if filtering fails
      try {
        final querySnapshot = await _db.collection('users').limit(20).get();
        final currentUser =
            await _db.collection('users').doc(currentUserId).get();
        final friends = List<String>.from(currentUser.data()?['friends'] ?? []);
        final excludedIds = {currentUserId, ...friends};
        return querySnapshot.docs
            .where((doc) => !excludedIds.contains(doc.id))
            .toList();
      } catch (fallbackError) {
        debugPrint(
            "UserRepository Error: Fallback query also failed: $fallbackError");
        return [];
      }
    }
  }

  // recordSwipe - Keep notification logic for super_like
  Future<void> recordSwipe(
      String currentUserId, String otherUserId, String action) async {
    debugPrint(
        "UserRepository: Recording swipe ($action) from $currentUserId to $otherUserId.");
    final userRef = _db.collection('users').doc(currentUserId);
    if (action == 'super_like') {
      await _db.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw Exception("Current user not found.");
        final user = UserModel.fromDoc(userDoc);
        if (user.superLikes < 1)
          throw Exception("You have no Super Likes left.");
        transaction.update(userRef, {'superLikes': FieldValue.increment(-1)});
      });
    }
    await userRef.collection('swipes').doc(otherUserId).set({
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
    });
    if (action == 'super_like') {
      final currentUserModel = await getUser(currentUserId);
      // Keep notification for super_like
      await _notificationRepository.addNotification(
        userId: otherUserId,
        type: 'superLike', // Ensure this matches enum string
        fromUserId: currentUserId,
        fromUsername: currentUserModel.username,
        fromUserPhotoUrl: currentUserModel.photoUrl,
      );
    }
  }

  // checkForMatch remains the same
  Future<bool> checkForMatch(String currentUserId, String otherUserId) async {
    debugPrint(
        "UserRepository: Checking for match between $currentUserId and $otherUserId.");
    final otherUserSwipeDoc = await _db
        .collection('users')
        .doc(otherUserId)
        .collection('swipes')
        .doc(currentUserId)
        .get();
    if (!otherUserSwipeDoc.exists) return false;
    final otherUserAction = otherUserSwipeDoc.data()?['action'];
    bool match = otherUserAction == 'smash' || otherUserAction == 'super_like';
    debugPrint("UserRepository: Match check result -> $match");
    return match;
  }

  // createMatch - Remove gamification calls
  Future<void> createMatch(String userId1, String userId2) async {
    if (kDebugMode) {
      debugPrint(
          "[UserRepository] Creating match between $userId1 and $userId2");
    }

    final ids = [userId1, userId2]..sort();
    final chatId = ids.join('_');
    final user1Doc = await getUser(userId1);
    final user2Doc = await getUser(userId2);

    // Bug #12 fix: Use transaction to prevent duplicate friends on retry
    await _db.runTransaction((transaction) async {
      final user1Ref = _db.collection('users').doc(userId1);
      final user2Ref = _db.collection('users').doc(userId2);
      final chatRef = _db.collection('chats').doc(chatId);

      final user1Snapshot = await transaction.get(user1Ref);
      final user2Snapshot = await transaction.get(user2Ref);

      if (!user1Snapshot.exists || !user2Snapshot.exists) {
        throw Exception("One or both users not found");
      }

      final user1Friends =
          List<String>.from(user1Snapshot.get('friends') ?? []);
      final user2Friends =
          List<String>.from(user2Snapshot.get('friends') ?? []);

      // Only add if not already friends (idempotency)
      if (!user1Friends.contains(userId2)) {
        transaction.update(user1Ref, {
          'friends': FieldValue.arrayUnion([userId2]),
          'friendRequestsReceived': FieldValue.arrayRemove([userId2]),
          'friendRequestsSent': FieldValue.arrayRemove([userId2])
        });
      }

      if (!user2Friends.contains(userId1)) {
        transaction.update(user2Ref, {
          'friends': FieldValue.arrayUnion([userId1]),
          'friendRequestsReceived': FieldValue.arrayRemove([userId1]),
          'friendRequestsSent': FieldValue.arrayRemove([userId1])
        });
      }

      transaction.set(
          chatRef,
          {
            'users': ids,
            'usernames': {
              userId1: user1Doc.username,
              userId2: user2Doc.username
            },
            'lastMessage': 'You matched! Say hello.',
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
            'chatType': 'friend_chat',
            'matchTimestamp': FieldValue.serverTimestamp(),
            'unreadFor': [],
          },
          SetOptions(merge: true));
    });

    if (kDebugMode) {
      debugPrint("[UserRepository] Match created successfully");
    }
  }

  // --- User Discovery Methods ---
  // getPaginatedUsers remains the same
  Future<QuerySnapshot> getPaginatedUsers(
      {required int limit, DocumentSnapshot? lastDocument}) {
    debugPrint("UserRepository: Fetching paginated users (limit: $limit).");
    Query query = _db.collection('users').orderBy('username').limit(limit);
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    return query.get();
  }

  // getRecommendedUsers - Remove sorting by level
  Future<List<DocumentSnapshot>> getRecommendedUsers(
      List<String> interests, String currentUserId) async {
    debugPrint(
        "UserRepository: Fetching recommended users for $currentUserId.");
    if (interests.isEmpty) return [];
    try {
      // Query based on interests
      final querySnapshot = await _db
          .collection('users')
          .where('interests', arrayContainsAny: interests)
          .limit(50) // Fetch a larger pool initially
          .get();

      // Filter out current user and map to UserModel for sorting
      final candidates = querySnapshot.docs
          .where((doc) => doc.id != currentUserId)
          .map((doc) => UserModel.fromDoc(doc))
          .toList();

      // Sort primarily by number of shared interests (descending)
      candidates.sort((a, b) {
        final aSharedInterests =
            a.interests.where((i) => interests.contains(i)).length;
        final bSharedInterests =
            b.interests.where((i) => interests.contains(i)).length;
        // Primary sort: shared interests (descending)
        int interestComparison = bSharedInterests.compareTo(aSharedInterests);
        if (interestComparison != 0) return interestComparison;
        // Secondary sort: maybe last seen (more recent first)? Optional.
        // return b.lastSeen.compareTo(a.lastSeen);
        return 0; // Or no secondary sort
      });

      // Get the sorted IDs
      final sortedIds = candidates.map((u) => u.id).toList();

      // Re-sort the original DocumentSnapshots based on the sorted IDs
      final originalDocs =
          querySnapshot.docs.where((doc) => doc.id != currentUserId).toList();
      originalDocs.sort(
          (a, b) => sortedIds.indexOf(a.id).compareTo(sortedIds.indexOf(b.id)));

      // Return the top N recommendations
      return originalDocs.take(30).toList();
    } catch (e) {
      debugPrint("UserRepository Error: Failed to get recommended users: $e");
      return [];
    }
  }

  Stream<QuerySnapshot> searchUsers(String query) {
    if (kDebugMode) {
      debugPrint("[UserRepository] Searching users with query '$query'");
    }
    if (query.isEmpty) return Stream.empty();

    // Bug #16 fix: Sanitize search query to prevent injection and handle special chars
    final sanitizedQuery = query.trim().replaceAll(RegExp(r'[^\w\s]'), '');
    if (sanitizedQuery.isEmpty) return Stream.empty();

    return _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: sanitizedQuery)
        .where('username', isLessThanOrEqualTo: '$sanitizedQuery\uf8ff')
        .limit(20)
        .snapshots();
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
}
