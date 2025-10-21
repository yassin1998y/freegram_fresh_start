import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/action_queue_repository.dart';
import 'package:freegram/repositories/gamification_repository.dart';
import 'package:freegram/repositories/task_repository.dart';

class ChatRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final GamificationRepository _gamificationRepository;
  final TaskRepository _taskRepository;
  final ActionQueueRepository _actionQueueRepository;

  ChatRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    required GamificationRepository gamificationRepository,
    required TaskRepository taskRepository,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = firebaseAuth ?? FirebaseAuth.instance,
        _gamificationRepository = gamificationRepository,
        _taskRepository = taskRepository,
        _actionQueueRepository = locator<ActionQueueRepository>();

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
        'chatType': 'contact_request',
        'initiatorId': currentUser.uid,
        'unreadFor': [],
      }, SetOptions(merge: true));
    }

    return chatId;
  }

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
      // OFFLINE: Queue the action
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

    // ONLINE: Proceed with existing logic
    final chatRef = _db.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) return;

    final chatData = chatDoc.data() as Map<String, dynamic>;
    final chatType = chatData['chatType'] ?? 'friend';

    if (chatType == 'contact_request') {
      final initiatorId = chatData['initiatorId'];
      final messagesFromInitiator = await chatRef
          .collection('messages')
          .where('senderId', isEqualTo: initiatorId)
          .count()
          .get();

      if (senderId == initiatorId && (messagesFromInitiator.count ?? 0) >= 2) {
        throw Exception(
            "You cannot send more than two messages until they reply.");
      }

      if (senderId != initiatorId) {
        throw Exception(
            "You cannot reply until you accept the friend request.");
      }
    }

    await chatRef.collection('messages').add({
      'text': text,
      'imageUrl': imageUrl,
      'senderId': senderId,
      'timestamp': FieldValue.serverTimestamp(),
      'isSeen': false,
      'isDelivered': true,
      'reactions': {},
      'replyToMessageId': replyToMessageId,
      'replyToMessageText': replyToMessageText,
      'replyToImageUrl': replyToImageUrl,
      'replyToSender': replyToSender,
    });

    final otherUserId =
    (chatData['users'] as List).firstWhere((id) => id != senderId);

    await chatRef.update({
      'lastMessage': imageUrl != null ? '📷 Photo' : text,
      'lastMessageIsImage': imageUrl != null,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'unreadFor': FieldValue.arrayUnion([otherUserId]),
    });

    await _gamificationRepository.addXp(senderId, 2, isSeasonal: true);
    await _taskRepository.updateTaskProgress(senderId, 'send_messages', 1);
  }

  Future<void> editMessage(String chatId, String messageId, String newText) {
    final messageRef =
    _db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    return messageRef.update({
      'text': newText,
      'edited': true,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String chatId, String messageId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> deleteChat(String chatId) async {
    final chatRef = _db.collection('chats').doc(chatId);
    final messages = await chatRef.collection('messages').get();
    final batch = _db.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(chatRef);
    return batch.commit();
  }

  Future<void> toggleMessageReaction(
      String chatId, String messageId, String userId, String emoji) async {
    final messageRef =
    _db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    final doc = await messageRef.get();
    final reactions = Map<String, String>.from(doc.data()?['reactions'] ?? {});
    if (reactions[userId] == emoji) {
      reactions.remove(userId);
    } else {
      reactions[userId] = emoji;
    }
    await messageRef.update({'reactions': reactions});
  }

  Future<void> markMultipleMessagesAsSeen(
      String chatId, List<String> messageIds) {
    if (messageIds.isEmpty) return Future.value();
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

  Future<void> resetUnreadCount(String chatId, String userId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .update({'unreadFor': FieldValue.arrayRemove([userId])});
  }

  Future<void> updateTypingStatus(
      String chatId, String userId, bool isTyping) {
    return _db
        .collection('chats')
        .doc(chatId)
        .update({'typingStatus.$userId': isTyping});
  }

  // --- STREAMS ---

  Stream<QuerySnapshot> getChatsStream(String userId) {
    return _db
        .collection('chats')
        .where('users', arrayContains: userId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot> getChatStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots();
  }

  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<int> getUnreadChatCountStream(String userId) {
    return _db
        .collection('chats')
        .where('unreadFor', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}