import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/screens/gift_detail_screen.dart';
import 'package:freegram/widgets/gift_notification_overlay.dart';

/// Service that manages gift notifications and displays overlays
class GiftNotificationService {
  static final GiftNotificationService _instance =
      GiftNotificationService._internal();
  factory GiftNotificationService() => _instance;
  GiftNotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  Box<String>? _shownNotificationsBox;
  bool _isInitialized = false;

  // Use GlobalKey to access navigator context
  GlobalKey<NavigatorState>? _navigatorKey;

  // Queue to manage multiple notifications
  final List<Map<String, dynamic>> _notificationQueue = [];
  bool _isShowingOverlay = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Open Hive box for tracking shown notifications
      _shownNotificationsBox =
          await Hive.openBox<String>('shown_gift_notifications');

      _isInitialized = true;
      debugPrint('[GiftNotificationService] Initialized successfully');
    } catch (e) {
      debugPrint('[GiftNotificationService] Initialization error: $e');
    }
  }

  /// Set the navigator key (call this from main app)
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
    debugPrint('[GiftNotificationService] Navigator key set');
  }

  /// Start listening for gift notifications
  void startListening() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint(
          '[GiftNotificationService] No user logged in, skipping listener');
      return;
    }

    // Cancel existing subscription
    _notificationSubscription?.cancel();

    debugPrint(
        '[GiftNotificationService] Starting listener for user: ${currentUser.uid}');

    // Listen to unread gift notifications from user subcollection
    _notificationSubscription = _db
        .collection('users')
        .doc(currentUser.uid)
        .collection('notifications')
        .where('type', isEqualTo: 'gift_received')
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        debugPrint(
            '[GiftNotificationService] Snapshot received: ${snapshot.docs.length} documents');
        for (var change in snapshot.docChanges) {
          debugPrint(
              '[GiftNotificationService] Document change type: ${change.type}');
          if (change.type == DocumentChangeType.added) {
            _handleNewNotification(change.doc);
          }
        }
      },
      onError: (error) {
        debugPrint('[GiftNotificationService] Listener error: $error');
        debugPrint(
            '[GiftNotificationService] Error type: ${error.runtimeType}');
        // Check if it's a Firestore index error
        if (error.toString().contains('index')) {
          debugPrint('[GiftNotificationService] ⚠️ FIRESTORE INDEX REQUIRED!');
          debugPrint(
              '[GiftNotificationService] Create index for: users/{userId}/notifications collection');
          debugPrint(
              '[GiftNotificationService] Fields: type, isRead, timestamp (descending)');
        }
      },
    );
  }

  /// Handle a new notification
  void _handleNewNotification(DocumentSnapshot doc) {
    final notificationId = doc.id;
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) return;

    // Check if already shown
    if (_shownNotificationsBox?.containsKey(notificationId) ?? false) {
      debugPrint(
          '[GiftNotificationService] Notification $notificationId already shown');
      return;
    }

    debugPrint(
        '[GiftNotificationService] New gift notification: $notificationId');

    // Add to queue
    _notificationQueue.add({
      'id': notificationId,
      'data': data,
    });

    // Process queue
    _processQueue();
  }

  /// Process notification queue (show one at a time)
  void _processQueue() {
    if (_isShowingOverlay || _notificationQueue.isEmpty) return;

    // Check if navigator is available
    if (_navigatorKey?.currentContext == null) {
      debugPrint(
          '[GiftNotificationService] Navigator context not available, retrying in 1s...');
      Future.delayed(const Duration(seconds: 1), _processQueue);
      return;
    }

    _isShowingOverlay = true;
    final notification = _notificationQueue.removeAt(0);

    _showOverlay(
      notificationId: notification['id'],
      data: notification['data'],
    );
  }

  /// Show the gift notification overlay
  void _showOverlay({
    required String notificationId,
    required Map<String, dynamic> data,
  }) {
    final context = _navigatorKey?.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('[GiftNotificationService] Context not available for overlay');
      _isShowingOverlay = false;
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => GiftNotificationOverlay(
        senderName: data['fromUsername'] ?? 'Someone',
        senderPhotoUrl: data['fromUserPhotoUrl'],
        giftMessage: data['message'] ?? 'Sent you a gift!',
        onViewGift: () async {
          Navigator.of(dialogContext).pop();
          _markAsShown(notificationId);
          _markAsRead(notificationId);
          _onOverlayClosed();

          // Navigate to gift detail screen
          final giftId = data['giftId'] as String?;
          if (giftId != null && _navigatorKey?.currentContext != null) {
            try {
              // Fetch gift data
              final giftRepo = locator<GiftRepository>();
              final gift = await giftRepo.getGiftById(giftId);

              if (gift != null && _navigatorKey!.currentContext != null) {
                Navigator.of(_navigatorKey!.currentContext!).push(
                  MaterialPageRoute(
                    builder: (context) => GiftDetailScreen(gift: gift),
                  ),
                );
              }
            } catch (e) {
              debugPrint(
                  '[GiftNotificationService] Error navigating to gift detail: $e');
            }
          }
        },
        onClose: () {
          Navigator.of(dialogContext).pop();
          _markAsShown(notificationId);
          _markAsRead(notificationId);
          _onOverlayClosed();
        },
      ),
    );
  }

  /// Called when overlay is closed
  void _onOverlayClosed() {
    _isShowingOverlay = false;

    // Process next notification in queue
    if (_notificationQueue.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _processQueue();
      });
    }
  }

  /// Mark notification as shown (locally)
  void _markAsShown(String notificationId) {
    try {
      _shownNotificationsBox?.put(
          notificationId, DateTime.now().toIso8601String());
      debugPrint('[GiftNotificationService] Marked $notificationId as shown');
    } catch (e) {
      debugPrint('[GiftNotificationService] Error marking as shown: $e');
    }
  }

  /// Mark notification as read (Firestore)
  Future<void> _markAsRead(String notificationId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _db
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[GiftNotificationService] Marked $notificationId as read');
    } catch (e) {
      debugPrint('[GiftNotificationService] Error marking as read: $e');
    }
  }

  /// Check for pending notifications (called on app start)
  Future<void> checkPendingNotifications() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('[GiftNotificationService] No user for pending check');
      return;
    }

    try {
      debugPrint(
          '[GiftNotificationService] Checking pending notifications for: ${currentUser.uid}');

      final snapshot = await _db
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .where('type', isEqualTo: 'gift_received')
          .where('isRead', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(5) // Check last 5 unread notifications
          .get();

      debugPrint(
          '[GiftNotificationService] Found ${snapshot.docs.length} pending notifications');

      for (var doc in snapshot.docs) {
        debugPrint(
            '[GiftNotificationService] Processing pending notification: ${doc.id}');
        _handleNewNotification(doc);
      }
    } catch (e) {
      debugPrint(
          '[GiftNotificationService] Error checking pending notifications: $e');
      debugPrint('[GiftNotificationService] Error type: ${e.runtimeType}');
      if (e.toString().contains('index')) {
        debugPrint('[GiftNotificationService] ⚠️ FIRESTORE INDEX REQUIRED!');
        debugPrint(
            '[GiftNotificationService] Create index for: notifications collection');
        debugPrint(
            '[GiftNotificationService] Fields: userId, type, isRead, timestamp (descending)');
      }
    }
  }

  /// Stop listening
  void stopListening() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    debugPrint('[GiftNotificationService] Stopped listening');
  }

  /// Dispose resources
  void dispose() {
    stopListening();
    _shownNotificationsBox?.close();
    _isInitialized = false;
  }
}
