// lib/services/upload_notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// Service for showing upload progress notifications in the background
class UploadNotificationService {
  static final UploadNotificationService _instance = UploadNotificationService._internal();
  factory UploadNotificationService() => _instance;
  UploadNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    debugPrint('UploadNotificationService: Initialized');
  }

  /// Show upload progress notification
  Future<void> showUploadProgress({
    required String uploadId,
    required double progress,
    required String currentStep,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      'story_upload',
      'Story Upload',
      channelDescription: 'Notifications for story upload progress',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: (progress * 100).round(),
      onlyAlertOnce: true,
      ongoing: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      uploadId.hashCode,
      'Uploading story...',
      currentStep,
      details,
    );

    debugPrint('UploadNotificationService: Showing upload progress: ${(progress * 100).toStringAsFixed(0)}%');
  }

  /// Update upload progress notification
  Future<void> updateUploadProgress({
    required String uploadId,
    required double progress,
    required String currentStep,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      'story_upload',
      'Story Upload',
      channelDescription: 'Notifications for story upload progress',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: (progress * 100).round(),
      onlyAlertOnce: true,
      ongoing: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      uploadId.hashCode,
      'Uploading story...',
      currentStep,
      details,
    );
  }

  /// Show upload completion notification
  Future<void> showUploadComplete({
    required String uploadId,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'story_upload',
      'Story Upload',
      channelDescription: 'Notifications for story upload progress',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      uploadId.hashCode,
      'Story uploaded successfully! 🎉',
      'Your story is now live',
      details,
    );

    debugPrint('UploadNotificationService: Showing upload complete notification');
  }

  /// Show upload failure notification
  Future<void> showUploadFailed({
    required String uploadId,
    String? errorMessage,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'story_upload',
      'Story Upload',
      channelDescription: 'Notifications for story upload progress',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      uploadId.hashCode,
      'Upload failed',
      errorMessage ?? 'Please try again',
      details,
    );

    debugPrint('UploadNotificationService: Showing upload failed notification');
  }

  /// Cancel upload notification
  Future<void> cancelNotification(String uploadId) async {
    await _notifications.cancel(uploadId.hashCode);
    debugPrint('UploadNotificationService: Cancelled notification for upload $uploadId');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('UploadNotificationService: Notification tapped: ${response.id}');
    // Handle notification tap - can navigate to story or show details
  }
}

