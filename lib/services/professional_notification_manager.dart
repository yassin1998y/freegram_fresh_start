// lib/services/professional_notification_manager.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Professional notification manager like WhatsApp/Messenger
/// Features:
/// - Message grouping (multiple messages from same person)
/// - Proper notification IDs (prevents duplicates)
/// - Rich styling (profile pictures, big text)
/// - Action buttons (Reply, Mark as Read)
/// - Notification stacking (multiple conversations)
class ProfessionalNotificationManager {
  static final ProfessionalNotificationManager _instance =
      ProfessionalNotificationManager._internal();
  factory ProfessionalNotificationManager() => _instance;
  ProfessionalNotificationManager._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Store messages per chat for grouping (like WhatsApp)
  final Map<String, List<NotificationMessage>> _messagesByChat = {};

  // Store notification IDs to prevent duplicates
  final Map<String, int> _notificationIds = {};

  /// Initialize professional notification channels
  Future<void> initialize() async {
    // Android initialization
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('ic_stat_freegram');

    // iOS initialization
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);

    // Create Android notification channels (like WhatsApp)
    await _createProfessionalChannels();

    if (kDebugMode) {
      debugPrint('[Pro Notification] Manager initialized');
    }
  }

  /// Create professional notification channels
  Future<void> _createProfessionalChannels() async {
    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // HIGH PRIORITY: Messages (like WhatsApp)
    const AndroidNotificationChannel messagesChannel =
        AndroidNotificationChannel(
      'messages_channel',
      'Messages',
      description: 'Notifications for new messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // DEFAULT PRIORITY: Friend requests
    const AndroidNotificationChannel friendsChannel =
        AndroidNotificationChannel(
      'friends_channel',
      'Friend Requests',
      description: 'Notifications for friend requests',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // LOW PRIORITY: General notifications
    const AndroidNotificationChannel generalChannel =
        AndroidNotificationChannel(
      'general_channel',
      'General',
      description: 'General app notifications',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await androidPlugin.createNotificationChannel(messagesChannel);
    await androidPlugin.createNotificationChannel(friendsChannel);
    await androidPlugin.createNotificationChannel(generalChannel);

    if (kDebugMode) {
      debugPrint('[Pro Notification] Channels created');
    }
  }

  /// Show message notification (supports grouping like WhatsApp)
  Future<void> showMessageNotification({
    required String chatId,
    required String senderId,
    required String senderName,
    required String message,
    String? senderAvatarUrl,
    int? timestamp,
  }) async {
    // Generate consistent notification ID for this chat
    final notificationId = _getNotificationId('chat_$chatId');

    // Add message to group
    _messagesByChat.putIfAbsent(chatId, () => []);
    _messagesByChat[chatId]!.add(NotificationMessage(
      senderName: senderName,
      message: message,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
    ));

    // Keep only last 10 messages per chat
    if (_messagesByChat[chatId]!.length > 10) {
      _messagesByChat[chatId]!.removeAt(0);
    }

    // Download profile picture for rich notification
    String? largeIconPath;
    if (senderAvatarUrl != null && senderAvatarUrl.isNotEmpty) {
      largeIconPath = await _downloadAndSaveImage(
        senderAvatarUrl,
        'avatar_$senderId.jpg',
      );
    }

    // Build notification based on message count
    final messages = _messagesByChat[chatId]!;
    final messageCount = messages.length;

    if (!kIsWeb && Platform.isAndroid) {
      await _showAndroidMessageNotification(
        notificationId: notificationId,
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        messages: messages,
        messageCount: messageCount,
        largeIconPath: largeIconPath,
      );
    } else if (!kIsWeb && Platform.isIOS) {
      await _showIOSMessageNotification(
        notificationId: notificationId,
        senderName: senderName,
        message: message,
        messageCount: messageCount,
      );
    }

    if (kDebugMode) {
      debugPrint(
          '[Pro Notification] Message notification shown: $senderName ($messageCount messages)');
    }
  }

  /// Android message notification with MessagingStyle (like WhatsApp)
  Future<void> _showAndroidMessageNotification({
    required int notificationId,
    required String chatId,
    required String senderId,
    required String senderName,
    required List<NotificationMessage> messages,
    required int messageCount,
    String? largeIconPath,
  }) async {
    // Build messaging style messages (proper conversation format)
    final List<Message> messagingStyleMessages = messages.map((m) {
      return Message(
        m.message,
        DateTime.fromMillisecondsSinceEpoch(m.timestamp),
        Person(
          name: m.senderName,
          // You can add profile icon here if available
        ),
      );
    }).toList();

    // Create MessagingStyleInformation (like WhatsApp)
    final MessagingStyleInformation styleInformation =
        MessagingStyleInformation(
      const Person(
        name: 'Me', // Current user
        key: 'me',
      ),
      conversationTitle: senderName,
      groupConversation: false, // Set to true for group chats
      messages: messagingStyleMessages,
      htmlFormatContent: true,
      htmlFormatTitle: true,
    );

    // Action buttons (Reply, Mark as Read)
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'Notifications for new messages',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: styleInformation,
      largeIcon:
          largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
      color: const Color(0xFF2196F3), // Your app's primary color
      showWhen: true,
      when: messages.last.timestamp,
      groupKey: 'com.freegram.MESSAGES', // Group all message notifications
      setAsGroupSummary: false,
      autoCancel: true,
      ongoing: false,
      // Tag to update same notification
      tag: chatId,
      // Action buttons
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'reply',
          'Reply',
          showsUserInterface: true,
          cancelNotification: false,
          // icon: DrawableResourceAndroidBitmap('ic_reply'), // Optional: Add custom icon
        ),
        const AndroidNotificationAction(
          'mark_read',
          'Mark as Read',
          showsUserInterface: false,
          cancelNotification: true,
          // icon: DrawableResourceAndroidBitmap('ic_check'), // Optional: Add custom icon
        ),
      ],
      // Category for smart features (enables Android Auto, Wear OS, etc.)
      category: AndroidNotificationCategory.message,
      // Visibility
      visibility: NotificationVisibility.private,
      // Enable lights and vibration
      enableLights: true,
      ledColor: const Color(0xFF2196F3),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    // Show notification
    await _notificationsPlugin.show(
      notificationId,
      senderName,
      messages.last.message,
      notificationDetails,
      payload: 'chat:$chatId:$senderId',
    );
  }

  /// iOS message notification
  Future<void> _showIOSMessageNotification({
    required int notificationId,
    required String senderName,
    required String message,
    required int messageCount,
  }) async {
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      threadIdentifier: senderName,
      subtitle: messageCount > 1 ? '$messageCount messages' : null,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: messageCount,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      notificationId,
      senderName,
      message,
      notificationDetails,
    );
  }

  /// Show friend request notification (prevents duplicates)
  Future<void> showFriendRequestNotification({
    required String fromUserId,
    required String fromUsername,
    String? avatarUrl,
  }) async {
    // Use consistent notification ID to prevent duplicates
    final notificationId = _getNotificationId('friend_$fromUserId');

    // Download profile picture
    String? largeIconPath;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      largeIconPath = await _downloadAndSaveImage(
        avatarUrl,
        'avatar_$fromUserId.jpg',
      );
    }

    if (!kIsWeb && Platform.isAndroid) {
      await _showAndroidFriendRequestNotification(
        notificationId: notificationId,
        fromUserId: fromUserId,
        fromUsername: fromUsername,
        largeIconPath: largeIconPath,
      );
    } else if (!kIsWeb && Platform.isIOS) {
      await _showIOSFriendRequestNotification(
        notificationId: notificationId,
        fromUsername: fromUsername,
      );
    }

    if (kDebugMode) {
      debugPrint(
          '[Pro Notification] Friend request shown: $fromUsername (ID: $notificationId)');
    }
  }

  /// Android friend request notification
  Future<void> _showAndroidFriendRequestNotification({
    required int notificationId,
    required String fromUserId,
    required String fromUsername,
    String? largeIconPath,
  }) async {
    final BigTextStyleInformation styleInformation = BigTextStyleInformation(
      '$fromUsername sent you a friend request',
      htmlFormatBigText: true,
      contentTitle: 'Friend Request',
      htmlFormatContentTitle: true,
      summaryText: 'Tap to view profile',
      htmlFormatSummaryText: true,
    );

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'friends_channel',
      'Friend Requests',
      channelDescription: 'Notifications for friend requests',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      styleInformation: styleInformation,
      largeIcon:
          largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
      color: const Color(0xFF2196F3),
      groupKey: 'friend_requests',
      setAsGroupSummary: false,
      autoCancel: true,
      // Action buttons
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'accept',
          'Accept',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'view_profile',
          'View Profile',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
      category: AndroidNotificationCategory.social,
      visibility: NotificationVisibility.private,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      notificationId,
      'Friend Request',
      '$fromUsername sent you a friend request',
      notificationDetails,
      payload: 'profile:$fromUserId',
    );
  }

  /// iOS friend request notification
  Future<void> _showIOSFriendRequestNotification({
    required int notificationId,
    required String fromUsername,
  }) async {
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      threadIdentifier: 'friend_requests',
      subtitle: fromUsername,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      notificationId,
      'Friend Request',
      '$fromUsername sent you a friend request',
      notificationDetails,
    );
  }

  /// Clear messages for a specific chat
  void clearChatMessages(String chatId) {
    _messagesByChat.remove(chatId);
    final notificationId = _getNotificationId('chat_$chatId');
    _notificationsPlugin.cancel(notificationId);

    if (kDebugMode) {
      debugPrint('[Pro Notification] Cleared messages for chat: $chatId');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    _messagesByChat.clear();
    _notificationIds.clear();

    if (kDebugMode) {
      debugPrint('[Pro Notification] Cleared all notifications');
    }
  }

  /// Generate consistent notification ID (prevents duplicates)
  int _getNotificationId(String key) {
    if (!_notificationIds.containsKey(key)) {
      // Generate unique ID based on hash (consistent across app restarts)
      _notificationIds[key] = key.hashCode.abs() % 100000;
    }
    return _notificationIds[key]!;
  }

  /// Download and save image for notification
  Future<String?> _downloadAndSaveImage(String url, String filename) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/$filename';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Pro Notification] Error downloading image: $e');
      }
    }
    return null;
  }

  // ============================================================================
  // BACKGROUND NOTIFICATION METHODS (for when app is in background/terminated)
  // ============================================================================

  /// Show grouped message notification in background (like WhatsApp)
  Future<void> showBackgroundMessageNotification({
    required String chatId,
    required String senderId,
    required String senderUsername,
    required String senderPhotoUrl,
    required String messageText,
    required int messageCount,
    required List<String> messages,
  }) async {
    final notificationId = _getNotificationId('chat_$chatId');

    // Cancel any existing notification for this chat to prevent duplicates
    await _notificationsPlugin.cancel(notificationId);

    if (kDebugMode) {
      debugPrint(
          '[Pro Notification Background] Canceled old notification for chat: $chatId');
    }

    // Download profile picture
    String? largeIconPath;
    if (senderPhotoUrl.isNotEmpty) {
      largeIconPath = await _downloadAndSaveImage(
        senderPhotoUrl,
        'avatar_$senderId.jpg',
      );
    }

    // Build MessagingStyle messages (proper conversation format)
    final List<Message> messagingStyleMessages = [];
    final now = DateTime.now();

    for (int i = 0; i < messages.length && i < 10; i++) {
      final msg = messages[i];
      if (msg.trim().isEmpty) continue;

      // Determine if this message is from "You" or the sender
      final isFromYou = msg.startsWith('You: ');
      final displayText = isFromYou ? msg.substring(5) : msg;
      final personName = isFromYou ? 'Me' : senderUsername;

      messagingStyleMessages.add(Message(
        displayText,
        now.subtract(Duration(
            minutes: messages.length - i)), // Simulate time progression
        Person(
          name: personName,
          key: isFromYou ? 'me' : senderId,
        ),
      ));
    }

    // Create MessagingStyleInformation (WhatsApp-style conversation)
    final MessagingStyleInformation styleInformation =
        MessagingStyleInformation(
      const Person(
        name: 'Me',
        key: 'me',
      ),
      conversationTitle: senderUsername,
      groupConversation: false,
      messages: messagingStyleMessages,
      htmlFormatContent: true,
      htmlFormatTitle: true,
    );

    // Action buttons with icons
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'Notifications for new messages',
      importance: Importance.high,
      priority: Priority.high,
      largeIcon:
          largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
      styleInformation: styleInformation,
      groupKey: 'com.freegram.MESSAGES',
      setAsGroupSummary: false,
      tag: chatId, // Use tag to update same notification
      color: const Color(0xFF2196F3),
      // Action buttons
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'reply',
          'Reply',
          showsUserInterface: true,
          cancelNotification: false,
          // icon: DrawableResourceAndroidBitmap('ic_reply'), // Optional: Add custom icon
        ),
        const AndroidNotificationAction(
          'mark_read',
          'Mark as Read',
          showsUserInterface: false,
          cancelNotification: true,
          // icon: DrawableResourceAndroidBitmap('ic_check'), // Optional: Add custom icon
        ),
      ],
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.private,
      enableLights: true,
      ledColor: const Color(0xFF2196F3),
      ledOnMs: 1000,
      ledOffMs: 500,
      autoCancel: true,
    );

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      notificationId,
      senderUsername,
      messageText,
      platformDetails,
      payload: 'chat:$chatId:$senderId',
    );

    if (kDebugMode) {
      debugPrint(
          '[Pro Notification Background] Showed message notification for $senderUsername with $messageCount messages');
    }
  }

  /// Show friend request notification in background
  Future<void> showBackgroundFriendRequestNotification({
    required String fromUserId,
    required String fromUsername,
    required String fromPhotoUrl,
  }) async {
    final notificationId = _getNotificationId('friend_request_$fromUserId');

    // Download profile picture
    String? largeIconPath;
    if (fromPhotoUrl.isNotEmpty) {
      largeIconPath = await _downloadAndSaveImage(
        fromPhotoUrl,
        'avatar_$fromUserId.jpg',
      );
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'friends_channel',
      'Friend Requests',
      channelDescription: 'Notifications for friend requests',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      largeIcon:
          largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
      styleInformation: BigTextStyleInformation(
        '$fromUsername sent you a friend request!',
        contentTitle: 'New Friend Request 👋',
      ),
      tag: fromUserId, // Use tag to prevent duplicates
      color: const Color(0xFF28a745),
    );

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      notificationId,
      'New Friend Request 👋',
      '$fromUsername sent you a friend request!',
      platformDetails,
      payload: 'profile:$fromUserId',
    );

    if (kDebugMode) {
      debugPrint(
          '[Pro Notification Background] Showed friend request from $fromUsername');
    }
  }

  /// Show friend request accepted notification in background
  Future<void> showBackgroundFriendAcceptedNotification({
    required String fromUserId,
    required String fromUsername,
    required String fromPhotoUrl,
  }) async {
    final notificationId = _getNotificationId('friend_accepted_$fromUserId');

    // Download profile picture
    String? largeIconPath;
    if (fromPhotoUrl.isNotEmpty) {
      largeIconPath = await _downloadAndSaveImage(
        fromPhotoUrl,
        'avatar_$fromUserId.jpg',
      );
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'friends_channel',
      'Friend Requests',
      channelDescription: 'Notifications for friend requests',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      largeIcon:
          largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
      styleInformation: BigTextStyleInformation(
        '$fromUsername accepted your friend request!',
        contentTitle: 'Friend Request Accepted ✅',
      ),
      tag: fromUserId, // Use tag to prevent duplicates
      color: const Color(0xFF17a2b8),
    );

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      notificationId,
      'Friend Request Accepted ✅',
      '$fromUsername accepted your friend request!',
      platformDetails,
      payload: 'profile:$fromUserId',
    );

    if (kDebugMode) {
      debugPrint(
          '[Pro Notification Background] Showed friend accepted from $fromUsername');
    }
  }

  /// Show reel notification in background (like, comment)
  Future<void> showBackgroundReelNotification({
    required String reelId,
    required String fromUserId,
    required String fromUsername,
    required String fromPhotoUrl,
    required String notificationType,
    required int count,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint(
            '[Pro Notification Background] Showing reel notification: $notificationType from $fromUsername');
      }

      final notificationId =
          _getNotificationId('reel_${notificationType}_$reelId');

      // Download profile picture
      String? largeIconPath;
      if (fromPhotoUrl.isNotEmpty) {
        largeIconPath = await _downloadAndSaveImage(
          fromPhotoUrl,
          'avatar_$fromUserId.jpg',
        );
      }

      // Format title and body based on type and count
      String title;
      String body;

      if (notificationType == 'reelLike') {
        if (count == 1) {
          title = 'Reel Like ❤️';
          body = '$fromUsername liked your reel';
        } else {
          title = 'Reel Likes ❤️';
          body =
              '$fromUsername and ${count - 1} other${count > 2 ? 's' : ''} liked your reel';
        }
      } else if (notificationType == 'reelComment') {
        if (count == 1) {
          title = 'Reel Comment 💬';
          body = '$fromUsername commented on your reel';
        } else {
          title = 'Reel Comments 💬';
          body =
              '$fromUsername and ${count - 1} other${count > 2 ? 's' : ''} commented on your reel';
        }
      } else {
        title = 'Reel Notification';
        body = '$fromUsername interacted with your reel';
      }

      // Android notification
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'general_channel',
        'General',
        channelDescription: 'General app notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        largeIcon:
            largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ),
        color: notificationType == 'reelLike'
            ? const Color(0xFFE91E63)
            : const Color(0xFF2196F3),
        autoCancel: true,
      );

      // iOS notification
      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        threadIdentifier: 'reel_notifications',
        subtitle: fromUsername,
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        platformDetails,
        payload: 'reel:$reelId:$fromUserId',
      );

      if (kDebugMode) {
        debugPrint(
            '[Pro Notification Background] Showed reel notification from $fromUsername');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[Pro Notification Background] Error showing reel notification: $e');
      }
    }
  }

  /// Show post notification in background (like, comment, mention)
  Future<void> showBackgroundPostNotification({
    required String postId,
    required String fromUserId,
    required String fromUsername,
    required String fromPhotoUrl,
    required String notificationType,
    required int count,
    String? commentText,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint(
            '[Pro Notification Background] Showing post notification: $notificationType from $fromUsername');
      }

      final notificationId =
          _getNotificationId('post_${notificationType}_$postId');

      // Download profile picture
      String? largeIconPath;
      if (fromPhotoUrl.isNotEmpty) {
        largeIconPath = await _downloadAndSaveImage(
          fromPhotoUrl,
          'avatar_$fromUserId.jpg',
        );
      }

      // Format title and body based on type and count
      String title;
      String body;

      if (notificationType == 'reaction' || notificationType == 'like') {
        if (count == 1) {
          title = 'New Like ❤️';
          body = '$fromUsername liked your post';
        } else {
          title = 'New Likes ❤️';
          body =
              '$fromUsername and ${count - 1} other${count > 2 ? 's' : ''} liked your post';
        }
      } else if (notificationType == 'comment') {
        if (count == 1) {
          title = 'New Comment 💬';
          body = '$fromUsername commented: ${commentText ?? "on your post"}';
        } else {
          title = 'New Comments 💬';
          body =
              '$fromUsername and ${count - 1} other${count > 2 ? 's' : ''} commented on your post';
        }
      } else if (notificationType == 'mention') {
        title = 'New Mention @';
        body = '$fromUsername mentioned you in a post';
      } else {
        title = 'New Notification';
        body = '$fromUsername interacted with your post';
      }

      // Android notification
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'general_channel',
        'General',
        channelDescription: 'General app notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        largeIcon:
            largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ),
        color: (notificationType == 'reaction' || notificationType == 'like')
            ? const Color(0xFFE91E63)
            : const Color(0xFF2196F3),
        autoCancel: true,
      );

      // iOS notification
      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        threadIdentifier: 'post_notifications',
        subtitle: fromUsername,
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        platformDetails,
        payload: 'post:$postId:$fromUserId',
      );

      if (kDebugMode) {
        debugPrint(
            '[Pro Notification Background] Showed post notification from $fromUsername');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[Pro Notification Background] Error showing post notification: $e');
      }
    }
  }
}

/// Model for notification messages
class NotificationMessage {
  final String senderName;
  final String message;
  final int timestamp;

  NotificationMessage({
    required this.senderName,
    required this.message,
    required this.timestamp,
  });
}
