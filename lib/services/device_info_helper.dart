// lib/services/device_info_helper.dart
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Helper service to detect device manufacturer and handle device-specific issues
/// Particularly important for MIUI/Xiaomi/Redmi devices which have aggressive
/// battery optimization and background process killing
class DeviceInfoHelper {
  static final DeviceInfoHelper _instance = DeviceInfoHelper._internal();
  factory DeviceInfoHelper() => _instance;
  DeviceInfoHelper._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Cache device info to avoid repeated calls
  String? _manufacturer;
  String? _model;
  String? _brand;
  bool? _isXiaomiDevice;

  /// Initialize device info (call this early in app lifecycle)
  Future<void> initialize() async {
    if (_manufacturer != null) return; // Already initialized

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _manufacturer = androidInfo.manufacturer.toLowerCase();
        _model = androidInfo.model.toLowerCase();
        _brand = androidInfo.brand.toLowerCase();

        // Check if it's a Xiaomi/Redmi/POCO device
        _isXiaomiDevice = _manufacturer == 'xiaomi' ||
            _brand == 'xiaomi' ||
            _brand == 'redmi' ||
            _brand == 'poco' ||
            (_model?.contains('redmi') ?? false) ||
            (_model?.contains('poco') ?? false);

        if (kDebugMode) {
          debugPrint(
              'DeviceInfoHelper: Manufacturer=$_manufacturer, Brand=$_brand, Model=$_model, IsXiaomi=$_isXiaomiDevice');
        }
      } else {
        _isXiaomiDevice = false;
      }
    } catch (e) {
      debugPrint('DeviceInfoHelper: Error getting device info: $e');
      _isXiaomiDevice = false;
    }
  }

  /// Check if this is a Xiaomi/Redmi/POCO device (MIUI)
  bool get isXiaomiDevice {
    return _isXiaomiDevice ?? false;
  }

  /// Check if this is a MIUI device (same as Xiaomi check)
  bool get isMiuiDevice => isXiaomiDevice;

  /// Get device manufacturer
  String get manufacturer => _manufacturer ?? 'unknown';

  /// Get device brand
  String get brand => _brand ?? 'unknown';

  /// Get device model
  String get model => _model ?? 'unknown';

  /// Check if device is known for aggressive battery optimization
  /// Includes MIUI, ColorOS (Oppo), FunTouch (Vivo), EMUI (Huawei)
  bool get hasAggressiveBatteryOptimization {
    if (_manufacturer == null) return false;

    final aggressiveManufacturers = [
      'xiaomi',
      'redmi',
      'poco',
      'oppo',
      'vivo',
      'huawei',
      'honor',
      'oneplus',
      'realme',
    ];

    return aggressiveManufacturers.any((m) =>
        (_manufacturer?.contains(m) ?? false) ||
        (_brand?.contains(m) ?? false) ||
        (_model?.contains(m) ?? false));
  }

  /// Get user-friendly device name
  String get deviceName {
    if (_brand != null && _model != null) {
      return '${_brand!.toUpperCase()} $_model';
    }
    return 'Unknown device';
  }

  /// Get guidance text for battery optimization based on device
  String getBatteryOptimizationGuidance() {
    if (isXiaomiDevice) {
      return '''
MIUI Battery Optimization Tips:

1. Enable "Autostart" permission:
   Settings → Apps → Freegram → Autostart → Enable

2. Disable Battery Saver:
   Settings → Battery & Performance → Freegram → No restrictions

3. Lock app in Recent Apps:
   Open Recent Apps → Drag down on Freegram → Lock icon

4. Enable Background Activity:
   Settings → Battery → App Battery Saver → Freegram → No restrictions
''';
    } else if (_manufacturer == 'oppo' || _brand == 'oppo') {
      return '''
ColorOS Battery Optimization Tips:

1. Enable Autostart:
   Settings → App Management → Freegram → Autostart → Enable

2. Disable Battery Optimization:
   Settings → Battery → Freegram → Don't optimize

3. Lock app in Recent Apps
''';
    } else if (_manufacturer == 'huawei' || _brand == 'huawei') {
      return '''
EMUI Battery Optimization Tips:

1. Enable Protected Apps:
   Settings → Apps → Protected Apps → Enable Freegram

2. Disable Battery Optimization:
   Settings → Battery → App Launch → Freegram → Manage manually

3. Lock app in Recent Apps
''';
    } else if (_manufacturer == 'samsung' || _brand == 'samsung') {
      return '''
Samsung Battery Optimization Tips:

1. Disable Battery Optimization:
   Settings → Apps → Freegram → Battery → Optimize battery usage → All → Freegram → Don't optimize

2. Add to Never Sleeping Apps:
   Settings → Battery → Background usage limits → Never sleeping apps → Add Freegram
''';
    } else {
      return '''
Battery Optimization Tips:

1. Disable battery optimization for Freegram
2. Allow background activity
3. Lock app in recent apps to prevent it from being closed
''';
    }
  }
}
