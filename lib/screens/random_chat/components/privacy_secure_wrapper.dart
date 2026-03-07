import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivacySecureWrapper extends StatefulWidget {
  final Widget child;

  const PrivacySecureWrapper({super.key, required this.child});

  @override
  State<PrivacySecureWrapper> createState() => _PrivacySecureWrapperState();
}

class _PrivacySecureWrapperState extends State<PrivacySecureWrapper> {
  static const _windowChannel = MethodChannel('freegram/window_manager');
  static const int _flagSecure = 8192;

  @override
  void initState() {
    super.initState();
    _enableSecureMode();
  }

  @override
  void dispose() {
    _disableSecureMode();
    super.dispose();
  }

  Future<void> _enableSecureMode() async {
    if (Theme.of(context).platform != TargetPlatform.android) return;
    try {
      await _windowChannel.invokeMethod('addFlags', {'flags': _flagSecure});
      debugPrint('[PrivacySecureWrapper] FLAG_SECURE added');
    } catch (e) {
      debugPrint('[PrivacySecureWrapper] Error adding FLAG_SECURE: $e');
    }
  }

  Future<void> _disableSecureMode() async {
    if (Theme.of(context).platform != TargetPlatform.android) return;
    try {
      await _windowChannel.invokeMethod('clearFlags', {'flags': _flagSecure});
      debugPrint('[PrivacySecureWrapper] FLAG_SECURE cleared');
    } catch (e) {
      debugPrint('[PrivacySecureWrapper] Error clearing FLAG_SECURE: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
