// lib/services/fcm_navigation_service.dart
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/navigation/app_routes.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/screens/post_detail_screen.dart';

/// Service to handle FCM notification navigation
/// This ensures tapping notifications opens the correct screen
class FcmNavigationService {
  static final FcmNavigationService _instance =
      FcmNavigationService._internal();
  factory FcmNavigationService() => _instance;
  FcmNavigationService._internal();

  // Use centralized navigator from NavigationService
  GlobalKey<NavigatorState> get navigatorKey =>
      locator<NavigationService>().navigatorKey;

  /// Initialize FCM navigation handling
  void initialize() {
    // Handle notification taps when app is in background or terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('[FCM Navigation] Notification opened app from background');
        debugPrint('[FCM Navigation] Data: ${message.data}');
      }
      _handleNotificationTap(message.data);
    });

    // Check if app was opened from a terminated state by tapping notification
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        if (kDebugMode) {
          debugPrint('[FCM Navigation] App opened from terminated state');
          debugPrint('[FCM Navigation] Data: ${message.data}');
        }
        // Delay navigation to ensure app is fully initialized
        Future.delayed(const Duration(milliseconds: 1500), () {
          _handleNotificationTap(message.data);
        });
      }
    });

    if (kDebugMode) {
      debugPrint('[FCM Navigation] Service initialized');
    }
  }

  /// Handle notification tap and navigate to appropriate screen
  void _handleNotificationTap(Map<String, dynamic> data) {
    if (kDebugMode) {
      debugPrint('[FCM Navigation] Handling notification tap: $data');
    }

    final type = data['type'];
    final context = navigatorKey.currentContext;

    if (context == null) {
      if (kDebugMode) {
        debugPrint('[FCM Navigation] Context is null, cannot navigate');
      }
      return;
    }

    switch (type) {
      case 'friendRequest':
        _navigateToFriendRequests(context, data);
        break;

      case 'newMessage':
        _navigateToChat(context, data);
        break;

      case 'requestAccepted':
        _navigateToProfile(context, data);
        break;

      case 'comment':
      case 'reaction':
      case 'mention':
        _navigateToPost(context, data);
        break;

      default:
        if (kDebugMode) {
          debugPrint('[FCM Navigation] Unknown notification type: $type');
        }
    }
  }

  /// Navigate to friend requests tab
  void _navigateToFriendRequests(
      BuildContext context, Map<String, dynamic> data) {
    try {
      final fromUserId = data['fromUserId'];
      final fromUsername = data['fromUsername'];

      if (kDebugMode) {
        debugPrint('[FCM Navigation] Navigating to friend requests');
        debugPrint('[FCM Navigation] From: $fromUsername ($fromUserId)');
      }

      locator<NavigationService>().navigateNamed(
        AppRoutes.profile,
        arguments: {'userId': fromUserId},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM Navigation] Error navigating to friend requests: $e');
      }
    }
  }

  /// Navigate to specific chat screen
  void _navigateToChat(BuildContext context, Map<String, dynamic> data) {
    try {
      final chatId = data['chatId'];
      final senderId = data['senderId'];
      final senderUsername = data['senderUsername'];

      if (kDebugMode) {
        debugPrint('[FCM Navigation] Navigating to chat');
        debugPrint('[FCM Navigation] Chat ID: $chatId');
        debugPrint('[FCM Navigation] Sender: $senderUsername ($senderId)');
      }

      if (chatId == null || chatId.isEmpty) {
        if (kDebugMode) {
          debugPrint('[FCM Navigation] Chat ID is null or empty');
        }
        return;
      }

      locator<NavigationService>().navigateNamed(
        AppRoutes.chat,
        arguments: {
          'chatId': chatId,
          'otherUserId': senderId,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM Navigation] Error navigating to chat: $e');
      }
    }
  }

  /// Navigate to user profile screen
  void _navigateToProfile(BuildContext context, Map<String, dynamic> data) {
    try {
      final fromUserId = data['fromUserId'];
      final fromUsername = data['fromUsername'];

      if (kDebugMode) {
        debugPrint('[FCM Navigation] Navigating to profile');
        debugPrint('[FCM Navigation] User: $fromUsername ($fromUserId)');
      }

      if (fromUserId == null || fromUserId.isEmpty) {
        if (kDebugMode) {
          debugPrint('[FCM Navigation] User ID is null or empty');
        }
        return;
      }

      locator<NavigationService>().navigateNamed(
        AppRoutes.profile,
        arguments: {'userId': fromUserId},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM Navigation] Error navigating to profile: $e');
      }
    }
  }

  /// Navigate to post detail screen
  void _navigateToPost(BuildContext context, Map<String, dynamic> data) {
    try {
      final postId = data['postId'];
      final commentId = data['commentId'];

      if (kDebugMode) {
        debugPrint('[FCM Navigation] Navigating to post');
        debugPrint('[FCM Navigation] Post ID: $postId');
        if (commentId != null) {
          debugPrint('[FCM Navigation] Comment ID: $commentId');
        }
      }

      if (postId == null || postId.isEmpty) {
        if (kDebugMode) {
          debugPrint('[FCM Navigation] Post ID is null or empty');
        }
        return;
      }

      locator<NavigationService>().navigateTo(
        PostDetailScreen(
          postId: postId,
          commentId: commentId,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM Navigation] Error navigating to post: $e');
      }
    }
  }

  /// Manually trigger navigation (for testing or foreground notifications)
  void handleForegroundNotificationTap(Map<String, dynamic> data) {
    _handleNotificationTap(data);
  }
}
