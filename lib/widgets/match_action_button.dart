import 'dart:async';

import 'package:flutter/material.dart';
import 'package:freegram/widgets/common/app_button.dart';

/// Configuration for match screen action buttons
class MatchActionButtonConfig {
  final IconData icon;
  final Color color;
  final String label;
  final String tooltip;
  final double size;
  final double iconSize;
  final VoidCallback? onPressed;
  final String? badge;
  final bool isDisabled;
  final bool isPrimary;
  final HapticFeedbackType hapticType;

  const MatchActionButtonConfig({
    required this.icon,
    required this.color,
    required this.label,
    required this.tooltip,
    this.size = 56.0,
    this.iconSize = 24.0,
    this.onPressed,
    this.badge,
    this.isDisabled = false,
    this.isPrimary = false,
    this.hapticType = HapticFeedbackType.selection,
  });
}

enum HapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
}

/// Professional action button component for match screen
///
/// DEPRECATED: Use AppActionButton from app_button.dart instead
/// This class is kept for backward compatibility but delegates to AppActionButton
///
/// Features:
/// - Smooth press animations with proper feedback
/// - Accessibility support with semantic labels
/// - Haptic feedback variations
/// - Disabled state handling
/// - Badge support for counters
/// - Theme-aware styling
@Deprecated('Use AppActionButton from app_button.dart instead')
class MatchActionButton extends StatelessWidget {
  final MatchActionButtonConfig config;
  final Duration animationDuration;
  final bool showLabel;

  const MatchActionButton({
    super.key,
    required this.config,
    this.animationDuration = const Duration(milliseconds: 150),
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    // Convert HapticFeedbackType to AppButtonHapticType
    AppButtonHapticType hapticType;
    switch (config.hapticType) {
      case HapticFeedbackType.light:
        hapticType = AppButtonHapticType.light;
        break;
      case HapticFeedbackType.medium:
        hapticType = AppButtonHapticType.medium;
        break;
      case HapticFeedbackType.heavy:
        hapticType = AppButtonHapticType.heavy;
        break;
      case HapticFeedbackType.selection:
        hapticType = AppButtonHapticType.selection;
        break;
    }

    return AppActionButton(
      icon: config.icon,
      label: config.label,
      onPressed: config.onPressed,
      tooltip: config.tooltip,
      color: config.color,
      badge: config.badge,
      isDisabled: config.isDisabled,
      isPrimary: config.isPrimary,
      size: config.size,
      iconSize: config.iconSize,
      hapticType: hapticType,
      animationDuration: animationDuration,
      showLabel: showLabel,
    );
  }
}

/// Debouncer utility to prevent rapid button presses
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
