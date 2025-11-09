// lib/widgets/common/app_progress_indicator.dart

import 'package:flutter/material.dart';

/// Reusable progress indicator widget that follows app theme
///
/// This widget standardizes progress indicators across the app,
/// automatically using theme colors and providing consistent sizing.
///
/// Usage:
/// ```dart
/// // Simple usage (uses theme primary color)
/// AppProgressIndicator()
///
/// // Custom color
/// AppProgressIndicator(color: Colors.white)
///
/// // Sized indicator
/// AppProgressIndicator(size: 24.0)
///
/// // With custom stroke width
/// AppProgressIndicator(strokeWidth: 3.0)
/// ```
class AppProgressIndicator extends StatelessWidget {
  /// Custom color for the indicator. If null, uses theme primary color.
  final Color? color;

  /// Size of the indicator. If null, uses default size.
  final double? size;

  /// Stroke width of the indicator. Defaults to 4.0.
  final double strokeWidth;

  /// Background color for the indicator track. If null, uses default.
  final Color? backgroundColor;

  /// Value between 0.0 and 1.0 for determinate progress. If null, shows indeterminate.
  final double? value;

  const AppProgressIndicator({
    super.key,
    this.color,
    this.size,
    this.strokeWidth = 4.0,
    this.backgroundColor,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine the color to use
    final indicatorColor = color ?? theme.colorScheme.primary;

    // Determine background color
    final trackColor = backgroundColor ??
        (color?.withOpacity(0.2) ?? theme.colorScheme.primary.withOpacity(0.2));

    // If size is specified, wrap in SizedBox
    if (size != null) {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          value: value,
          color: indicatorColor,
          backgroundColor: trackColor,
          strokeWidth: strokeWidth,
        ),
      );
    }

    // Default size
    return CircularProgressIndicator(
      value: value,
      color: indicatorColor,
      backgroundColor: trackColor,
      strokeWidth: strokeWidth,
    );
  }
}

/// Linear progress indicator variant
class AppLinearProgressIndicator extends StatelessWidget {
  /// Custom color for the indicator. If null, uses theme primary color.
  final Color? color;

  /// Background color for the indicator track. If null, uses default.
  final Color? backgroundColor;

  /// Value between 0.0 and 1.0 for determinate progress. If null, shows indeterminate.
  final double? value;

  /// Minimum height of the indicator. Defaults to 4.0.
  final double minHeight;

  const AppLinearProgressIndicator({
    super.key,
    this.color,
    this.backgroundColor,
    this.value,
    this.minHeight = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine the color to use
    final indicatorColor = color ?? theme.colorScheme.primary;

    // Determine background color
    final trackColor = backgroundColor ??
        (color?.withOpacity(0.2) ?? theme.colorScheme.primary.withOpacity(0.2));

    return LinearProgressIndicator(
      value: value,
      color: indicatorColor,
      backgroundColor: trackColor,
      minHeight: minHeight,
    );
  }
}
