// lib/services/notification_action_handler.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Handles notification actions (Reply, Mark as Read, Accept, etc.)
/// Professional implementation like WhatsApp/Messenger
class NotificationActionHandler {
  static final NotificationActionHandler _instance =
      NotificationActionHandler._internal();
  factory NotificationActionHandler() => _instance;
  NotificationActionHandler._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize action handler
  Future<void> initialize() async {
    // Android initialization with action handler
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    final DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    if (kDebugMode) {
      debugPrint('[Notification Actions] Handler initialized');
    }
  }

  /// Handle notification tap (foreground)
  void _onNotificationResponse(NotificationResponse response) async {
    if (kDebugMode) {
      debugPrint('[Notification Actions] Response: ${response.actionId}');
      debugPrint('[Notification Actions] Payload: ${response.payload}');
    }

    final actionId = response.actionId;
    final payload = response.payload ?? '';

    if (actionId != null) {
      await _handleAction(actionId, payload);
    }
  }

  /// Handle notification action tap (background)
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint(
          '[Notification Actions] Background action: ${response.actionId}');
    }
    // Note: Background actions are limited. Heavy operations should be done in foreground.
  }

  /// Handle iOS local notification (legacy)
  void _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    if (kDebugMode) {
      debugPrint('[Notification Actions] iOS notification: $title');
    }
  }

  /// Handle specific action
  Future<void> _handleAction(String actionId, String payload) async {
    try {
      switch (actionId) {
        case 'reply':
          await _handleReplyAction(payload);
          break;
        case 'mark_read':
          await _handleMarkAsReadAction(payload);
          break;
        case 'accept':
          await _handleAcceptFriendRequest(payload);
          break;
        case 'view_profile':
          await _handleViewProfile(payload);
          break;
        default:
          if (kDebugMode) {
            debugPrint('[Notification Actions] Unknown action: $actionId');
          }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Notification Actions] Error handling action: $e');
      }
    }
  }

  /// Handle Reply action (opens chat)
  Future<void> _handleReplyAction(String payload) async {
    if (kDebugMode) {
      debugPrint('[Notification Actions] Reply action: $payload');
    }

    // Parse payload: "chat:chatId:senderId"
    final parts = payload.split(':');
    if (parts.length >= 3 && parts[0] == 'chat') {
      final chatId = parts[1];

      // TODO: Navigate to chat screen
      // This requires access to navigator, which should be handled by FcmNavigationService
      // For now, we just log. The actual navigation will be handled when user opens app.

      if (kDebugMode) {
        debugPrint('[Notification Actions] Would open chat: $chatId');
      }
    }
  }

  /// Handle Mark as Read action
  Future<void> _handleMarkAsReadAction(String payload) async {
    if (kDebugMode) {
      debugPrint('[Notification Actions] Mark as read: $payload');
    }

    try {
      // Parse payload: "chat:chatId:senderId"
      final parts = payload.split(':');
      if (parts.length >= 3 && parts[0] == 'chat') {
        final chatId = parts[1];
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        if (currentUserId == null) {
          if (kDebugMode) {
            debugPrint('[Notification Actions] User not authenticated');
          }
          return;
        }

        // Mark ALL unread messages in this chat as seen in Firestore
        final firestore = FirebaseFirestore.instance;
        final firestoreChatRef = firestore.collection('chats').doc(chatId);

        // Get all unseen messages from the other user
        final unreadMessages = await firestoreChatRef
            .collection('messages')
            .where('senderId', isNotEqualTo: currentUserId)
            .where('isSeen', isEqualTo: false)
            .get();

        if (unreadMessages.docs.isNotEmpty) {
          // Batch update all messages to seen
          final batch = firestore.batch();
          for (final doc in unreadMessages.docs) {
            batch.update(doc.reference, {
              'isSeen': true,
              'seenAt': FieldValue.serverTimestamp(),
            });
          }
          await batch.commit();

          if (kDebugMode) {
            debugPrint(
                '[Notification Actions] Marked ${unreadMessages.docs.length} messages as seen');
          }
        }

        // Update chat document to remove user from unreadFor array
        await firestoreChatRef.update({
          'unreadFor': FieldValue.arrayRemove([currentUserId]),
          'lastSeenBy.$currentUserId': FieldValue.serverTimestamp(),
        });

        // Cancel notification
        await _notificationsPlugin.cancel(_getNotificationId('chat_$chatId'));

        if (kDebugMode) {
          debugPrint('[Notification Actions] Marked chat $chatId as read');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Notification Actions] Error marking as read: $e');
      }
    }
  }

  /// Handle Accept friend request action
  Future<void> _handleAcceptFriendRequest(String payload) async {
    if (kDebugMode) {
      debugPrint('[Notification Actions] Accept friend request: $payload');
    }

    try {
      // Parse payload: "profile:userId"
      final parts = payload.split(':');
      if (parts.length >= 2 && parts[0] == 'profile') {
        final fromUserId = parts[1];
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        if (currentUserId == null) {
          if (kDebugMode) {
            debugPrint('[Notification Actions] User not authenticated');
          }
          return;
        }

        // Accept friend request in Firebase
        final db = FirebaseDatabase.instance;

        // Add to friends list
        await db.ref('users/$currentUserId/friends/$fromUserId').set(true);
        await db.ref('users/$fromUserId/friends/$currentUserId').set(true);

        // Remove from pending requests
        await db
            .ref('users/$currentUserId/friendRequests/$fromUserId')
            .remove();
        await db.ref('users/$fromUserId/sentRequests/$currentUserId').remove();

        // Cancel notification
        await _notificationsPlugin
            .cancel(_getNotificationId('friend_$fromUserId'));

        if (kDebugMode) {
          debugPrint(
              '[Notification Actions] Accepted friend request from $fromUserId');
        }

        // Show success notification
        await _showSuccessNotification('Friend request accepted! 🎉');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Notification Actions] Error accepting friend request: $e');
      }
    }
  }

  /// Handle View Profile action
  Future<void> _handleViewProfile(String payload) async {
    if (kDebugMode) {
      debugPrint('[Notification Actions] View profile: $payload');
    }

    // Parse payload: "profile:userId"
    final parts = payload.split(':');
    if (parts.length >= 2 && parts[0] == 'profile') {
      final userId = parts[1];

      // TODO: Navigate to profile screen
      // This requires access to navigator

      if (kDebugMode) {
        debugPrint('[Notification Actions] Would open profile: $userId');
      }
    }
  }

  /// Show success notification
  Future<void> _showSuccessNotification(String message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'general_channel',
      'General',
      channelDescription: 'General app notifications',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      999999, // Unique ID for success notifications
      'Success',
      message,
      notificationDetails,
    );
  }

  /// Generate consistent notification ID
  int _getNotificationId(String key) {
    return key.hashCode.abs() % 100000;
  }
}
