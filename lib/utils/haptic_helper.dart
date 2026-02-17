import 'package:flutter/services.dart';

/// Helper class for haptic feedback throughout the app
class HapticHelper {
  /// Light impact - for subtle interactions like taps
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Alias for light()
  static void lightImpact() {
    HapticFeedback.lightImpact();
  }

  /// Medium impact - for standard button presses
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Alias for medium()
  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact - for important actions like confirmations
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Alias for heavy() as requested by implementation specs
  static void heavyImpact() {
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
