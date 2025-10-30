// lib/services/message_seen_tracker.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

/// Automatically tracks and marks messages as seen when user is viewing a chat
/// Professional implementation like WhatsApp
class MessageSeenTracker {
  static final MessageSeenTracker _instance = MessageSeenTracker._internal();
  factory MessageSeenTracker() => _instance;
  MessageSeenTracker._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Track active chats to avoid duplicate listeners
  final Map<String, StreamSubscription> _activeListeners = {};
  final Map<String, bool> _isViewingChat = {};

  /// Start tracking a chat when user enters the chat screen
  void startTracking(String chatId) {
    _isViewingChat[chatId] = true;

    if (kDebugMode) {
      debugPrint('[Message Seen Tracker] Started tracking chat: $chatId');
    }

    // Mark existing unread messages as seen immediately
    _markExistingMessagesAsSeen(chatId);

    // Listen for new messages and mark them as seen
    _startRealtimeTracking(chatId);
  }

  /// Stop tracking a chat when user leaves the chat screen
  void stopTracking(String chatId) {
    _isViewingChat[chatId] = false;

    // Cancel the listener after a delay to handle quick screen switches
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isViewingChat[chatId] == false) {
        _activeListeners[chatId]?.cancel();
        _activeListeners.remove(chatId);

        if (kDebugMode) {
          debugPrint('[Message Seen Tracker] Stopped tracking chat: $chatId');
        }
      }
    });
  }

  /// Mark all existing unread messages as seen
  Future<void> _markExistingMessagesAsSeen(String chatId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final chatRef = _firestore.collection('chats').doc(chatId);

      // Get all unseen messages from the other user
      final unreadMessages = await chatRef
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUserId)
          .where('isSeen', isEqualTo: false)
          .get();

      if (unreadMessages.docs.isEmpty) return;

      // Batch update all messages to seen
      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'isSeen': true,
          'seenAt': FieldValue.serverTimestamp(),
        });
      }

      // Update chat document
      batch.update(chatRef, {
        'unreadFor': FieldValue.arrayRemove([currentUserId]),
        'lastSeenBy.$currentUserId': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (kDebugMode) {
        debugPrint(
            '[Message Seen Tracker] Marked ${unreadMessages.docs.length} messages as seen in chat: $chatId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Message Seen Tracker] Error marking messages as seen: $e');
      }
    }
  }

  /// Listen for new messages in real-time and mark them as seen
  void _startRealtimeTracking(String chatId) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // Cancel existing listener if any
    _activeListeners[chatId]?.cancel();

    // Create new listener
    final chatRef = _firestore.collection('chats').doc(chatId);
    _activeListeners[chatId] = chatRef
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .where('isSeen', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(10) // Only track recent messages
        .snapshots()
        .listen((snapshot) {
      // Only mark as seen if user is still viewing the chat
      if (_isViewingChat[chatId] == true) {
        _markSnapshotMessagesAsSeen(chatId, snapshot.docs, currentUserId);
      }
    });
  }

  /// Mark messages from a snapshot as seen
  Future<void> _markSnapshotMessagesAsSeen(
    String chatId,
    List<QueryDocumentSnapshot> docs,
    String currentUserId,
  ) async {
    if (docs.isEmpty) return;

    try {
      final batch = _firestore.batch();
      final chatRef = _firestore.collection('chats').doc(chatId);

      for (final doc in docs) {
        batch.update(doc.reference, {
          'isSeen': true,
          'seenAt': FieldValue.serverTimestamp(),
        });
      }

      // Update chat document
      batch.update(chatRef, {
        'unreadFor': FieldValue.arrayRemove([currentUserId]),
        'lastSeenBy.$currentUserId': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (kDebugMode) {
        debugPrint(
            '[Message Seen Tracker] Auto-marked ${docs.length} new messages as seen');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Message Seen Tracker] Error auto-marking messages: $e');
      }
    }
  }

  /// Cleanup all listeners (call on app dispose)
  void dispose() {
    for (final listener in _activeListeners.values) {
      listener.cancel();
    }
    _activeListeners.clear();
    _isViewingChat.clear();

    if (kDebugMode) {
      debugPrint('[Message Seen Tracker] Disposed all listeners');
    }
  }
}
