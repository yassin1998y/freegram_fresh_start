// lib/repositories/user_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:flutter/foundation.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/gamification_repository.dart';
import 'package:freegram/repositories/notification_repository.dart';
import 'package:freegram/services/sonar/local_cache_service.dart';
import 'package:freegram/repositories/action_queue_repository.dart';


class UserRepository {
  final FirebaseFirestore _db;
  final rtdb.FirebaseDatabase _rtdb;
  final NotificationRepository _notificationRepository;
  final GamificationRepository _gamificationRepository;
  final LocalCacheService _localCacheService;
  final ActionQueueRepository _actionQueueRepository;

  UserRepository({
    FirebaseFirestore? firestore,
    rtdb.FirebaseDatabase? rtdbInstance,
    required NotificationRepository notificationRepository,
    required GamificationRepository gamificationRepository,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _rtdb = rtdbInstance ?? rtdb.FirebaseDatabase.instance,
        _notificationRepository = notificationRepository,
        _gamificationRepository = gamificationRepository,
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
        .map((doc) {
      if (!doc.exists) {
        debugPrint('User stream warning: User not found for ID: $userId');
        throw Exception('User stream error: User not found for ID: $userId');
      }
      return UserModel.fromDoc(doc);
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    // Ensure uidShort is not accidentally overwritten if not provided
    data.remove('uidShort');
    // Ensure id is not accidentally overwritten
    data.remove('id');
    debugPrint("UserRepository: Updating user $uid with data: $data");
    return _db.collection('users').doc(uid).update(data);
  }

  // ** NEW METHOD **
  /// Fetches user data for multiple uidShorts.
  Future<Map<String, UserModel>> getUsersByUidShorts(List<String> uidShorts) async {
    if (uidShorts.isEmpty) {
      return {};
    }
    debugPrint("UserRepository: Fetching users for uidShorts: $uidShorts");
    try {
      // Firestore 'whereIn' query is limited to 30 items per query.
      // We need to batch the requests if uidShorts.length > 30.
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
          results[user.uidShort] = user; // Map by uidShort for easy lookup
        }
        debugPrint("UserRepository: Fetched batch for ${batch.length} uidShorts, found ${querySnapshot.docs.length} users.");
      }

      debugPrint("UserRepository: Finished fetching for uidShorts. Total found: ${results.length}");
      return results;
    } catch (e) {
      debugPrint("UserRepository Error: Failed to fetch users by uidShorts: $e");
      return {}; // Return empty map on error
    }
  }


  // --- Presence ---
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
  Future<void> sendWave(String fromUserId, String toUserId) async {
    // This method now correctly sends a *server-side* notification
    debugPrint("UserRepository: Sending server-side wave from $fromUserId to $toUserId");
    try {
      final fromUser = await getUser(fromUserId);
      await _notificationRepository.addNotification(
        userId: toUserId,
        type: 'nearbyWave',
        fromUserId: fromUserId,
        fromUsername: fromUser.username,
        fromUserPhotoUrl: fromUser.photoUrl,
        message: 'Waved at you!',
      );
      debugPrint("UserRepository: Server-side wave notification sent successfully.");
    } catch (e) {
      debugPrint("UserRepository Error: Failed sending server-side wave: $e");
      // Optionally rethrow if SyncManager needs to know about the failure
      // rethrow;
    }
  }


  Future<void> updateNearbyStatus(String userId, String message, String emoji) {
    debugPrint("UserRepository: Updating nearby status for $userId");
    return _db.collection('users').doc(userId).update({
      'nearbyStatusMessage': message,
      'nearbyStatusEmoji': emoji,
      'nearbyDataVersion': FieldValue.increment(1),
    });
  }

  Future<void> updateSharedMusic(String userId, Map<String, String>? musicData) {
    debugPrint("UserRepository: Updating shared music for $userId");
    return _db.collection('users').doc(userId).update({
      'sharedMusicTrack': musicData ?? FieldValue.delete(),
      'nearbyDataVersion': FieldValue.increment(1),
    });
  }


  // --- Friendship Methods ---
  Future<void> sendFriendRequest(String fromUserId, String toUserId, {bool isSync = false}) async {
    // CRITICAL: Ensure 'toUserId' passed here is the FULL UUID, not the short one.
    // The SyncManager is now responsible for resolving the ID before calling this.
    if (fromUserId == toUserId) {
      debugPrint("UserRepository Warning: Attempted to send friend request to self.");
      return;
    }

    // Removed offline queuing logic - it's handled before calling this now.

    debugPrint("UserRepository: Sending friend request from $fromUserId to $toUserId via Firebase.");
    final batch = _db.batch();
    final fromUserRef = _db.collection('users').doc(fromUserId);
    final toUserRef = _db.collection('users').doc(toUserId); // Use the full ID

    try {
      // Fetch documents using the full IDs
      final fromUserDoc = await fromUserRef.get();
      final toUserDoc = await toUserRef.get();

      // Check if documents exist using the full IDs
      if (!fromUserDoc.exists || !toUserDoc.exists) {
        // Log which user was not found
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

      // Checks remain the same (using full IDs now)
      if (fromFriends.contains(toUserId)) throw Exception("Already friends.");
      if (fromSent.contains(toUserId)) throw Exception("Request already sent.");
      if (fromReceived.contains(toUserId)) {
        debugPrint("UserRepository: Request already received from $toUserId. Accepting instead.");
        throw Exception("User has already sent you a request. Check your requests list.");
      }
      if (fromBlocked.contains(toUserId)) throw Exception("You have blocked this user.");
      if (toBlocked.contains(fromUserId)) throw Exception("This user has blocked you.");

      // Updates use the full IDs
      batch.update(fromUserRef, {'friendRequestsSent': FieldValue.arrayUnion([toUserId])});
      batch.update(toUserRef, {'friendRequestsReceived': FieldValue.arrayUnion([fromUserId])});

      await batch.commit();

      final fromUser = UserModel.fromDoc(fromUserDoc);
      await _notificationRepository.addNotification(
        userId: toUserId, type: 'friend_request_received', fromUserId: fromUserId,
        fromUsername: fromUser.username, fromUserPhotoUrl: fromUser.photoUrl,
      );
      debugPrint("UserRepository: Friend request sent and notification triggered.");

    } catch (e) {
      // Log the error with full IDs for clarity
      debugPrint("UserRepository Error: Failed to send friend request from $fromUserId to $toUserId: $e");
      rethrow;
    }
  }


  // --- Other friendship methods (accept, decline, remove, block, unblock) remain the same ---
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
    batch.set(chatRef, {'chatType': 'friend_chat'}, SetOptions(merge: true));

    await batch.commit();
    await _gamificationRepository.addXp(currentUserId, 50, isSeasonal: true);
    await _gamificationRepository.addXp(requestingUserId, 50, isSeasonal: true);
    final currentUser = await getUser(currentUserId);
    await _notificationRepository.addNotification(
      userId: requestingUserId, type: 'request_accepted', fromUserId: currentUserId,
      fromUsername: currentUser.username, fromUserPhotoUrl: currentUser.photoUrl,
    );
    debugPrint("UserRepository: Friend request accepted.");
  }

  Future<void> declineFriendRequest(String currentUserId, String requestingUserId) async {
    debugPrint("UserRepository: Declining friend request from $requestingUserId for $currentUserId.");
    final batch = _db.batch();
    final currentUserRef = _db.collection('users').doc(currentUserId);
    final requestingUserRef = _db.collection('users').doc(requestingUserId);
    batch.update(currentUserRef, {'friendRequestsReceived': FieldValue.arrayRemove([requestingUserId])});
    batch.update(requestingUserRef, {'friendRequestsSent': FieldValue.arrayRemove([currentUserId])});
    final ids = [currentUserId, requestingUserId]..sort();
    final chatId = ids.join('_');
    final chatRef = _db.collection('chats').doc(chatId);
    // Optional: Delete chat if it was only a request chat?
    // final chatDoc = await chatRef.get();
    // if (chatDoc.exists && chatDoc.data()?['chatType'] == 'contact_request') {
    //    batch.delete(chatRef);
    // }
    await batch.commit();
    debugPrint("UserRepository: Friend request declined.");
  }

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

  Future<void> blockUser(String currentUserId, String userToBlockId) async {
    debugPrint("UserRepository: Blocking user $userToBlockId for $currentUserId.");
    // Attempt to remove friend first, ignore error if they weren't friends
    await removeFriend(currentUserId, userToBlockId).catchError((e) {
      debugPrint("UserRepository: Note - Error removing friend during block (might not be friends): $e");
    });
    // Add to blocker's list
    await _db.collection('users').doc(currentUserId).update({
      'blockedUsers': FieldValue.arrayUnion([userToBlockId])
    });
    // Remove any pending requests between them
    await _db.collection('users').doc(userToBlockId).update({
      'friendRequestsReceived': FieldValue.arrayRemove([currentUserId]),
      'friendRequestsSent': FieldValue.arrayRemove([currentUserId]),
    });
    await _db.collection('users').doc(currentUserId).update({
      'friendRequestsReceived': FieldValue.arrayRemove([userToBlockId]),
      'friendRequestsSent': FieldValue.arrayRemove([userToBlockId]),
    });
    // Delete chat between them
    final ids = [currentUserId, userToBlockId]..sort();
    final chatId = ids.join('_');
    await _db.collection('chats').doc(chatId).delete().catchError((e){
      debugPrint("UserRepository: Note - Error deleting chat during block: $e");
    });
    debugPrint("UserRepository: User blocked.");
  }

  Future<void> unblockUser(String currentUserId, String userToUnblockId) {
    debugPrint("UserRepository: Unblocking user $userToUnblockId for $currentUserId.");
    return _db.collection('users').doc(currentUserId).update({
      'blockedUsers': FieldValue.arrayRemove([userToUnblockId])
    });
  }


  // --- Match / Swipe Methods ---
  Future<List<DocumentSnapshot>> getPotentialMatches(String currentUserId) async {
    // ... (remains the same) ...
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

      final querySnapshot = await _db.collection('users').limit(50).get();
      return querySnapshot.docs.where((doc) => !excludedIds.contains(doc.id)).toList();
    } catch (e) {
      debugPrint("UserRepository Error: Failed to get potential matches: $e");
      return []; // Return empty list on error
    }
  }

