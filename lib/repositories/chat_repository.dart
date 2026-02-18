import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/action_queue_repository.dart';
import 'package:freegram/utils/app_constants.dart';
import 'package:freegram/utils/firestore_error_handler.dart';
import 'package:path/path.dart' as p;
// import 'package:freegram/repositories/gamification_repository.dart'; // Removed
// import 'package:freegram/repositories/task_repository.dart'; // Removed

class ChatRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  // final GamificationRepository _gamificationRepository; // Removed
  // final TaskRepository _taskRepository; // Removed
  final ActionQueueRepository _actionQueueRepository;

  ChatRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    FirebaseStorage? firebaseStorage,
    // required GamificationRepository gamificationRepository, // Removed
    // required TaskRepository taskRepository, // Removed
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = firebaseAuth ?? FirebaseAuth.instance,
        _storage = firebaseStorage ?? FirebaseStorage.instance,
        // _gamificationRepository = gamificationRepository, // Removed
        // _taskRepository = taskRepository, // Removed
        _actionQueueRepository = locator<ActionQueueRepository>();

  final _messageSentController = StreamController<void>.broadcast();
  Stream<void> get onMessageSent => _messageSentController.stream;

  // startOrGetChat remains the same
  Future<String> startOrGetChat(
      String otherUserId, String otherUsername) async {
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

  /// Sends a message with atomic chat update.
  ///
  /// Uses WriteBatch to ensure message creation and chat document update
  /// happen atomically, preventing inconsistent state.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    String? text,
    String? imageUrl,
    String? audioUrl,
    Duration? audioDuration,
    List<double>? waveform,
    String? replyToMessageId,
    String? replyToMessageText,
    String? replyToImageUrl,
    String? replyToSender,
    // Story reply context (Facebook-style private story replies)
    String? storyReplyId,
    String? storyThumbnailUrl,
    String? storyMediaUrl,
    String? storyMediaType,
    String? storyAuthorId,
    String? storyAuthorUsername,
  }) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      // Offline: Queue the action
      final payload = {
        'chatId': chatId,
        'senderId': senderId,
        'text': text,
        'imageUrl': imageUrl,
        'audioUrl': audioUrl,
        'audioDurationMs': audioDuration?.inMilliseconds,
        'waveform': waveform,
        'replyToMessageId': replyToMessageId,
        'replyToMessageText': replyToMessageText,
        'replyToImageUrl': replyToImageUrl,
        'replyToSender': replyToSender,
        'storyReplyId': storyReplyId,
        'storyThumbnailUrl': storyThumbnailUrl,
        'storyMediaUrl': storyMediaUrl,
        'storyMediaType': storyMediaType,
        'storyAuthorId': storyAuthorId,
        'storyAuthorUsername': storyAuthorUsername,
      };
      await _actionQueueRepository.addAction(
          type: 'send_online_message', payload: payload);
      return;
    }

    // Online: Proceed with atomic batch write
    final chatRef = _db.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) return; // Exit if chat doesn't exist

    final chatData = chatDoc.data() as Map<String, dynamic>;
    final chatType =
        chatData['chatType'] ?? 'friend'; // Default to 'friend' if type missing

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
          throw Exception(ErrorMessages.cannotSendMessage);
        }
      } else {
        // If sender is NOT the initiator in a 'contact_request' chat
        throw Exception(ErrorMessages.mustAcceptFirst);
      }
    }

    // Prepare message data
    final messageData = <String, dynamic>{
      'text': text,
      'imageUrl': imageUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (audioDuration != null)
        'audioDurationMs': audioDuration.inMilliseconds,
      if (waveform != null) 'waveform': waveform,
      'senderId': senderId,
      'timestamp': FieldValue.serverTimestamp(),
      'isSeen': false,
      'isDelivered': true, // Assume delivered if online
      'reactions': {},
      'replyToMessageId': replyToMessageId,
      'replyToMessageText': replyToMessageText,
      'replyToImageUrl': replyToImageUrl,
      'replyToSender': replyToSender,
      // Story reply context
      if (storyReplyId != null) 'storyReplyId': storyReplyId,
      if (storyThumbnailUrl != null) 'storyThumbnailUrl': storyThumbnailUrl,
      if (storyMediaUrl != null) 'storyMediaUrl': storyMediaUrl,
      if (storyMediaType != null) 'storyMediaType': storyMediaType,
      if (storyAuthorId != null) 'storyAuthorId': storyAuthorId,
      if (storyAuthorUsername != null)
        'storyAuthorUsername': storyAuthorUsername,
    };

    // Determine last message preview text
    String lastMessagePreview;
    if (audioUrl != null) {
      lastMessagePreview = '🎙️ Voice message';
    } else if (storyReplyId != null) {
      lastMessagePreview = '📸 Story reply';
    } else if (imageUrl != null) {
      lastMessagePreview = '📷 Photo';
    } else {
      lastMessagePreview = text ?? '';
    }

    final otherUserId = (chatData['users'] as List)
        .firstWhere((id) => id != senderId, orElse: () => '');

    // Use WriteBatch for atomic operations
    final batch = _db.batch();

    // Generate message ID and add to batch
    final messageRef = chatRef.collection('messages').doc();
    batch.set(messageRef, messageData);

    // Update chat document in same batch
    if (otherUserId.isNotEmpty) {
      batch.update(chatRef, {
        'lastMessage': lastMessagePreview,
        'lastMessageIsImage': imageUrl != null,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'unreadFor':
            FieldValue.arrayUnion([otherUserId]), // Mark unread for recipient
      });
    } else {
      // Handle case where other user ID couldn't be found (e.g., chat with self?)
      batch.update(chatRef, {
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
    }

    // Update user stats
    final userRef = _db.collection('users').doc(senderId);
    batch.update(userRef, {
      'totalMessagesSent': FieldValue.increment(1),
      'socialPoints': FieldValue.increment(1),
    });

    // Commit batch atomically
    await batch.commit();

    // Trigger onMessageSent stream
    _messageSentController.add(null);

    // --- Removed Gamification/Task calls ---
    // await _gamificationRepository.addXp(senderId, 2, isSeasonal: true);
    // await _taskRepository.updateTaskProgress(senderId, 'send_messages', 1);
  }

  /// Sends a system milestone message to the chat.
  Future<void> sendSystemMilestone(
      String chatId, String achievementName) async {
    final chatRef = _db.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) return;

    final chatData = chatDoc.data() as Map<String, dynamic>;
    final users = List<String>.from(chatData['users'] ?? []);
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final messageData = <String, dynamic>{
      'text':
          '✨ ${currentUser.displayName ?? 'User'} just earned the $achievementName badge!',
      'senderId': 'system',
      'timestamp': FieldValue.serverTimestamp(),
      'isSeen': false,
      'isDelivered': true,
      'isSystemMessage': true,
      'milestoneName': achievementName,
    };

    final batch = _db.batch();
    final messageRef = chatRef.collection('messages').doc();
    batch.set(messageRef, messageData);

    // Update last message preview
    batch.update(chatRef, {
      'lastMessage': '✨ Achievement: $achievementName',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'unreadFor': FieldValue.arrayUnion(
          users.where((u) => u != currentUser.uid).toList()),
    });

    await batch.commit();
  }

  /// Broadcasts a system milestone message to active chat sessions.
  Future<void> broadcastSystemMilestone(
      String userId, String achievementName) async {
    try {
      // Get most recent 5 chats to avoid spamming too many groups but reach active ones
      final snapshot = await _db
          .collection('chats')
          .where('users', arrayContains: userId)
          .orderBy('lastMessageTimestamp', descending: true)
          .limit(5)
          .get();

      for (final doc in snapshot.docs) {
        await sendSystemMilestone(doc.id, achievementName);
      }
    } catch (e) {
      debugPrint('ChatRepository: Error broadcasting milestone: $e');
    }
  }

  // editMessage remains the same
  Future<void> editMessage(String chatId, String messageId, String newText) {
    final messageRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
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

  /// Toggles a message reaction with transaction safety.
  ///
  /// Uses Firestore transaction to ensure atomic read-modify-write,
  /// preventing lost reactions when multiple users react simultaneously.
  Future<void> toggleMessageReaction(
      String chatId, String messageId, String userId, String emoji) async {
    final messageRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    // Use transaction for atomic read-modify-write
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(messageRef);

      if (!doc.exists) {
        throw Exception(ErrorMessages.messageNotFound);
      }

      final reactions =
          Map<String, String>.from(doc.data()?['reactions'] ?? {});

      // If user already reacted with the same emoji, remove reaction
      if (reactions[userId] == emoji) {
        reactions.remove(userId);
      } else {
        // Otherwise, add/update reaction
        reactions[userId] = emoji;
      }

      transaction.update(messageRef, {'reactions': reactions});
    });
  }

  // markMultipleMessagesAsSeen remains the same
  Future<void> markMultipleMessagesAsSeen(
      String chatId, List<String> messageIds) {
    if (messageIds.isEmpty) {
      return Future.value(); // No need for batch if list is empty
    }
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
    return _db.collection('chats').doc(chatId).update({
      'unreadFor': FieldValue.arrayRemove([userId])
    });
  }

  // updateTypingStatus remains the same
  Future<void> updateTypingStatus(String chatId, String userId, bool isTyping) {
    // Use dot notation for nested fields
    return _db
        .collection('chats')
        .doc(chatId)
        .update({'typingStatus.$userId': isTyping});
  }

  // --- STREAMS ---

  /// Provides a real-time stream of user's chat list with pagination support.
  ///
  /// Chats are ordered by last message timestamp (most recent first).
  /// The stream automatically updates when new messages arrive or chat data changes.
  ///
  /// [userId] - The unique identifier of the user
  /// [limit] - Maximum number of chats to return (defaults to AppConstants.chatListInitialLimit)
  ///
  /// Returns a [Stream<QuerySnapshot>] of chat documents.
  Stream<QuerySnapshot> getChatsStream(String userId,
      {int limit = AppConstants.chatListInitialLimit}) {
    return _db
        .collection('chats')
        .where('users', arrayContains: userId)
        .orderBy('lastMessageTimestamp', descending: true)
        .limit(limit) // Limit chats initially
        .snapshots();
  }

  /// Loads additional chats for pagination beyond the initial limit.
  ///
  /// [userId] - The unique identifier of the user
  /// [lastDocument] - The last document from the previous page (for cursor-based pagination)
  /// [limit] - Number of additional chats to load (defaults to AppConstants.chatListInitialLimit)
  ///
  /// Returns a [Future<QuerySnapshot>] containing the next page of chats.
  Future<QuerySnapshot> loadMoreChats(
      String userId, DocumentSnapshot? lastDocument,
      {int limit = AppConstants.chatListInitialLimit}) async {
    Query query = _db
        .collection('chats')
        .where('users', arrayContains: userId)
        .orderBy('lastMessageTimestamp', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return await query.get();
  }

  // getChatStream remains the same
  Stream<DocumentSnapshot> getChatStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots();
  }

  // getMessagesStream with pagination limit to reduce Firestore reads
  Stream<QuerySnapshot> getMessagesStream(String chatId, {int limit = 50}) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit) // CRITICAL: Limit messages to reduce reads
        .snapshots();
  }

  // getUnreadChatCountStream remains the same
  Stream<int> getUnreadChatCountStream(String userId) {
    return _db
        .collection('chats')
        .where('unreadFor', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot
            .docs.length); // Count documents where user is in 'unreadFor'
  }

  Future<void> sendVoiceMessage({
    required String chatId,
    required String senderId,
    required File audioFile,
    required Duration audioDuration,
    List<double>? waveform,
    String? replyToMessageId,
    String? replyToMessageText,
    String? replyToImageUrl,
    String? replyToSender,
  }) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      throw Exception(ErrorMessages.voiceMessageOffline);
    }

    final audioUrl = await _uploadChatAudio(
      audioFile: audioFile,
      chatId: chatId,
      senderId: senderId,
    );

    await sendMessage(
      chatId: chatId,
      senderId: senderId,
      audioUrl: audioUrl,
      audioDuration: audioDuration,
      waveform: waveform,
      replyToMessageId: replyToMessageId,
      replyToMessageText: replyToMessageText,
      replyToImageUrl: replyToImageUrl,
      replyToSender: replyToSender,
    );
  }

  Future<String> _uploadChatAudio({
    required File audioFile,
    required String chatId,
    required String senderId,
  }) async {
    final originalName = p.basename(audioFile.path);
    final fileExtension = p.extension(audioFile.path).replaceFirst('.', '');
    final safeExtension =
        fileExtension.isEmpty ? 'm4a' : fileExtension.toLowerCase();

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${senderId}_$originalName';
    final Reference ref = _storage.ref().child('chat_audio/$chatId/$fileName');

    final metadata = SettableMetadata(
      contentType: 'audio/$safeExtension',
    );

    await ref.putFile(audioFile, metadata);
    return ref.getDownloadURL();
  }
}
