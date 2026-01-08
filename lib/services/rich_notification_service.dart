import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Enhanced notification service with rich notifications
class RichNotificationService {
  static final RichNotificationService _instance =
      RichNotificationService._internal();
  factory RichNotificationService() => _instance;
  RichNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Notification channels
  static const String _giftChannelId = 'gift_notifications';
  static const String _giftChannelName = 'Gift Notifications';
  static const String _giftChannelDescription =
      'Notifications for received gifts';

  static const String _reactionChannelId = 'reaction_notifications';
  static const String _reactionChannelName = 'Reaction Notifications';
  static const String _reactionChannelDescription =
      'Notifications for gift reactions';

  static const String _dailyChannelId = 'daily_gift_notifications';
  static const String _dailyChannelName = 'Daily Gift Notifications';
  static const String _dailyChannelDescription =
      'Notifications for daily free gifts';

  /// Initialize the notification service
  Future<void> initialize() async {
    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Initialize Firebase messaging
    await _initializeFirebaseMessaging();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    // Request FCM permissions
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels (Android)
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Gift channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _giftChannelId,
          _giftChannelName,
          description: _giftChannelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // Reaction channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _reactionChannelId,
          _reactionChannelName,
          description: _reactionChannelDescription,
          importance: Importance.defaultImportance,
          playSound: true,
        ),
      );

      // Daily gift channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _dailyChannelId,
          _dailyChannelName,
          description: _dailyChannelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    }
  }

  Future<void> _initializeFirebaseMessaging() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Get initial message if app was opened from notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  /// Show gift received notification with image
  Future<void> showGiftReceivedNotification({
    required String giftId,
    required String senderName,
    required String giftName,
    String? message,
    String? imageUrl,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Download image if available
    String? bigPicturePath;
    if (imageUrl != null) {
      bigPicturePath = await _downloadImage(imageUrl);
    }

    final androidDetails = AndroidNotificationDetails(
      _giftChannelId,
      _giftChannelName,
      channelDescription: _giftChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: bigPicturePath != null
          ? BigPictureStyleInformation(
              FilePathAndroidBitmap(bigPicturePath),
              contentTitle: '$senderName sent you a gift! 🎁',
              summaryText: message ?? giftName,
            )
          : BigTextStyleInformation(
              message ?? 'You received $giftName!',
              contentTitle: '$senderName sent you a gift! 🎁',
            ),
      actions: const [
        AndroidNotificationAction(
          'view',
          'View Gift',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'thank',
          'Say Thanks',
          showsUserInterface: true,
        ),
      ],
      groupKey: 'gifts',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'gift_received',
    );

    await _notifications.show(
      id,
      '$senderName sent you a gift! 🎁',
      message ?? 'You received $giftName',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: 'gift:$giftId',
    );

    // Show summary notification for grouped notifications
    if (Platform.isAndroid) {
      await _showGroupSummary('gifts', 'New Gifts', 'You have new gifts');
    }
  }

  /// Show reaction notification
  Future<void> showReactionNotification({
    required String giftId,
    required String userName,
    required String reaction,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    const androidDetails = AndroidNotificationDetails(
      _reactionChannelId,
      _reactionChannelName,
      channelDescription: _reactionChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      groupKey: 'reactions',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _notifications.show(
      id,
      '$userName reacted to your gift',
      'Reaction: $reaction',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: 'reaction:$giftId',
    );
  }

  /// Show thank you notification
  Future<void> showThankYouNotification({
    required String giftId,
    required String userName,
    String? message,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final androidDetails = AndroidNotificationDetails(
      _reactionChannelId,
      _reactionChannelName,
      channelDescription: _reactionChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        '',
        contentTitle: '$userName thanked you! ❤️',
      ),
      groupKey: 'reactions',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _notifications.show(
      id,
      '$userName thanked you! ❤️',
      message ?? 'They appreciated your gift',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: 'thank:$giftId',
    );
  }

  /// Show daily gift available notification
  Future<void> showDailyGiftAvailableNotification({
    required int streak,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    const androidDetails = AndroidNotificationDetails(
      _dailyChannelId,
      _dailyChannelName,
      channelDescription: _dailyChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(
          'claim',
          'Claim Now',
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'daily_gift',
    );

    await _notifications.show(
      id,
      'Daily Gift Available! 🎁',
      streak > 0
          ? 'Keep your $streak-day streak going!'
          : 'Claim your free gift now!',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: 'daily_gift',
    );
  }

  /// Show group summary notification
  Future<void> _showGroupSummary(
    String groupKey,
    String title,
    String body,
  ) async {
    final androidDetails = AndroidNotificationDetails(
      _giftChannelId,
      _giftChannelName,
      channelDescription: _giftChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      groupKey: groupKey,
      setAsGroupSummary: true,
    );

    await _notifications.show(
      0,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  /// Download image for notification
  Future<String?> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final filePath =
            '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
    } catch (e) {
      debugPrint('Error downloading notification image: $e');
    }
    return null;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    _handleDeepLink(payload, response.actionId);
  }

  /// Handle foreground message
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final data = message.data;
    final type = data['type'] as String?;

    switch (type) {
      case 'gift_received':
        showGiftReceivedNotification(
          giftId: data['giftId'] ?? '',
          senderName: data['senderName'] ?? 'Someone',
          giftName: data['giftName'] ?? 'a gift',
          message: notification.body,
          imageUrl: data['imageUrl'],
        );
        break;
      case 'gift_thanked':
        showThankYouNotification(
          giftId: data['giftId'] ?? '',
          userName: data['userName'] ?? 'Someone',
          message: notification.body,
        );
        break;
      case 'gift_reacted':
        showReactionNotification(
          giftId: data['giftId'] ?? '',
          userName: data['userName'] ?? 'Someone',
          reaction: data['reaction'] ?? '❤️',
        );
        break;
      case 'daily_gift':
        showDailyGiftAvailableNotification(
          streak: int.tryParse(data['streak'] ?? '0') ?? 0,
        );
        break;
    }
  }

  /// Handle message opened app
  void _handleMessageOpenedApp(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    final payload = '$type:${data['giftId'] ?? data['id'] ?? ''}';
    _handleDeepLink(payload, null);
  }

  /// Handle deep linking
  void _handleDeepLink(String payload, String? actionId) {
    final parts = payload.split(':');
    if (parts.length < 2) return;

    final type = parts[0];
    final id = parts[1];

    // TODO: Implement navigation based on type and action
    debugPrint('Deep link: $type -> $id (action: $actionId)');

    // Example navigation logic:
    // switch (type) {
    //   case 'gift':
    //     if (actionId == 'view') {
    //       navigatorKey.currentState?.pushNamed('/inventory');
    //     } else if (actionId == 'thank') {
    //       // Show thank you dialog
    //     }
    //     break;
    //   case 'daily_gift':
    //     if (actionId == 'claim') {
    //       navigatorKey.currentState?.pushNamed('/daily-gift');
    //     }
    //     break;
    // }
  }

  /// Get FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Cancel notification by id
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}

/// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
  // Handle background message
}
