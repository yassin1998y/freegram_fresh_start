// lib/services/native_gatt.dart

import 'dart:async';
import 'package:flutter/services.dart';

// Renamed for clarity, as it no longer manages a GATT server for discovery.
class NativeAdvertiser {
  static const MethodChannel _channel = MethodChannel('freegram/gatt');

  static Future<bool> startAdvertising(String uid) async {
    try {
      final res = await _channel.invokeMethod<bool>('startAdvertising', {'uid': uid});
      return res ?? false;
    } on PlatformException catch (e) {
      print('Failed to start advertising: ${e.message}');
      return false;
    }
  }

  static Future<void> stopAdvertising() async {
    try {
      await _channel.invokeMethod('stopAdvertising');
    } on PlatformException catch (e) {
      print('Failed to stop advertising: ${e.message}');
    }
  }
}