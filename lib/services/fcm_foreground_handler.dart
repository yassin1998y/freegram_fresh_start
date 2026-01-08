// lib/services/fcm_foreground_handler.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freegram/services/chat_state_tracker.dart';
import 'package:freegram/services/fcm_navigation_service.dart';
import 'package:freegram/widgets/island_popup.dart';

/// Handles FCM notifications when app is in foreground
/// Professional behavior:
/// - Uses Island Popup instead of system notifications
/// - Suppresses notifications when user is in the active chat
/// - Allows tap-to-navigate from Island Popup
class FcmForegroundHandler {
  static final FcmForegroundHandler _instance =
      FcmForegroundHandler._internal();
  factory FcmForegroundHandler() => _instance;
  FcmForegroundHandler._internal();

  final ChatStateTracker _chatStateTracker = ChatStateTracker();
  final FcmNavigationService _navigationService = FcmNavigationService();

  /// Initialize foreground message handling
  void initialize() {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    if (kDebugMode) {
      debugPrint('[FCM Foreground Handler] Initialized');
    }
  }

  /// Handle incoming message when app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint('[FCM Foreground Handler] Processing message');
      debugPrint('[FCM Foreground Handler] Type: ${message.data['type']}');
      debugPrint('[FCM Foreground Handler] Data: ${message.data}');
    }

    final type = message.data['type'] ?? '';
    final data = message.data;

    // Data-only messages (no automatic notification)
    if (data.isEmpty) {
      if (kDebugMode) {
        debugPrint('[FCM Foreground Handler] No data payload, skipping');
      }
      return;
    }

    // Handle different notification types
    switch (type) {
      case 'newMessage':
        _handleNewMessage(data);
        break;
      case 'friendRequest':
        _handleFriendRequest(data);
        break;
      case 'requestAccepted':
        _handleRequestAccepted(data);
        break;
      case 'comment':
      case 'reaction':
      case 'mention':
        _handlePostNotification(data);
        break;
      case 'reelLike':
      case 'reelComment':
        _handleReelNotification(data);
        break;
      default:
        if (kDebugMode) {
          debugPrint('[FCM Foreground Handler] Unknown type: $type');
        }
    }
  }

  /// Handle new message notification
  void _handleNewMessage(Map<String, dynamic> data) {
    final chatId = data['chatId'] ?? '';
    final senderId = data['senderId'] ?? '';
    final senderUsername = data['senderUsername'] ?? 'Someone';
    final title = data['title'] ?? 'New Message';
    final body = data['body'] ?? 'You have a new message';

    // Professional behavior: Don't show notification if user is in this chat
    if (_chatStateTracker.isInChat(chatId)) {
      if (kDebugMode) {
        debugPrint(
            '[FCM Foreground Handler] User is in chat $chatId, suppressing notification');
      }
      return;
    }

    // Show Island Popup
    _showIslandPopup(
      icon: Icons.message,
      title: title,
      message: body,
      onTap: () {
        // Navigate to chat when tapped
        _navigationService.handleForegroundNotificationTap({
          'type': 'newMessage',
          'chatId': chatId,
          'senderId': senderId,
        });
      },
    );

    if (kDebugMode) {
      debugPrint(
          '[FCM Foreground Handler] Island popup shown for message from $senderUsername');
    }
  }

  /// Handle friend request notification
  void _handleFriendRequest(Map<String, dynamic> data) {
    final fromUserId = data['fromUserId'] ?? '';
    final fromUsername = data['fromUsername'] ?? 'Someone';
    final title = data['title'] ?? 'Friend Request';
    final body = data['body'] ?? '$fromUsername sent you a friend request';

    // Professional behavior: Don't show if already viewing this user's profile
    if (_chatStateTracker.isViewingProfile(fromUserId)) {
      if (kDebugMode) {
        debugPrint(
            '[FCM Foreground Handler] User is viewing profile $fromUserId, suppressing notification');
      }
      return;
    }

    // Show Island Popup
    _showIslandPopup(
      icon: Icons.person_add,
      title: title,
      message: body,
      onTap: () {
        // Navigate to profile when tapped
        _navigationService.handleForegroundNotificationTap({
          'type': 'friendRequest',
          'fromUserId': fromUserId,
        });
      },
    );

    if (kDebugMode) {
      debugPrint(
          '[FCM Foreground Handler] Island popup shown for friend request from $fromUsername');
    }
  }

  /// Handle post-related notifications (comment, reaction/like, mention)
  void _handlePostNotification(Map<String, dynamic> data) {
    final postId = data['postId'] ?? '';
    final commentId = data['commentId'];
    final fromUsername = data['fromUsername'] ?? 'Someone';
    final type = data['type'] ?? '';

    String title;
    String body;
    IconData icon;

    // Customize message based on type
    switch (type) {
      case 'comment':
        title = data['title'] ?? 'New Comment';
        body = data['body'] ?? '$fromUsername commented on your post';
        icon = Icons.comment;
        break;
      case 'reaction':
        title = data['title'] ?? 'New Like';
        body = data['body'] ?? '$fromUsername liked your post';
        icon = Icons.favorite;
        break;
      case 'mention':
        title = data['title'] ?? 'Mentioned You';
        body = data['body'] ?? '$fromUsername mentioned you in a post';
        icon = Icons.alternate_email;
        break;
      default:
        title = 'Post Notification';
        body = 'You have a new notification';
        icon = Icons.notifications;
    }

    if (postId.isEmpty) {
      if (kDebugMode) {
        debugPrint(
            '[FCM Foreground Handler] Post ID is empty, skipping post notification');
      }
      return;
    }

    // Show Island Popup
    _showIslandPopup(
      icon: icon,
      title: title,
      message: body,
      onTap: () {
        // Navigate to post detail screen when tapped
        _navigationService.handleForegroundNotificationTap({
          'type': type,
          'postId': postId,
          if (commentId != null) 'commentId': commentId,
        });
      },
    );

    if (kDebugMode) {
      debugPrint(
          '[FCM Foreground Handler] Island popup shown for $type notification from $fromUsername');
    }
  }

  /// Handle request accepted notification
  void _handleRequestAccepted(Map<String, dynamic> data) {
    final fromUserId = data['fromUserId'] ?? '';
    final fromUsername = data['fromUsername'] ?? 'Someone';
    final title = data['title'] ?? 'Request Accepted';
    final body = data['body'] ?? '$fromUsername accepted your friend request';

    // Professional behavior: Don't show if already viewing this user's profile
    if (_chatStateTracker.isViewingProfile(fromUserId)) {
      if (kDebugMode) {
        debugPrint(
            '[FCM Foreground Handler] User is viewing profile $fromUserId, suppressing notification');
      }
      return;
    }

    // Show Island Popup
    _showIslandPopup(
      icon: Icons.check_circle,
      title: title,
      message: body,
      onTap: () {
        // Navigate to profile when tapped
        _navigationService.handleForegroundNotificationTap({
          'type': 'requestAccepted',
          'fromUserId': fromUserId,
        });
      },
    );

    if (kDebugMode) {
      debugPrint(
          '[FCM Foreground Handler] Island popup shown for request accepted from $fromUsername');
    }
  }

  /// Handle reel-related notifications (like, comment)
  void _handleReelNotification(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final reelId = data['contentId'] ?? '';
    final fromUsername = data['fromUsername'] ?? 'Someone';
    final count = int.tryParse(data['count'] ?? '1') ?? 1;

    if (kDebugMode) {
      debugPrint(
          '[FCM Foreground Handler] Handling reel notification: $type from $fromUsername');
    }

    // Determine icon and message based on type
    IconData icon;
    String title;
    String message;

    if (type == 'reelLike') {
      icon = Icons.favorite;
      title = 'Reel Like';
      if (count == 1) {
        message = '$fromUsername liked your reel';
      } else {
        message =
            '$fromUsername and ${count - 1} other${count > 2 ? 's' : ''} liked your reel';
      }
    } else if (type == 'reelComment') {
      icon = Icons.comment;
      title = 'Reel Comment';
      if (count == 1) {
        message = '$fromUsername commented on your reel';
      } else {
        message =
            '$fromUsername and ${count - 1} other${count > 2 ? 's' : ''} commented on your reel';
      }
    } else {
      // Fallback for unknown reel notification types
      icon = Icons.notifications;
      title = 'Reel Notification';
      message = '$fromUsername interacted with your reel';
    }

    _showIslandPopup(
      icon: icon,
      title: title,
      message: message,
      onTap: () {
        if (reelId.isNotEmpty) {
          _navigationService.navigateToReel(reelId);
        }
      },
    );

    if (kDebugMode) {
      debugPrint(
          '[FCM Foreground Handler] Island popup shown for reel notification from $fromUsername');
    }
  }

  /// Show Island Popup with optional tap action
  void _showIslandPopup({
    required IconData icon,
    required String title,
    required String message,
    VoidCallback? onTap,
  }) {
    final context = _navigationService.navigatorKey.currentContext;
    if (context == null) {
      if (kDebugMode) {
        debugPrint(
            '[FCM Foreground Handler] No context available for Island Popup');
      }
      return;
    }

    showIslandPopup(
      context: context,
      message: '$title\n$message',
      icon: icon,
      onTap: onTap,
    );
  }
}
