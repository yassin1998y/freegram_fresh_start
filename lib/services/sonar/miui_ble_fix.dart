// lib/services/sonar/miui_ble_fix.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:freegram/services/device_info_helper.dart';

/// MIUI-specific BLE advertising fixes for Error 18
/// MIUI severely limits concurrent BLE advertisers (usually 3-5 system-wide)
/// This service implements workarounds specifically for Xiaomi/Redmi/POCO devices
class MiuiBleFixService {
  static final MiuiBleFixService _instance = MiuiBleFixService._internal();
  factory MiuiBleFixService() => _instance;
  MiuiBleFixService._internal();

  static const MethodChannel _channel = MethodChannel('freegram/gatt');

  final DeviceInfoHelper _deviceInfo = DeviceInfoHelper();
  bool _isInitialized = false;
  bool _useNativeAdvertiser = false;

  /// Initialize MIUI-specific BLE fixes
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _deviceInfo.initialize();

    if (_deviceInfo.isXiaomiDevice) {
      debugPrint(
          '[MIUI BLE Fix] Xiaomi device detected, applying MIUI-specific workarounds');

      // Try to clear BLE cache on MIUI
      await _clearBluetoothCache();

      // Check if native advertiser is available as fallback
      _useNativeAdvertiser = await _checkNativeAdvertiserAvailability();
    }

