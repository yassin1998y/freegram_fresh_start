import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WindowManagerService {
  static const MethodChannel _channel =
      MethodChannel('freegram/window_manager');

  // Android WindowManager.LayoutParams.FLAG_SECURE = 0x00002000 => 8192
  static const int FLAG_SECURE = 8192;

  static Future<void> addFlags(int flags) async {
    try {
      await _channel.invokeMethod('addFlags', {'flags': flags});
    } on MissingPluginException {
      debugPrint(
          "⚠️ [WindowManager] Native channel not found (MissingPlugin).");
    } catch (e) {
      debugPrint("⚠️ [WindowManager] Failed to add flags: $e");
    }
  }

  static Future<void> clearFlags(int flags) async {
    try {
      await _channel.invokeMethod('clearFlags', {'flags': flags});
    } on MissingPluginException {
      debugPrint(
          "⚠️ [WindowManager] Native channel not found (MissingPlugin).");
    } catch (e) {
      debugPrint("⚠️ [WindowManager] Failed to clear flags: $e");
    }
  }
}
