import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/notification_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/utils/firestore_error_handler.dart';

class MatchRepository {
  final FirebaseFirestore _db;
  final NotificationRepository _notificationRepository;
  final UserRepository _userRepository;

  MatchRepository({
    FirebaseFirestore? firestore,
    required NotificationRepository notificationRepository,
    required UserRepository userRepository,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _notificationRepository = notificationRepository,
        _userRepository = userRepository;

  // --- Match / Swipe Methods ---

  Future<List<DocumentSnapshot>> getPotentialMatches(
      String currentUserId) async {
    debugPrint("MatchRepository: Getting potential matches for $currentUserId.");
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

      // OPTIMIZED: Fetch 30 users to account for client-side filtering
      // Expected exclusion rate: ~33% (blocked + friends + swiped)
      // This ensures we get ~20 results after filtering
      // NOTE: Firestore doesn't support "where id not in array" efficiently,
      // so client-side filtering is necessary. Future: Use Cloud Functions for server-side filtering.
      Query query = _db.collection('users').limit(30);

      // Gender filtering can be added here if UserModel has interestedIn field
      // For best performance, create Firestore composite index:
      // Collection: users, Fields: gender (Ascending), age (Ascending)

      final querySnapshot = await query.get();

      // Client-side filtering for excluded users
      final filtered = querySnapshot.docs
          .where((doc) => !excludedIds.contains(doc.id))
          .toList();

      // Return up to 20 results after filtering
      return filtered.take(20).toList();
    } catch (e) {
      debugPrint("MatchRepository Error: Failed to get potential matches: $e");
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
            "MatchRepository Error: Fallback query also failed: $fallbackError");
        return [];
      }
    }
  }

  Future<void> recordSwipe(
      String currentUserId, String otherUserId, String action) async {
    debugPrint(
        "MatchRepository: Recording swipe ($action) from $currentUserId to $otherUserId.");
    final userRef = _db.collection('users').doc(currentUserId);
    if (action == 'super_like') {
      await _db.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw Exception("Current user not found.");
        final user = UserModel.fromDoc(userDoc);
        if (user.superLikes < 1) {
          throw Exception(ErrorMessages.noSuperLikes);
        }
        transaction.update(userRef, {'superLikes': FieldValue.increment(-1)});
      });
    }
    await userRef.collection('swipes').doc(otherUserId).set({
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
    });
    if (action == 'super_like') {
      final currentUserModel = await _userRepository.getUser(currentUserId);
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

  Future<bool> checkForMatch(String currentUserId, String otherUserId) async {
    debugPrint(
        "MatchRepository: Checking for match between $currentUserId and $otherUserId.");
    final otherUserSwipeDoc = await _db
        .collection('users')
        .doc(otherUserId)
        .collection('swipes')
        .doc(currentUserId)
        .get();
    if (!otherUserSwipeDoc.exists) return false;
    final otherUserAction = otherUserSwipeDoc.data()?['action'];
    bool match = otherUserAction == 'smash' || otherUserAction == 'super_like';
    debugPrint("MatchRepository: Match check result -> $match");
    return match;
  }

  Future<void> createMatch(String userId1, String userId2) async {
    if (kDebugMode) {
      debugPrint(
          "[MatchRepository] Creating match between $userId1 and $userId2");
    }

    final ids = [userId1, userId2]..sort();
    final chatId = ids.join('_');
    final user1Doc = await _userRepository.getUser(userId1);
    final user2Doc = await _userRepository.getUser(userId2);

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
      debugPrint("[MatchRepository] Match created successfully");
    }
  }
}
