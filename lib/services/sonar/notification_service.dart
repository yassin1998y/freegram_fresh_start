// lib/services/notification_service.dart
import 'package:flutter/foundation.dart'; // Needed for debugPrint
import 'package:flutter/material.dart'; // Needed for @pragma('vm:entry-point')
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:freegram/services/fcm_navigation_service.dart';

// Define top-level or static function for background notification tap handling
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle notification tap when app is in background or terminated
  debugPrint(
      'Notification tapped in background/terminated: ${notificationResponse.payload}');
  // TODO: Add logic here to navigate or handle the payload,
  // potentially using shared preferences or another mechanism
  // to communicate with the main app isolate upon startup.
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Define channel IDs
  static const String waveChannelId = 'waves_channel';
  static const String waveChannelName = 'Nearby Waves';
  static const String waveChannelDescription =
      'Notifications for received waves';

  static const String discoveryChannelId = 'discovery_channel';
  static const String discoveryChannelName = 'Nearby Discovery';
  static const String discoveryChannelDescription =
      'Notifications for new users nearby';

  /// Initializes the notification plugin and sets up channels.
  Future<void> initialize() async {
    // Android Initialization Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Use app icon

    // iOS Initialization Settings (requesting permissions)
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );

    // General Initialization Settings
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      // Handle notification tap when app is already running (foreground/background)
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      // Handle notification tap when app was terminated
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create Android Notification Channels
    await _createAndroidChannels();
    debugPrint("NotificationService: Initialized.");
  }

  /// Creates necessary Android notification channels.
  Future<void> _createAndroidChannels() async {
    const AndroidNotificationChannel waveChannel = AndroidNotificationChannel(
      waveChannelId,
      waveChannelName,
      description: waveChannelDescription,
      importance: Importance
          .max, // High importance for waves (implicitly sets priority)
      // priority: Priority.high, // REMOVED
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel discoveryChannel =
        AndroidNotificationChannel(
      discoveryChannelId,
      discoveryChannelName,
      description: discoveryChannelDescription,
      importance: Importance
          .defaultImportance, // Lower importance (implicitly sets priority)
      // priority: Priority.defaultPriority, // REMOVED
      playSound: false, // Optional: No sound for discovery
      enableVibration: false, // Optional: No vibration for discovery
    );

    // Get platform implementation and create channels
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(waveChannel);
    await androidImplementation?.createNotificationChannel(discoveryChannel);

    debugPrint("NotificationService: Android channels created.");
  }

  // --- Notification Showing Methods ---

  /// Shows a notification for a received wave.
  Future<void> showWaveNotification({
    required String title,
    required String body,
    String? payload, // Optional: e.g., sender's profileId or uidShort
  }) async {
    // Define Android details (without priority)
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      waveChannelId,
      waveChannelName,
      channelDescription: waveChannelDescription,
      importance: Importance.max, // Use Importance.max
      // priority: Priority.high, // REMOVED
      ticker: 'ticker', // Text shown briefly in status bar
    );
    // Define iOS details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true, // Show badge count update on iOS
      presentSound: true, // Play sound on iOS
    );
    // Combine platform details
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show the notification
    await _flutterLocalNotificationsPlugin.show(
      0, // Notification ID (0 for waves)
      title,
      body,
      platformDetails,
      payload: payload,
    );
    debugPrint(
        "NotificationService: Showing wave notification. Payload: $payload");
  }

  /// Shows a notification for a newly discovered user (optional).
  Future<void> showNewUserNearbyNotification({
    required String title,
    required String body,
    String? payload, // Optional: user's profileId or uidShort
  }) async {
    // Define Android details (without priority)
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      discoveryChannelId,
      discoveryChannelName,
      channelDescription: discoveryChannelDescription,
      importance:
          Importance.defaultImportance, // Use Importance.defaultImportance
      // priority: Priority.defaultPriority, // REMOVED
      ticker: 'ticker',
    );
    // Define iOS details (less intrusive for discovery)
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true, // Show alert
      presentBadge: false, // No badge update
      presentSound: false, // No sound
    );
    // Combine platform details
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show the notification
    await _flutterLocalNotificationsPlugin.show(
      1, // Use a different ID (1 for discovery)
      title,
      body,
      platformDetails,
      payload: payload,
    );
    debugPrint(
        "NotificationService: Showing discovery notification. Payload: $payload");
  }

  // --- Notification Tap Handlers ---

  // Callback for iOS when notification is received while app is in foreground
  void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    // Display a dialog or handle as needed
    debugPrint(
        "NotificationService (iOS FG): Received: $title - Payload: $payload");
    // Example: Show an in-app banner or dialog if app is active
  }

  // Callback for all platforms when a notification is tapped and app is running
  void onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    debugPrint("[Local Notification] Tapped. Payload: $payload");

    if (payload != null && payload.isNotEmpty) {
      // Parse payload format: "type:id:extraId"
      // Examples:
      // - "chat:chatId123:senderId456"
      // - "profile:userId123"

      final parts = payload.split(':');
      if (parts.isEmpty) return;

      final type = parts[0];

      try {
        final fcmNav = FcmNavigationService();
        final context = fcmNav.navigatorKey.currentContext;

        if (context == null) {
          debugPrint(
              "[Local Notification] No context available for navigation");
          return;
        }

        switch (type) {
          case 'chat':
            if (parts.length >= 3) {
              final chatId = parts[1];
              final senderId = parts[2];
              debugPrint("[Local Notification] Navigating to chat: $chatId");
              Navigator.pushNamed(
                context,
                '/chat',
                arguments: {
                  'chatId': chatId,
                  'otherUserId': senderId,
                },
              );
            }
            break;

          case 'profile':
            if (parts.length >= 2) {
              final userId = parts[1];
              debugPrint("[Local Notification] Navigating to profile: $userId");
              Navigator.pushNamed(
                context,
                '/profile',
                arguments: {'userId': userId},
              );
            }
            break;

          default:
            debugPrint("[Local Notification] Unknown payload type: $type");
        }
      } catch (e) {
        debugPrint("[Local Notification] Error navigating: $e");
      }
    }
  }

  // --- Permission Request (iOS) ---
  Future<bool?> requestIOSPermissions() async {
    debugPrint("NotificationService: Requesting iOS permissions...");
    return await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }
}
