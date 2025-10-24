import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/action_queue_repository.dart';
// import 'package:freegram/repositories/gamification_repository.dart'; // Removed
// import 'package:freegram/repositories/task_repository.dart'; // Removed

class ChatRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  // final GamificationRepository _gamificationRepository; // Removed
  // final TaskRepository _taskRepository; // Removed
  final ActionQueueRepository _actionQueueRepository;

  ChatRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    // required GamificationRepository gamificationRepository, // Removed
    // required TaskRepository taskRepository, // Removed
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = firebaseAuth ?? FirebaseAuth.instance,
  // _gamificationRepository = gamificationRepository, // Removed
  // _taskRepository = taskRepository, // Removed
        _actionQueueRepository = locator<ActionQueueRepository>();

  // startOrGetChat remains the same
  Future<String> startOrGetChat(String otherUserId, String otherUsername) async {
    final currentUser = _auth.currentUser!;
    final ids = [currentUser.uid, otherUserId];
    ids.sort();
    final chatId = ids.join('_');
    final chatRef = _db.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      await chatRef.set({
        'users': [currentUser.uid, otherUserId],
        'usernames': {
          currentUser.uid: currentUser.displayName ?? 'Anonymous',
          otherUserId: otherUsername,
        },
        'chatType': 'contact_request', // Keep initial type logic
        'initiatorId': currentUser.uid,
        'unreadFor': [], // Start empty
      }, SetOptions(merge: true));
    }
    // If chat exists, don't overwrite type, just return ID
    return chatId;
  }


  // sendMessage updated to remove gamification/task calls
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    String? text,
    String? imageUrl,
    String? replyToMessageId,
    String? replyToMessageText,
    String? replyToImageUrl,
    String? replyToSender,
  }) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      // Offline: Queue the action
      final payload = {
        'chatId': chatId,
        'senderId': senderId,
        'text': text,
        'imageUrl': imageUrl,
        'replyToMessageId': replyToMessageId,
        'replyToMessageText': replyToMessageText,
        'replyToImageUrl': replyToImageUrl,
        'replyToSender': replyToSender,
      };
      await _actionQueueRepository.addAction(
          type: 'send_online_message', payload: payload);
      return;
    }

    // Online: Proceed with existing logic
    final chatRef = _db.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) return; // Exit if chat doesn't exist

    final chatData = chatDoc.data() as Map<String, dynamic>;
    final chatType = chatData['chatType'] ?? 'friend'; // Default to 'friend' if type missing

    // Keep contact request logic
    if (chatType == 'contact_request') {
      final initiatorId = chatData['initiatorId'];
      // Only check message count if the sender is the initiator
      if (senderId == initiatorId) {
        final messagesFromInitiator = await chatRef
            .collection('messages')
            .where('senderId', isEqualTo: initiatorId)
            .count()
            .get();

        // Allow max 2 messages before reply/accept
        if ((messagesFromInitiator.count ?? 0) >= 2) {
          throw Exception(
              "You cannot send more than two messages until they reply or accept.");
        }
      } else {
        // If sender is NOT the initiator in a 'contact_request' chat
        throw Exception(
            "You cannot reply until you accept the friend request.");
      }
    }

    // Add message to subcollection
    await chatRef.collection('messages').add({
      'text': text,
      'imageUrl': imageUrl,
      'senderId': senderId,
      'timestamp': FieldValue.serverTimestamp(),
      'isSeen': false,
      'isDelivered': true, // Assume delivered if online
      'reactions': {},
      'replyToMessageId': replyToMessageId,
      'replyToMessageText': replyToMessageText,
      'replyToImageUrl': replyToImageUrl,
      'replyToSender': replyToSender,
    });

    // Update the main chat document for previews and unread status
    final otherUserId =
    (chatData['users'] as List).firstWhere((id) => id != senderId, orElse: () => '');

    if (otherUserId.isNotEmpty) {
      await chatRef.update({
        'lastMessage': imageUrl != null ? '📷 Photo' : text,
        'lastMessageIsImage': imageUrl != null,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'unreadFor': FieldValue.arrayUnion([otherUserId]), // Mark unread for recipient
      });
    } else {
      // Handle case where other user ID couldn't be found (e.g., chat with self?)
      await chatRef.update({
        'lastMessage': imageUrl != null ? '📷 Photo' : text,
        'lastMessageIsImage': imageUrl != null,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
    }

    // --- Removed Gamification/Task calls ---
    // await _gamificationRepository.addXp(senderId, 2, isSeasonal: true);
    // await _taskRepository.updateTaskProgress(senderId, 'send_messages', 1);
  }


  // editMessage remains the same
  Future<void> editMessage(String chatId, String messageId, String newText) {
    final messageRef =
    _db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    return messageRef.update({
      'text': newText,
      'edited': true,
      'timestamp': FieldValue.serverTimestamp(), // Update timestamp on edit
    });
  }

  // deleteMessage remains the same
  Future<void> deleteMessage(String chatId, String messageId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  // deleteChat remains the same
  Future<void> deleteChat(String chatId) async {
    final chatRef = _db.collection('chats').doc(chatId);
    // Delete all messages in the subcollection first
    final messages = await chatRef.collection('messages').get();
    final batch = _db.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    // Then delete the chat document itself
    batch.delete(chatRef);
    return batch.commit();
  }

  // toggleMessageReaction remains the same
  Future<void> toggleMessageReaction(
      String chatId, String messageId, String userId, String emoji) async {
    final messageRef =
    _db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    final doc = await messageRef.get();
    final reactions = Map<String, String>.from(doc.data()?['reactions'] ?? {});
    // If user already reacted with the same emoji, remove reaction
    if (reactions[userId] == emoji) {
      reactions.remove(userId);
    } else {
      // Otherwise, add/update reaction
      reactions[userId] = emoji;
    }
    await messageRef.update({'reactions': reactions});
  }

  // markMultipleMessagesAsSeen remains the same
  Future<void> markMultipleMessagesAsSeen(
      String chatId, List<String> messageIds) {
    if (messageIds.isEmpty) return Future.value(); // No need for batch if list is empty
    final batch = _db.batch();
    for (final messageId in messageIds) {
      final messageRef = _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);
      batch.update(messageRef, {'isSeen': true});
    }
    return batch.commit();
  }

  // resetUnreadCount remains the same
  Future<void> resetUnreadCount(String chatId, String userId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .update({'unreadFor': FieldValue.arrayRemove([userId])});
  }

  // updateTypingStatus remains the same
  Future<void> updateTypingStatus(
      String chatId, String userId, bool isTyping) {
    // Use dot notation for nested fields
    return _db
        .collection('chats')
        .doc(chatId)
        .update({'typingStatus.$userId': isTyping});
  }


  // --- STREAMS ---

  // getChatsStream remains the same
  Stream<QuerySnapshot> getChatsStream(String userId) {
    return _db
        .collection('chats')
        .where('users', arrayContains: userId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots();
  }

  // getChatStream remains the same
  Stream<DocumentSnapshot> getChatStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots();
  }

  // getMessagesStream remains the same
  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // getUnreadChatCountStream remains the same
  Stream<int> getUnreadChatCountStream(String userId) {
    return _db
        .collection('chats')
        .where('unreadFor', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length); // Count documents where user is in 'unreadFor'
  }
}