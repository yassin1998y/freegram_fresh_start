// lib/repositories/user_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:flutter/foundation.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
// import 'package:freegram/repositories/gamification_repository.dart'; // Removed
import 'package:freegram/repositories/notification_repository.dart'; // Keep
import 'package:freegram/services/sonar/local_cache_service.dart';
import 'package:freegram/repositories/action_queue_repository.dart';


class UserRepository {
  final FirebaseFirestore _db;
  final rtdb.FirebaseDatabase _rtdb;
  final NotificationRepository _notificationRepository; // Keep
  // final GamificationRepository _gamificationRepository; // Removed
  final LocalCacheService _localCacheService;
  final ActionQueueRepository _actionQueueRepository;

  UserRepository({
    FirebaseFirestore? firestore,
    rtdb.FirebaseDatabase? rtdbInstance,
    required NotificationRepository notificationRepository, // Keep
    // required GamificationRepository gamificationRepository, // Removed
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _rtdb = rtdbInstance ?? rtdb.FirebaseDatabase.instance,
        _notificationRepository = notificationRepository, // Keep
  // _gamificationRepository = gamificationRepository, // Removed
        _localCacheService = locator<LocalCacheService>(),
        _actionQueueRepository = locator<ActionQueueRepository>();

  // --- User Profile Methods ---
  Future<UserModel> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw Exception('User not found for ID: $uid');
    }
    return UserModel.fromDoc(doc);
  }

