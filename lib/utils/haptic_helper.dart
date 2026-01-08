import 'package:flutter/services.dart';

/// Helper class for haptic feedback throughout the app
class HapticHelper {
  /// Light impact - for subtle interactions like taps
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Medium impact - for standard button presses
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact - for important actions like confirmations
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Selection click - for picker/selector changes
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Success feedback - for successful operations
  static void success() {
    HapticFeedback.mediumImpact();
  }

  /// Error feedback - for failed operations
  static void error() {
    HapticFeedback.heavyImpact();
  }

  /// Vibrate - for notifications or alerts
  static void vibrate() {
    HapticFeedback.vibrate();
  }
}
