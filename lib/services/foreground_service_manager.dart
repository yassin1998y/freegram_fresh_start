// lib/services/foreground_service_manager.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Manager for starting/stopping Android Foreground Service
/// Critical for MIUI/Xiaomi devices to prevent background process killing
class ForegroundServiceManager {
  static final ForegroundServiceManager _instance =
      ForegroundServiceManager._internal();
  factory ForegroundServiceManager() => _instance;
  ForegroundServiceManager._internal();

  static const MethodChannel _channel =
      MethodChannel('freegram/foreground_service');

  bool _isServiceRunning = false;

  /// Check if foreground service is currently running
  bool get isServiceRunning => _isServiceRunning;

  /// Start the foreground service (Android only)
  /// This creates a persistent notification that prevents MIUI from killing the app
  Future<bool> startService() async {
    if (!Platform.isAndroid) return false;
    if (_isServiceRunning) {
      debugPrint(
          'ForegroundServiceManager: Service already running, skipping start');
      return true;
    }

    try {
      // Start the foreground service via platform channel
      final result = await _channel.invokeMethod('startForegroundService');
      _isServiceRunning = result == true;

      if (_isServiceRunning) {
        debugPrint(
            'ForegroundServiceManager: Foreground service started successfully');
      } else {
        debugPrint(
            'ForegroundServiceManager: Failed to start foreground service');
      }

      return _isServiceRunning;
    } catch (e) {
      debugPrint('ForegroundServiceManager: Error starting service: $e');
      return false;
    }
  }

  /// Stop the foreground service (Android only)
  Future<bool> stopService() async {
    if (!Platform.isAndroid) return false;
    if (!_isServiceRunning) {
      debugPrint(
          'ForegroundServiceManager: Service not running, skipping stop');
      return true;
    }

    try {
      // Stop the foreground service via platform channel
      final result = await _channel.invokeMethod('stopForegroundService');
      _isServiceRunning = false;

      debugPrint('ForegroundServiceManager: Foreground service stopped');
      return result == true;
    } catch (e) {
      debugPrint('ForegroundServiceManager: Error stopping service: $e');
      _isServiceRunning = false; // Assume stopped on error
      return false;
    }
  }

  /// Update the foreground service notification
  /// Useful for showing current status (e.g., "3 users nearby")
  Future<void> updateNotification({
    required String title,
    required String content,
  }) async {
    if (!Platform.isAndroid || !_isServiceRunning) return;

    try {
      await _channel.invokeMethod('updateNotification', {
        'title': title,
        'content': content,
      });
    } catch (e) {
      debugPrint('ForegroundServiceManager: Error updating notification: $e');
    }
  }
}