    _isInitialized = true;
  }

  /// Check if this is a MIUI device that needs special handling
  bool get isMiuiDevice => _deviceInfo.isXiaomiDevice;

  /// Check if we should use native advertiser instead of flutter_ble_peripheral
  bool get shouldUseNativeAdvertiser => _useNativeAdvertiser && isMiuiDevice;

  /// Clear Bluetooth cache on MIUI (helps free up advertising slots)
  Future<bool> _clearBluetoothCache() async {
    if (!Platform.isAndroid || !isMiuiDevice) return false;

    try {
      debugPrint('[MIUI BLE Fix] Attempting to clear Bluetooth cache...');
      // This would require a platform channel implementation
      // For now, just log the attempt
      return true;
    } catch (e) {
      debugPrint('[MIUI BLE Fix] Error clearing Bluetooth cache: $e');
      return false;
    }
  }

  /// Check if native advertiser (MainActivity) is available
  Future<bool> _checkNativeAdvertiserAvailability() async {
    if (!Platform.isAndroid) return false;

    try {
      // Check if the native advertising channel responds
      await _channel.invokeMethod('stopAdvertising');
      debugPrint('[MIUI BLE Fix] Native advertiser is available');
      return true;
    } catch (e) {
      debugPrint('[MIUI BLE Fix] Native advertiser check failed: $e');
      return false;
    }
  }

  /// Start advertising using native Android implementation (fallback for MIUI)
  /// This uses the AdvertiserManager in MainActivity.kt
  Future<bool> startNativeAdvertising(String uidShort, int gender) async {
    if (!Platform.isAndroid) return false;

    try {
      debugPrint(
          '[MIUI BLE Fix] Starting native advertising with UID: $uidShort, gender: $gender');

      // Build payload as hex string: uidShort (8 hex chars = 4 bytes) + gender (2 hex chars = 1 byte)
      // Example: "d02ebe8b" + "01" = "d02ebe8b01"
      // The native code will convert this hex string to actual bytes
      final String genderHex = gender.toRadixString(16).padLeft(2, '0');
      final String payload = '$uidShort$genderHex';

      debugPrint('[MIUI BLE Fix] Native advertising payload (hex): $payload');

      final result = await _channel.invokeMethod('startAdvertising', {
        'uid': payload,
      });

      if (result == true) {
        debugPrint('[MIUI BLE Fix] Native advertising started successfully');
        return true;
      } else {
        debugPrint('[MIUI BLE Fix] Native advertising failed to start');
        return false;
      }
    } catch (e) {
      debugPrint('[MIUI BLE Fix] Error starting native advertising: $e');
      return false;
    }
  }

  /// Stop native advertising
  Future<bool> stopNativeAdvertising() async {
    if (!Platform.isAndroid) return false;

    try {
      await _channel.invokeMethod('stopAdvertising');
      debugPrint('[MIUI BLE Fix] Native advertising stopped');
      return true;
    } catch (e) {
      debugPrint('[MIUI BLE Fix] Error stopping native advertising: $e');
      return false;
    }
  }

  /// Reset Bluetooth adapter (helps clear advertising slots on MIUI)
  Future<bool> resetBluetoothAdapter() async {
    if (!Platform.isAndroid || !isMiuiDevice) return false;

    try {
      debugPrint('[MIUI BLE Fix] Resetting Bluetooth adapter...');

      // This requires platform implementation
      // Turning Bluetooth off/on programmatically requires BLUETOOTH_ADMIN permission
      // and may not work on Android 13+

      // For now, just notify user to manually reset
      debugPrint('[MIUI BLE Fix] Manual Bluetooth reset recommended');
      return false;
    } catch (e) {
      debugPrint('[MIUI BLE Fix] Error resetting Bluetooth: $e');
      return false;
    }
  }

  /// Get recommended MIUI-specific settings message
  String getMiuiAdvertisingGuidance() {
    if (!isMiuiDevice) return '';

    return '''
MIUI BLE Advertising Fix (Error 18):

To fix "Too many advertisers" on your Redmi device:

1. CLOSE these apps (they use BLE advertising slots):
   • Mi Smart Home / Mi Home
   • Mi Fit / Xiaomi Fitness
   • Mi Remote
   • Find My Device
   • Any other Bluetooth apps

2. Clear Bluetooth cache:
   Settings → Apps → Show system apps → Bluetooth → Clear cache

3. Restart Bluetooth:
   Turn Bluetooth OFF for 10 seconds, then ON

4. Restart Freegram

This is a MIUI limitation - Xiaomi restricts BLE advertising slots.
''';
  }

  /// Check if other apps might be using BLE advertising slots
  Future<List<String>> getConflictingApps() async {
    // Common Xiaomi apps that use BLE advertising
    final List<String> potentialConflicts = [
      'com.xiaomi.smarthome', // Mi Home
      'com.mi.health', // Mi Fit
      'com.xiaomi.hm.health', // Mi Fitness
      'com.duokan.phone.remotecontroller', // Mi Remote
      'com.xiaomi.finddevice', // Find My Device
      'com.xiaomi.xmsf', // Xiaomi Service Framework
      'com.miui.securitycenter', // MIUI Security
    ];

    // In a real implementation, you'd check if these are running
    // For now, just return the list for user reference
    return potentialConflicts;
  }

  /// Diagnose BLE advertising issues on MIUI
  Future<Map<String, dynamic>> diagnoseMiuiAdvertisingIssue() async {
    if (!isMiuiDevice) {
      return {
        'isMiui': false,
        'canAdvertise': true,
        'issues': <String>[],
      };
    }

    final List<String> issues = [];

    // Check device info
    issues.add('Device: ${_deviceInfo.deviceName}');
    issues.add('Manufacturer: ${_deviceInfo.manufacturer}');

    // Check for known MIUI issues
    issues.add('MIUI BLE advertising slots limited (max 3-5 system-wide)');
    issues.add('Error 18 = ADVERTISE_FAILED_TOO_MANY_ADVERTISERS');

    // Check for conflicting apps
    final conflicts = await getConflictingApps();
    if (conflicts.isNotEmpty) {
      issues.add('Potentially conflicting apps: ${conflicts.length}');
    }

    return {
      'isMiui': true,
      'deviceName': _deviceInfo.deviceName,
      'nativeAdvertiserAvailable': _useNativeAdvertiser,
      'issues': issues,
      'guidance': getMiuiAdvertisingGuidance(),
    };
  }

  /// Send a wave broadcast using native advertiser (for better MIUI compatibility)
  Future<bool> sendWaveBroadcast(
      String senderUidShort, String targetUidShort) async {
    if (!Platform.isAndroid) return false;

    try {
      debugPrint(
          '[MIUI BLE Fix] Starting native wave broadcast from $senderUidShort to $targetUidShort');

      // Build wave payload: sender (4 bytes) + target (4 bytes) = 8 bytes hex string
      final String payload = '$senderUidShort$targetUidShort';

      debugPrint('[MIUI BLE Fix] Native wave payload (hex): $payload');

      final result = await _channel.invokeMethod('startWaveAdvertising', {
        'payload': payload,
      });

      if (result == true) {
        debugPrint('[MIUI BLE Fix] Native wave broadcast started successfully');
        return true;
      } else {
        debugPrint('[MIUI BLE Fix] Native wave broadcast failed');
        return false;
      }
    } catch (e) {
      debugPrint('[MIUI BLE Fix] Error starting native wave broadcast: $e');
      return false;
    }
  }

  /// Send a wave broadcast using Service Data (MIUI FIX - bypasses manufacturer data filtering)
  /// This is the preferred method for MIUI devices as MIUI is less likely to filter service data
  Future<bool> sendServiceDataWaveBroadcast(
      String senderUidShort, String targetUidShort) async {
    if (!Platform.isAndroid) return false;

    try {
      debugPrint(
          '[MIUI BLE Fix] Starting SERVICE DATA wave broadcast from $senderUidShort to $targetUidShort');

      // Build wave payload: sender (4 bytes) + target (4 bytes) = 8 bytes hex string
      final String payload = '$senderUidShort$targetUidShort';

      debugPrint('[MIUI BLE Fix] Service Data wave payload (hex): $payload');

      final result =
          await _channel.invokeMethod('startServiceDataWaveAdvertising', {
        'payload': payload,
      });

      if (result == true) {
        debugPrint(
            '[MIUI BLE Fix] Service Data wave broadcast started successfully');
        return true;
      } else {
        debugPrint('[MIUI BLE Fix] Service Data wave broadcast failed');
        return false;
      }
    } catch (e) {
      debugPrint(
          '[MIUI BLE Fix] Error starting Service Data wave broadcast: $e');
      return false;
    }
  }
}
