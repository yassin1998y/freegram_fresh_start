// lib/services/miui_permission_helper.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:freegram/services/device_info_helper.dart';
import 'package:app_settings/app_settings.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper service to handle MIUI-specific permissions and battery optimization
/// MIUI has additional permission layers that are not standard Android:
/// 1. Autostart permission (prevents app from being killed)
/// 2. Battery optimization (must be disabled for background services)
/// 3. Background popup permission (for notifications)
/// 4. Display over other apps (for certain features)
class MiuiPermissionHelper {
  static final MiuiPermissionHelper _instance =
      MiuiPermissionHelper._internal();
  factory MiuiPermissionHelper() => _instance;
  MiuiPermissionHelper._internal();

  /// Check if battery optimization is enabled for the app
  /// Returns true if app is being optimized (bad for background services)
  Future<bool> isBatteryOptimizationEnabled() async {
    if (!Platform.isAndroid) return false;

    try {
      // Check using permission_handler
      final status = await Permission.ignoreBatteryOptimizations.status;
      return !status.isGranted; // If not granted, optimization is enabled
    } catch (e) {
      debugPrint(
          'MiuiPermissionHelper: Error checking battery optimization: $e');
      return true; // Assume optimized if error
    }
  }

  /// Request to disable battery optimization
  /// This is critical for MIUI devices to prevent background service killing
  Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return false;

    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      debugPrint(
          'MiuiPermissionHelper: Battery optimization permission: $status');
      return status.isGranted;
    } catch (e) {
      debugPrint(
          'MiuiPermissionHelper: Error requesting battery optimization exemption: $e');
      return false;
    }
  }

  /// Open battery optimization settings directly
  Future<void> openBatteryOptimizationSettings() async {
    try {
      await AppSettings.openAppSettings(
          type: AppSettingsType.batteryOptimization);
    } catch (e) {
      debugPrint('MiuiPermissionHelper: Error opening battery settings: $e');
      // Fallback to general app settings
      await AppSettings.openAppSettings();
    }
  }

  /// Check if this is a MIUI device that needs special handling
  Future<bool> requiresMiuiPermissions() async {
    final deviceInfo = DeviceInfoHelper();
    await deviceInfo.initialize();
    return deviceInfo.isXiaomiDevice;
  }

  /// Show MIUI-specific permission guide dialog
  Future<void> showMiuiPermissionGuide(BuildContext context) async {
    final deviceInfo = DeviceInfoHelper();
    await deviceInfo.initialize();

    if (!deviceInfo.isXiaomiDevice) {
      // Not a Xiaomi device, show generic guide
      await _showGenericPermissionGuide(context);
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.battery_alert, color: Colors.orange),
            SizedBox(width: 8),
            Text('MIUI Permissions Required'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your ${deviceInfo.deviceName} requires additional permissions for Freegram to work properly in the background.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildPermissionStep(
                '1',
                'Disable Battery Optimization',
                'Tap "Battery Settings" below and select "No restrictions"',
              ),
              const SizedBox(height: 12),
              _buildPermissionStep(
                '2',
                'Enable Autostart',
                'Go to Settings → Apps → Freegram → Autostart → Enable',
              ),
              const SizedBox(height: 12),
              _buildPermissionStep(
                '3',
                'Lock App in Recent Apps',
                'Open Recent Apps, drag down on Freegram, tap lock icon',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Without these permissions, Freegram cannot discover nearby users when running in background.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await openBatteryOptimizationSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Battery Settings'),
          ),
        ],
      ),
    );
  }

  /// Show generic permission guide for non-MIUI devices
  Future<void> _showGenericPermissionGuide(BuildContext context) async {
    final deviceInfo = DeviceInfoHelper();
    await deviceInfo.initialize();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Battery Optimization'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'For the best experience, disable battery optimization for Freegram.',
            ),
            const SizedBox(height: 16),
            if (deviceInfo.hasAggressiveBatteryOptimization)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  deviceInfo.getBatteryOptimizationGuidance(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openBatteryOptimizationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Build permission step widget
  Widget _buildPermissionStep(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Check all critical permissions and settings for background operation
  Future<Map<String, bool>> checkAllPermissions() async {
    final results = <String, bool>{};

    // Standard Bluetooth permissions
    results['bluetooth'] = await Permission.bluetooth.isGranted;
    results['bluetoothScan'] = await Permission.bluetoothScan.isGranted;
    results['bluetoothConnect'] = await Permission.bluetoothConnect.isGranted;
    results['bluetoothAdvertise'] =
        await Permission.bluetoothAdvertise.isGranted;

    // Location permissions (required for Bluetooth scanning on Android)
    results['location'] = await Permission.locationWhenInUse.isGranted;

    // Battery optimization
    results['batteryOptimization'] =
        await Permission.ignoreBatteryOptimizations.isGranted;

    // Notification permission (Android 13+)
    if (Platform.isAndroid) {
      results['notification'] = await Permission.notification.isGranted;
    }

    debugPrint('MiuiPermissionHelper: Permission status: $results');
    return results;
  }

  /// Request all critical permissions at once
  Future<bool> requestAllPermissions() async {
    final permissions = await checkAllPermissions();
    final missingPermissions = <Permission>[];

    if (!(permissions['bluetoothScan'] ?? false)) {
      missingPermissions.add(Permission.bluetoothScan);
    }
    if (!(permissions['bluetoothConnect'] ?? false)) {
      missingPermissions.add(Permission.bluetoothConnect);
    }
    if (!(permissions['bluetoothAdvertise'] ?? false)) {
      missingPermissions.add(Permission.bluetoothAdvertise);
    }
    if (!(permissions['location'] ?? false)) {
      missingPermissions.add(Permission.locationWhenInUse);
    }
    if (!(permissions['notification'] ?? false) && Platform.isAndroid) {
      missingPermissions.add(Permission.notification);
    }

    if (missingPermissions.isNotEmpty) {
      final results = await missingPermissions.request();
      debugPrint('MiuiPermissionHelper: Permission request results: $results');
    }

    // Always request battery optimization exemption last (shows separate dialog)
    if (!(permissions['batteryOptimization'] ?? false)) {
      await requestBatteryOptimizationExemption();
    }

    // Check if all granted now
    final updatedPermissions = await checkAllPermissions();
    return updatedPermissions.values.every((granted) => granted);
  }
}