  Future<void> recordSwipe(String currentUserId, String otherUserId, String action) async {
    // ... (remains the same) ...
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
      await _notificationRepository.addNotification(
        userId: otherUserId, type: 'super_like', fromUserId: currentUserId,
        fromUsername: currentUserModel.username, fromUserPhotoUrl: currentUserModel.photoUrl,
      );
    }
  }

  Future<bool> checkForMatch(String currentUserId, String otherUserId) async {
    // ... (remains the same) ...
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

  Future<void> createMatch(String userId1, String userId2) async {
    // ... (remains the same) ...
    debugPrint("UserRepository: Creating match between $userId1 and $userId2.");
    final ids = [userId1, userId2]..sort();
    final chatId = ids.join('_');
    final user1Doc = await getUser(userId1);
    final user2Doc = await getUser(userId2);
    final batch = _db.batch();
    final chatRef = _db.collection('chats').doc(chatId);
    batch.set(chatRef, {
      'users': ids,
      'usernames': { userId1: user1Doc.username, userId2: user2Doc.username },
      'lastMessage': 'You matched! Say hello.',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'chatType': 'friend_chat',
      'matchTimestamp': FieldValue.serverTimestamp(),
      'unreadFor': [],
    }, SetOptions(merge: true));
    final user1Ref = _db.collection('users').doc(userId1);
    final user2Ref = _db.collection('users').doc(userId2);
    batch.update(user1Ref, {'friends': FieldValue.arrayUnion([userId2])});
    batch.update(user2Ref, {'friends': FieldValue.arrayUnion([userId1])});
    batch.update(user1Ref, {'friendRequestsReceived': FieldValue.arrayRemove([userId2]), 'friendRequestsSent': FieldValue.arrayRemove([userId2])});
    batch.update(user2Ref, {'friendRequestsReceived': FieldValue.arrayRemove([userId1]), 'friendRequestsSent': FieldValue.arrayRemove([userId1])});
    await batch.commit();
    await _gamificationRepository.addXp(userId1, 100, isSeasonal: true);
    await _gamificationRepository.addXp(userId2, 100, isSeasonal: true);
    debugPrint("UserRepository: Match created successfully.");
  }

  // --- User Discovery Methods ---
  Future<QuerySnapshot> getPaginatedUsers({required int limit, DocumentSnapshot? lastDocument}) {
    // ... (remains the same) ...
    debugPrint("UserRepository: Fetching paginated users (limit: $limit).");
    Query query = _db.collection('users').orderBy('username').limit(limit);
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    return query.get();
  }

  Future<List<DocumentSnapshot>> getRecommendedUsers(List<String> interests, String currentUserId) async {
    // ... (remains the same) ...
    debugPrint("UserRepository: Fetching recommended users for $currentUserId.");
    if (interests.isEmpty) return [];
    try {
      final querySnapshot = await _db
          .collection('users')
          .where('interests', arrayContainsAny: interests)
          .limit(50)
          .get();
      final candidates = querySnapshot.docs
          .where((doc) => doc.id != currentUserId)
          .map((doc) => UserModel.fromDoc(doc))
          .toList();
      candidates.sort((a, b) {
        final aSharedInterests = a.interests.where((i) => interests.contains(i)).length;
        final bSharedInterests = b.interests.where((i) => interests.contains(i)).length;
        int interestComparison = bSharedInterests.compareTo(aSharedInterests);
        if (interestComparison != 0) return interestComparison;
        return b.level.compareTo(a.level);
      });
      final sortedIds = candidates.map((u) => u.id).toList();
      final originalDocs = querySnapshot.docs.where((doc) => doc.id != currentUserId).toList();
      originalDocs.sort((a, b) => sortedIds.indexOf(a.id).compareTo(sortedIds.indexOf(b.id)));
      return originalDocs.take(30).toList();
    } catch (e) {
      debugPrint("UserRepository Error: Failed to get recommended users: $e");
      return [];
    }
  }

  Stream<QuerySnapshot> searchUsers(String query) {
    // ... (remains the same) ...
    debugPrint("UserRepository: Searching users with query '$query'.");
    if (query.isEmpty) return Stream.empty();
    return _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .snapshots();
  }
}