  Stream<UserModel> getUserStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((doc) async {
      if (!doc.exists) {
        debugPrint('User stream warning: User not found for ID: $userId');
        // Wait a bit and retry once for new users
        await Future.delayed(const Duration(milliseconds: 1000));
        final retryDoc = await _db.collection('users').doc(userId).get();
        if (!retryDoc.exists) {
          throw Exception('User stream error: User not found for ID: $userId');
        }
        return UserModel.fromDoc(retryDoc);
      }
      return UserModel.fromDoc(doc);
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    // Ensure uidShort is not accidentally overwritten if not provided
    data.remove('uidShort');
    // Ensure id is not accidentally overwritten
    data.remove('id');
    // Remove deleted fields from update data if they happen to be passed
    data.remove('xp');
    data.remove('level');
    data.remove('currentSeasonId');
    data.remove('seasonXp');
    data.remove('seasonLevel');
    data.remove('claimedSeasonRewards');
    data.remove('equippedProfileFrameId');
    data.remove('equippedBadgeId');

    debugPrint("UserRepository: Updating user $uid with data: $data");
    return _db.collection('users').doc(uid).update(data);
  }

  // getUsersByUidShorts remains the same
  Future<Map<String, UserModel>> getUsersByUidShorts(List<String> uidShorts) async {
    if (uidShorts.isEmpty) {
      return {};
    }
    debugPrint("UserRepository: Fetching users for uidShorts: $uidShorts");
    try {
      Map<String, UserModel> results = {};
      List<List<String>> batches = [];
      for (var i = 0; i < uidShorts.length; i += 30) {
        batches.add(uidShorts.sublist(i, i + 30 > uidShorts.length ? uidShorts.length : i + 30));
      }

      for (var batch in batches) {
        final querySnapshot = await _db
            .collection('users')
            .where('uidShort', whereIn: batch)
            .get();

        for (var doc in querySnapshot.docs) {
          final user = UserModel.fromDoc(doc);
          results[user.uidShort] = user;
        }
        debugPrint("UserRepository: Fetched batch for ${batch.length} uidShorts, found ${querySnapshot.docs.length} users.");
      }

      debugPrint("UserRepository: Finished fetching for uidShorts. Total found: ${results.length}");
      return results;
    } catch (e) {
      debugPrint("UserRepository Error: Failed to fetch users by uidShorts: $e");
      return {};
    }
  }

  // --- Presence ---
  // updateUserPresence remains the same
  Future<void> updateUserPresence(String uid, bool isOnline) async {
    final userStatusFirestoreRef = _db.collection('users').doc(uid);
    final userStatusDatabaseRef = _rtdb.ref('status/$uid');
    final status = {
      'presence': isOnline,
      'lastSeen': rtdb.ServerValue.timestamp,
    };
    try {
      await userStatusDatabaseRef.set(status);
      await userStatusDatabaseRef.onDisconnect().set({
        'presence': false,
        'lastSeen': rtdb.ServerValue.timestamp,
      });

      await userStatusFirestoreRef.update({
        'presence': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      debugPrint("UserRepository: Updated presence for $uid to $isOnline");
    } catch (e) {
      debugPrint("UserRepository: Error updating presence for $uid: $e");
    }
  }


  // --- Nearby Feature Methods ---
  // sendWave remains the same (uses NotificationRepository)
  Future<void> sendWave(String fromUserId, String toUserId) async {
    debugPrint("UserRepository: Sending server-side wave from $fromUserId to $toUserId");
    try {
      final fromUser = await getUser(fromUserId);
      await _notificationRepository.addNotification(
        userId: toUserId,
        type: 'nearbyWave', // Ensure this matches enum string if using string based type
        fromUserId: fromUserId,
        fromUsername: fromUser.username,
        fromUserPhotoUrl: fromUser.photoUrl,
        message: 'Waved at you!',
      );
      debugPrint("UserRepository: Server-side wave notification sent successfully.");
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
  Future<void> updateSharedMusic(String userId, Map<String, String>? musicData) {
    debugPrint("UserRepository: Updating shared music for $userId");
    return _db.collection('users').doc(userId).update({
      'sharedMusicTrack': musicData ?? FieldValue.delete(),
      'nearbyDataVersion': FieldValue.increment(1),
    });
  }


  // --- Friendship Methods ---
  // sendFriendRequest - Remove gamification calls
  Future<void> sendFriendRequest(String fromUserId, String toUserId, {bool isSync = false}) async {
    if (fromUserId == toUserId) {
      debugPrint("UserRepository Warning: Attempted to send friend request to self.");
      return;
    }

    debugPrint("UserRepository: Sending friend request from $fromUserId to $toUserId via Firebase.");
    final batch = _db.batch();
    final fromUserRef = _db.collection('users').doc(fromUserId);
    final toUserRef = _db.collection('users').doc(toUserId);

    try {
      final fromUserDoc = await fromUserRef.get();
      final toUserDoc = await toUserRef.get();

      if (!fromUserDoc.exists || !toUserDoc.exists) {
        if (!fromUserDoc.exists) debugPrint("UserRepository Error: Sender user $fromUserId not found.");
        if (!toUserDoc.exists) debugPrint("UserRepository Error: Target user $toUserId not found.");
        throw Exception("One or both users not found.");
      }

      final fromUserData = fromUserDoc.data() as Map<String, dynamic>;
      final toUserData = toUserDoc.data() as Map<String, dynamic>;

      List<String> fromFriends = List<String>.from(fromUserData['friends'] ?? []);
      List<String> fromSent = List<String>.from(fromUserData['friendRequestsSent'] ?? []);
      List<String> fromReceived = List<String>.from(fromUserData['friendRequestsReceived'] ?? []);
      List<String> fromBlocked = List<String>.from(fromUserData['blockedUsers'] ?? []);
      List<String> toBlocked = List<String>.from(toUserData['blockedUsers'] ?? []);

      if (fromFriends.contains(toUserId)) throw Exception("Already friends.");
      if (fromSent.contains(toUserId)) throw Exception("Request already sent.");
      if (fromReceived.contains(toUserId)) {
        throw Exception("User has already sent you a request. Check your requests list.");
      }
      if (fromBlocked.contains(toUserId)) throw Exception("You have blocked this user.");
      if (toBlocked.contains(fromUserId)) throw Exception("This user has blocked you.");

      batch.update(fromUserRef, {'friendRequestsSent': FieldValue.arrayUnion([toUserId])});
      batch.update(toUserRef, {'friendRequestsReceived': FieldValue.arrayUnion([fromUserId])});

      await batch.commit();

      final fromUser = UserModel.fromDoc(fromUserDoc);
      await _notificationRepository.addNotification(
        userId: toUserId,
        type: 'friendRequest', // Ensure this matches enum string
        fromUserId: fromUserId,
        fromUsername: fromUser.username,
        fromUserPhotoUrl: fromUser.photoUrl,
      );
      debugPrint("UserRepository: Friend request sent and notification triggered.");

    } catch (e) {
      debugPrint("UserRepository Error: Failed to send friend request from $fromUserId to $toUserId: $e");
      rethrow;
    }
  }

  // acceptFriendRequest - Remove gamification calls
  Future<void> acceptFriendRequest(String currentUserId, String requestingUserId, {bool isSync = false}) async {
    if (!isSync) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("UserRepository: Offline. Queuing accept friend request.");
        return _actionQueueRepository.addAction(
          type: 'accept_friend_request',
          payload: {'currentUserId': currentUserId, 'requestingUserId': requestingUserId},
        );
      }
    }

    debugPrint("UserRepository: Accepting friend request from $requestingUserId for $currentUserId.");
    final batch = _db.batch();
    final currentUserRef = _db.collection('users').doc(currentUserId);
    final requestingUserRef = _db.collection('users').doc(requestingUserId);

    batch.update(currentUserRef, {'friendRequestsReceived': FieldValue.arrayRemove([requestingUserId]), 'friends': FieldValue.arrayUnion([requestingUserId])});
    batch.update(requestingUserRef, {'friendRequestsSent': FieldValue.arrayRemove([currentUserId]), 'friends': FieldValue.arrayUnion([currentUserId])});

    final ids = [currentUserId, requestingUserId]..sort();
    final chatId = ids.join('_');
    final chatRef = _db.collection('chats').doc(chatId);
    // Ensure chat type is updated to allow free messaging
    batch.set(chatRef, {'chatType': 'friend_chat'}, SetOptions(merge: true));

    await batch.commit();
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
  Future<void> declineFriendRequest(String currentUserId, String requestingUserId) async {
    debugPrint("UserRepository: Declining friend request from $requestingUserId for $currentUserId.");
    final batch = _db.batch();
    final currentUserRef = _db.collection('users').doc(currentUserId);
    final requestingUserRef = _db.collection('users').doc(requestingUserId);
    batch.update(currentUserRef, {'friendRequestsReceived': FieldValue.arrayRemove([requestingUserId])});
    batch.update(requestingUserRef, {'friendRequestsSent': FieldValue.arrayRemove([currentUserId])});
    await batch.commit();
    debugPrint("UserRepository: Friend request declined.");
  }

  // removeFriend remains the same
  Future<void> removeFriend(String currentUserId, String friendId) async {
    debugPrint("UserRepository: Removing friend $friendId for $currentUserId.");
    final batch = _db.batch();
    final currentUserRef = _db.collection('users').doc(currentUserId);
    final friendUserRef = _db.collection('users').doc(friendId);
    batch.update(currentUserRef, {'friends': FieldValue.arrayRemove([friendId])});
    batch.update(friendUserRef, {'friends': FieldValue.arrayRemove([currentUserId])});
    await batch.commit();
    debugPrint("UserRepository: Friend removed.");
  }

  // blockUser remains the same
  Future<void> blockUser(String currentUserId, String userToBlockId) async {
    debugPrint("UserRepository: Blocking user $userToBlockId for $currentUserId.");
    await removeFriend(currentUserId, userToBlockId).catchError((e) {
      debugPrint("UserRepository: Note - Error removing friend during block (might not be friends): $e");
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
    await _db.collection('chats').doc(chatId).delete().catchError((e){
      debugPrint("UserRepository: Note - Error deleting chat during block: $e");
    });
    debugPrint("UserRepository: User blocked.");
  }

  // unblockUser remains the same
  Future<void> unblockUser(String currentUserId, String userToUnblockId) {
    debugPrint("UserRepository: Unblocking user $userToUnblockId for $currentUserId.");
    return _db.collection('users').doc(currentUserId).update({
      'blockedUsers': FieldValue.arrayRemove([userToUnblockId])
    });
  }


  // --- Match / Swipe Methods ---
  // getPotentialMatches remains the same
  Future<List<DocumentSnapshot>> getPotentialMatches(String currentUserId) async {
    debugPrint("UserRepository: Getting potential matches for $currentUserId.");
    try {
      final userDoc = await _db.collection('users').doc(currentUserId).get();
      if (!userDoc.exists) return [];
      final userData = userDoc.data() as Map<String, dynamic>;
      List<String> blockedUsers = List<String>.from(userData['blockedUsers'] ?? []);
      List<String> friends = List<String>.from(userData['friends'] ?? []);
      final swipesSnapshot = await _db.collection('users').doc(currentUserId).collection('swipes').get();
      final swipedUserIds = swipesSnapshot.docs.map((doc) => doc.id).toList();
      final excludedIds = {currentUserId, ...blockedUsers, ...friends, ...swipedUserIds};

      // Simple query for now, can be refined later
      final querySnapshot = await _db.collection('users').limit(50).get();
      return querySnapshot.docs.where((doc) => !excludedIds.contains(doc.id)).toList();
    } catch (e) {
      debugPrint("UserRepository Error: Failed to get potential matches: $e");
      return [];
    }
  }

  // recordSwipe - Keep notification logic for super_like
  Future<void> recordSwipe(String currentUserId, String otherUserId, String action) async {
    debugPrint("UserRepository: Recording swipe ($action) from $currentUserId to $otherUserId.");
    final userRef = _db.collection('users').doc(currentUserId);
    if (action == 'super_like') {
      await _db.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw Exception("Current user not found.");
        final user = UserModel.fromDoc(userDoc);
        if (user.superLikes < 1) throw Exception("You have no Super Likes left.");
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
    debugPrint("UserRepository: Checking for match between $currentUserId and $otherUserId.");
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
    debugPrint("UserRepository: Creating match between $userId1 and $userId2.");
    final ids = [userId1, userId2]..sort();
    final chatId = ids.join('_');
    final user1Doc = await getUser(userId1); // Fetch user data
    final user2Doc = await getUser(userId2); // Fetch user data
    final batch = _db.batch();
    final chatRef = _db.collection('chats').doc(chatId);
    batch.set(chatRef, {
      'users': ids,
      'usernames': { userId1: user1Doc.username, userId2: user2Doc.username }, // Store usernames
      'lastMessage': 'You matched! Say hello.', // Initial message
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'chatType': 'friend_chat', // Mark as friend chat
      'matchTimestamp': FieldValue.serverTimestamp(), // Record match time
      'unreadFor': [], // Initially no unread messages
    }, SetOptions(merge: true)); // Merge in case chat existed (e.g., from request)
    final user1Ref = _db.collection('users').doc(userId1);
    final user2Ref = _db.collection('users').doc(userId2);
    // Add each other as friends
    batch.update(user1Ref, {'friends': FieldValue.arrayUnion([userId2])});
    batch.update(user2Ref, {'friends': FieldValue.arrayUnion([userId1])});
    // Remove any pending friend requests between them
    batch.update(user1Ref, {'friendRequestsReceived': FieldValue.arrayRemove([userId2]), 'friendRequestsSent': FieldValue.arrayRemove([userId2])});
    batch.update(user2Ref, {'friendRequestsReceived': FieldValue.arrayRemove([userId1]), 'friendRequestsSent': FieldValue.arrayRemove([userId1])});
    await batch.commit();
    // await _gamificationRepository.addXp(userId1, 100, isSeasonal: true); // Removed
    // await _gamificationRepository.addXp(userId2, 100, isSeasonal: true); // Removed
    debugPrint("UserRepository: Match created successfully.");
  }


  // --- User Discovery Methods ---
  // getPaginatedUsers remains the same
  Future<QuerySnapshot> getPaginatedUsers({required int limit, DocumentSnapshot? lastDocument}) {
    debugPrint("UserRepository: Fetching paginated users (limit: $limit).");
    Query query = _db.collection('users').orderBy('username').limit(limit);
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    return query.get();
  }

  // getRecommendedUsers - Remove sorting by level
  Future<List<DocumentSnapshot>> getRecommendedUsers(List<String> interests, String currentUserId) async {
    debugPrint("UserRepository: Fetching recommended users for $currentUserId.");
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
        final aSharedInterests = a.interests.where((i) => interests.contains(i)).length;
        final bSharedInterests = b.interests.where((i) => interests.contains(i)).length;
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
      final originalDocs = querySnapshot.docs.where((doc) => doc.id != currentUserId).toList();
      originalDocs.sort((a, b) => sortedIds.indexOf(a.id).compareTo(sortedIds.indexOf(b.id)));

      // Return the top N recommendations
      return originalDocs.take(30).toList();
    } catch (e) {
      debugPrint("UserRepository Error: Failed to get recommended users: $e");
      return [];
    }
  }


  // searchUsers remains the same
  Stream<QuerySnapshot> searchUsers(String query) {
    debugPrint("UserRepository: Searching users with query '$query'.");
    if (query.isEmpty) return Stream.empty();
    // Simple prefix search
    return _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff') // Standard trick for prefix search
        .limit(20)
        .snapshots();
  }
}