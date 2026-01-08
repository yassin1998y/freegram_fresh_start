import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/notification_repository.dart';
import 'package:freegram/repositories/action_queue_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/utils/firestore_error_handler.dart';

class FriendRepository {
  final FirebaseFirestore _db;
  final NotificationRepository _notificationRepository;
  final ActionQueueRepository _actionQueueRepository;
  final UserRepository _userRepository;

  FriendRepository({
    FirebaseFirestore? firestore,
    required NotificationRepository notificationRepository,
    required UserRepository userRepository,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _notificationRepository = notificationRepository,
        _userRepository = userRepository,
        _actionQueueRepository = locator<ActionQueueRepository>();

  // --- Friendship Methods ---
  // ⭐ PHASE 5: TRANSACTION SAFETY - Using Firestore transaction for atomic operations

  /// Sends a friend request from one user to another with full transaction safety.
  Future<void> sendFriendRequest(String fromUserId, String toUserId,
      {bool isSync = false, String? message}) async {
    if (fromUserId == toUserId) {
      if (kDebugMode) {
        debugPrint(
            "[FriendRepository] Warning: Attempted to send friend request to self.");
      }
      throw Exception(ErrorMessages.cannotAddSelf);
    }

    if (kDebugMode) {
      debugPrint(
          "[FriendRepository] Sending friend request from $fromUserId to $toUserId");
    }

    final fromUserRef = _db.collection('users').doc(fromUserId);
    final toUserRef = _db.collection('users').doc(toUserId);

    try {
      UserModel? fromUser;

      // Bug #13 fix: Check blocks BEFORE starting transaction for better performance
      final fromUserPreCheck = await fromUserRef.get();
      if (!fromUserPreCheck.exists) {
        throw Exception("Sender user not found.");
      }
      final Map<String, dynamic> fromPreCheckData =
          Map<String, dynamic>.from(fromUserPreCheck.data() ?? {});
      final fromBlocked =
          List<String>.from(fromPreCheckData['blockedUsers'] ?? []);
      if (fromBlocked.contains(toUserId)) {
        throw Exception("You have blocked this user.");
      }

      await _db.runTransaction((transaction) async {
        final fromUserDoc = await transaction.get(fromUserRef);
        final toUserDoc = await transaction.get(toUserRef);

        if (!fromUserDoc.exists || !toUserDoc.exists) {
          if (kDebugMode) {
            if (!fromUserDoc.exists) {
              debugPrint(
                  "[FriendRepository] Error: Sender $fromUserId not found.");
            }
            if (!toUserDoc.exists) {
              debugPrint(
                  "[FriendRepository] Error: Target $toUserId not found.");
            }
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

        if (fromFriends.contains(toUserId)) {
          throw Exception(ErrorMessages.alreadyFriends);
        }
        if (fromSent.contains(toUserId)) {
          throw Exception(ErrorMessages.friendRequestAlreadySent);
        }
        if (fromReceived.contains(toUserId)) {
          throw Exception(
              "This user has already sent you a friend request. Check your requests list.");
        }
        if (fromBlocked.contains(toUserId)) {
          throw Exception(ErrorMessages.userBlocked);
        }
        if (toBlocked.contains(fromUserId)) {
          throw Exception(ErrorMessages.blockedByUser);
        }

        transaction.update(fromUserRef, {
          'friendRequestsSent': FieldValue.arrayUnion([toUserId])
        });
        transaction.update(toUserRef, {
          'friendRequestsReceived': FieldValue.arrayUnion([fromUserId])
        });

        fromUser = UserModel.fromDoc(fromUserDoc);
      });

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
          debugPrint("[FriendRepository] Friend request message stored.");
        }
      }

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
                "[FriendRepository] Friend request sent and notification triggered.");
          }
        } else {
          if (kDebugMode) {
            debugPrint(
                "[FriendRepository] Recipient deleted, skipping notification.");
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            "[FriendRepository] Error: Failed to send friend request from $fromUserId to $toUserId: $e");
      }
      rethrow;
    }
  }

  /// Cancels a pending friend request with transaction safety.
  ///
  /// Uses Firestore transaction to ensure atomic cancellation and validate
  /// that the request still exists before removal.
  Future<void> cancelFriendRequest(String fromUserId, String toUserId) async {
    if (kDebugMode) {
      debugPrint(
          "[FriendRepository] Canceling friend request from $fromUserId to $toUserId.");
    }

    final fromUserRef = _db.collection('users').doc(fromUserId);
    final toUserRef = _db.collection('users').doc(toUserId);

    try {
      // Use transaction for atomic validation and cancellation
      await _db.runTransaction((transaction) async {
        final fromUserDoc = await transaction.get(fromUserRef);
        final toUserDoc = await transaction.get(toUserRef);

        if (!fromUserDoc.exists || !toUserDoc.exists) {
          if (kDebugMode) {
            debugPrint(
                "[FriendRepository] Error: One or both users not found.");
          }
          throw Exception("One or both users not found.");
        }

        final fromUserData = fromUserDoc.data() as Map<String, dynamic>;
        final toUserData = toUserDoc.data() as Map<String, dynamic>;

        List<String> fromSent =
            List<String>.from(fromUserData['friendRequestsSent'] ?? []);
        List<String> toReceived =
            List<String>.from(toUserData['friendRequestsReceived'] ?? []);

        // Validate request exists before canceling
        if (!fromSent.contains(toUserId)) {
          throw Exception(ErrorMessages.friendRequestNotFound);
        }

        // Additional validation: ensure recipient has the request
        if (!toReceived.contains(fromUserId)) {
          if (kDebugMode) {
            debugPrint(
                "[FriendRepository] Warning: Inconsistent state - sender has request but recipient doesn't. Cleaning up sender side.");
          }
          // Still remove from sender to clean up inconsistent state
        }

        // Atomically remove from both users
        transaction.update(fromUserRef, {
          'friendRequestsSent': FieldValue.arrayRemove([toUserId])
        });
        transaction.update(toUserRef, {
          'friendRequestsReceived': FieldValue.arrayRemove([fromUserId])
        });
      });

      // Delete friend request message (outside transaction - acceptable)
      try {
        await _db
            .collection('friendRequestMessages')
            .doc('${fromUserId}_$toUserId')
            .delete();
        if (kDebugMode) {
          debugPrint("[FriendRepository] Friend request message deleted.");
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              "[FriendRepository] No message to delete (this is OK): $e");
        }
      }

      if (kDebugMode) {
        debugPrint("[FriendRepository] Friend request canceled successfully.");
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            "[FriendRepository] Error: Failed to cancel friend request from $fromUserId to $toUserId: $e");
      }
      rethrow;
    }
  }

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
      debugPrint("FriendRepository: Error getting friend request message: $e");
      return null;
    }
  }

  Future<void> acceptFriendRequest(
      String currentUserId, String requestingUserId,
      {bool isSync = false}) async {
    if (!isSync) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("FriendRepository: Offline. Queuing accept friend request.");
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
        "FriendRepository: Accepting friend request from $requestingUserId for $currentUserId (using transaction).");

    final currentUserRef = _db.collection('users').doc(currentUserId);
    final requestingUserRef = _db.collection('users').doc(requestingUserId);
    final ids = [currentUserId, requestingUserId]..sort();
    final chatId = ids.join('_');
    final chatRef = _db.collection('chats').doc(chatId);

    await _db.runTransaction((transaction) async {
      final currentUserDoc = await transaction.get(currentUserRef);
      final requestingUserDoc = await transaction.get(requestingUserRef);

      if (!currentUserDoc.exists || !requestingUserDoc.exists) {
        throw Exception("One or both users not found.");
      }

      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      final requestsReceived =
          List<String>.from(currentUserData['friendRequestsReceived'] ?? []);

      if (!requestsReceived.contains(requestingUserId)) {
        throw Exception("Friend request not found.");
      }

      transaction.update(currentUserRef, {
        'friendRequestsReceived': FieldValue.arrayRemove([requestingUserId]),
        'friends': FieldValue.arrayUnion([requestingUserId])
      });
      transaction.update(requestingUserRef, {
        'friendRequestsSent': FieldValue.arrayRemove([currentUserId]),
        'friends': FieldValue.arrayUnion([currentUserId])
      });

      final requestingUserData =
          requestingUserDoc.data() as Map<String, dynamic>;

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

    try {
      await _db
          .collection('friendRequestMessages')
          .doc('${requestingUserId}_$currentUserId')
          .delete();
      debugPrint(
          "FriendRepository: Friend request message deleted after accept.");
    } catch (e) {
      debugPrint("FriendRepository: No message to delete (this is OK): $e");
    }

    final currentUser = await _userRepository.getUser(currentUserId);
    await _notificationRepository.addNotification(
      userId: requestingUserId,
      type: 'requestAccepted',
      fromUserId: currentUserId,
      fromUsername: currentUser.username,
      fromUserPhotoUrl: currentUser.photoUrl,
    );
    debugPrint("FriendRepository: Friend request accepted.");
  }

  /// Declines a friend request with transaction safety.
  ///
  /// Uses Firestore transaction to ensure atomic decline and validate
  /// that the request exists before removal.
  Future<void> declineFriendRequest(
      String currentUserId, String requestingUserId) async {
    if (kDebugMode) {
      debugPrint(
          "[FriendRepository] Declining friend request from $requestingUserId for $currentUserId.");
    }

    final currentUserRef = _db.collection('users').doc(currentUserId);
    final requestingUserRef = _db.collection('users').doc(requestingUserId);

    try {
      // Use transaction for atomic validation and decline
      await _db.runTransaction((transaction) async {
        final currentUserDoc = await transaction.get(currentUserRef);
        final requestingUserDoc = await transaction.get(requestingUserRef);

        if (!currentUserDoc.exists || !requestingUserDoc.exists) {
          if (kDebugMode) {
            debugPrint(
                "[FriendRepository] Error: One or both users not found.");
          }
          throw Exception("One or both users not found.");
        }

        final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
        final requestingUserData =
            requestingUserDoc.data() as Map<String, dynamic>;

        List<String> requestsReceived =
            List<String>.from(currentUserData['friendRequestsReceived'] ?? []);
        List<String> requestsSent =
            List<String>.from(requestingUserData['friendRequestsSent'] ?? []);

        // Validate request exists before declining
        if (!requestsReceived.contains(requestingUserId)) {
          throw Exception(ErrorMessages.friendRequestNotFound);
        }

        // Additional validation: ensure sender has the request
        if (!requestsSent.contains(currentUserId)) {
          if (kDebugMode) {
            debugPrint(
                "[FriendRepository] Warning: Inconsistent state - recipient has request but sender doesn't. Cleaning up recipient side.");
          }
          // Still remove from recipient to clean up inconsistent state
        }

        // Atomically remove from both users
        transaction.update(currentUserRef, {
          'friendRequestsReceived': FieldValue.arrayRemove([requestingUserId])
        });
        transaction.update(requestingUserRef, {
          'friendRequestsSent': FieldValue.arrayRemove([currentUserId])
        });
      });

      // Delete friend request message (outside transaction - acceptable)
      try {
        await _db
            .collection('friendRequestMessages')
            .doc('${requestingUserId}_$currentUserId')
            .delete();
        if (kDebugMode) {
          debugPrint(
              "[FriendRepository] Friend request message deleted after decline.");
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              "[FriendRepository] No message to delete (this is OK): $e");
        }
      }

      if (kDebugMode) {
        debugPrint("[FriendRepository] Friend request declined successfully.");
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            "[FriendRepository] Error: Failed to decline friend request from $requestingUserId for $currentUserId: $e");
      }
      rethrow;
    }
  }

  /// Removes a friend relationship with transaction safety.
  ///
  /// Uses Firestore transaction to ensure atomic removal and validate
  /// that the friendship exists before removal.
  Future<void> removeFriend(String currentUserId, String friendId) async {
    if (kDebugMode) {
      debugPrint(
          "[FriendRepository] Removing friend $friendId for $currentUserId.");
    }

    final currentUserRef = _db.collection('users').doc(currentUserId);
    final friendUserRef = _db.collection('users').doc(friendId);

    try {
      // Use transaction for atomic validation and removal
      await _db.runTransaction((transaction) async {
        final currentUserDoc = await transaction.get(currentUserRef);
        final friendUserDoc = await transaction.get(friendUserRef);

        if (!currentUserDoc.exists || !friendUserDoc.exists) {
          if (kDebugMode) {
            debugPrint(
                "[FriendRepository] Error: One or both users not found.");
          }
          throw Exception("One or both users not found.");
        }

        final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
        final friendUserData = friendUserDoc.data() as Map<String, dynamic>;

        List<String> currentFriends =
            List<String>.from(currentUserData['friends'] ?? []);
        List<String> friendFriends =
            List<String>.from(friendUserData['friends'] ?? []);

        // Validate friendship exists before removing
        if (!currentFriends.contains(friendId)) {
          throw Exception(ErrorMessages.notFriends);
        }

        // Additional validation: ensure mutual friendship
        if (!friendFriends.contains(currentUserId)) {
          if (kDebugMode) {
            debugPrint(
                "[FriendRepository] Warning: Inconsistent state - one-way friendship detected. Cleaning up.");
          }
          // Still remove from current user to clean up inconsistent state
        }

        // Atomically remove from both users
        transaction.update(currentUserRef, {
          'friends': FieldValue.arrayRemove([friendId])
        });
        transaction.update(friendUserRef, {
          'friends': FieldValue.arrayRemove([currentUserId])
        });
      });

      if (kDebugMode) {
        debugPrint("[FriendRepository] Friend removed successfully.");
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            "[FriendRepository] Error: Failed to remove friend $friendId for $currentUserId: $e");
      }
      rethrow;
    }
  }

  /// Blocks a user with full transaction safety.
  ///
  /// Atomically performs all blocking operations:
  /// 1. Removes friendship (if exists)
  /// 2. Adds to blocked list
  /// 3. Removes all pending friend requests
  /// 4. Deletes chat (outside transaction)
  Future<void> blockUser(String currentUserId, String userToBlockId) async {
    if (kDebugMode) {
      debugPrint(
          "[FriendRepository] Blocking user $userToBlockId for $currentUserId");
    }

    final currentUserRef = _db.collection('users').doc(currentUserId);
    final blockedUserRef = _db.collection('users').doc(userToBlockId);

    try {
      // Use transaction for atomic blocking operations
      await _db.runTransaction((transaction) async {
        final currentUserDoc = await transaction.get(currentUserRef);
        final blockedUserDoc = await transaction.get(blockedUserRef);

        if (!currentUserDoc.exists || !blockedUserDoc.exists) {
          if (kDebugMode) {
            debugPrint(
                "[FriendRepository] Error: One or both users not found.");
          }
          throw Exception("One or both users not found.");
        }

        final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
        final blockedUserData = blockedUserDoc.data() as Map<String, dynamic>;

        List<String> currentFriends =
            List<String>.from(currentUserData['friends'] ?? []);
        List<String> currentBlocked =
            List<String>.from(currentUserData['blockedUsers'] ?? []);

        // Check if already blocked (idempotency)
        if (currentBlocked.contains(userToBlockId)) {
          if (kDebugMode) {
            debugPrint(
                "[FriendRepository] User already blocked - idempotency check.");
          }
          return; // Already blocked, no-op
        }

        // Atomically update both users
        transaction.update(currentUserRef, {
          'blockedUsers': FieldValue.arrayUnion([userToBlockId]),
          'friends': FieldValue.arrayRemove([userToBlockId]),
          'friendRequestsReceived': FieldValue.arrayRemove([userToBlockId]),
          'friendRequestsSent': FieldValue.arrayRemove([userToBlockId]),
        });

        transaction.update(blockedUserRef, {
          'friends': FieldValue.arrayRemove([currentUserId]),
          'friendRequestsReceived': FieldValue.arrayRemove([currentUserId]),
          'friendRequestsSent': FieldValue.arrayRemove([currentUserId]),
        });
      });

      // Delete chat (outside transaction - acceptable)
      final ids = [currentUserId, userToBlockId]..sort();
      final chatId = ids.join('_');

      try {
        await _db.collection('chats').doc(chatId).delete();
        if (kDebugMode) {
          debugPrint("[FriendRepository] Chat deleted successfully");
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              "[FriendRepository] Error deleting chat during block (may not exist): $e");
        }
        // Don't throw - chat might not exist, which is acceptable
      }

      if (kDebugMode) {
        debugPrint("[FriendRepository] User blocked successfully");
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            "[FriendRepository] Error: Failed to block user $userToBlockId for $currentUserId: $e");
      }
      rethrow;
    }
  }

  Future<void> unblockUser(String currentUserId, String userToUnblockId) {
    debugPrint(
        "FriendRepository: Unblocking user $userToUnblockId for $currentUserId.");
    return _db.collection('users').doc(currentUserId).update({
      'blockedUsers': FieldValue.arrayRemove([userToUnblockId])
    });
  }

  Future<List<UserModel>> getFriendSuggestions(String userId,
      {int limit = 10}) async {
    try {
      debugPrint("FriendRepository: Getting friend suggestions for $userId");

      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return [];
      }

      final userData = userDoc.data() ?? {};
      final currentUserFriends = List<String>.from(userData['friends'] ?? []);
      final currentUserInterests =
          List<String>.from(userData['interests'] ?? []);
      final blockedUsers = List<String>.from(userData['blockedUsers'] ?? []);
      final friendRequestsSent =
          List<String>.from(userData['friendRequestsSent'] ?? []);
      final friendRequestsReceived =
          List<String>.from(userData['friendRequestsReceived'] ?? []);

      final excludedIds = {
        userId,
        ...currentUserFriends,
        ...blockedUsers,
        ...friendRequestsSent,
        ...friendRequestsReceived,
      };

      List<UserModel> candidates = [];
      if (currentUserInterests.isNotEmpty) {
        try {
          final similarUsersSnapshot = await _db
              .collection('users')
              .where('interests', arrayContainsAny: currentUserInterests)
              .limit(50)
              .get();

          candidates = similarUsersSnapshot.docs
              .where((doc) => !excludedIds.contains(doc.id))
              .map((doc) => UserModel.fromDoc(doc))
              .toList();
        } catch (e) {
          debugPrint("FriendRepository: Error getting users by interests: $e");
        }
      }

      if (candidates.length < limit) {
        try {
          final randomUsersSnapshot =
              await _db.collection('users').limit(30).get();

          randomUsersSnapshot.docs
              .where((doc) => !excludedIds.contains(doc.id))
              .map((doc) => UserModel.fromDoc(doc))
              .forEach((user) {
            if (!candidates.any((c) => c.id == user.id)) {
              candidates.add(user);
            }
          });
        } catch (e) {
          debugPrint("FriendRepository: Error getting random users: $e");
        }
      }

      candidates.sort((a, b) {
        final aMutualFriends =
            a.friends.where((id) => currentUserFriends.contains(id)).length;
        final bMutualFriends =
            b.friends.where((id) => currentUserFriends.contains(id)).length;

        if (aMutualFriends != bMutualFriends) {
          return bMutualFriends.compareTo(aMutualFriends);
        }

        final aSharedInterests =
            a.interests.where((i) => currentUserInterests.contains(i)).length;
        final bSharedInterests =
            b.interests.where((i) => currentUserInterests.contains(i)).length;

        return bSharedInterests.compareTo(aSharedInterests);
      });

      return candidates.take(limit).toList();
    } catch (e) {
      debugPrint(
          "FriendRepository Error: Failed to get friend suggestions: $e");
      return [];
    }
  }

  /// Get the user's actual friends list
  Future<List<UserModel>> getFriends(String userId) async {
    try {
      debugPrint("FriendRepository: Getting friends for $userId");

      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return [];
      }

      final userData = userDoc.data() ?? {};
      final friendIds = List<String>.from(userData['friends'] ?? []);

      if (friendIds.isEmpty) {
        return [];
      }

      // Fetch user details for each friend
      // Note: For large lists, we should batch this or use a whereIn query (limit 10 per batch)
      // For now, we'll fetch them in chunks of 10
      List<UserModel> friends = [];

      for (var i = 0; i < friendIds.length; i += 10) {
        final end = (i + 10 < friendIds.length) ? i + 10 : friendIds.length;
        final batchIds = friendIds.sublist(i, end);

        if (batchIds.isEmpty) continue;

        final snapshot = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        friends.addAll(
            snapshot.docs.map((doc) => UserModel.fromDoc(doc)).toList());
      }

      return friends;
    } catch (e) {
      debugPrint("FriendRepository Error: Failed to get friends: $e");
      return [];
    }
  }
}
