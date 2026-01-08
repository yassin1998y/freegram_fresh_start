// lib/widgets/common/empty_state_widget.dart
// Reusable empty state widget for consistent UI across the app

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

/// A reusable empty state widget that displays:
/// - A large, friendly icon
/// - A title
/// - A subtitle/description
/// - An optional action button
class EmptyStateWidget extends StatelessWidget {
  /// Icon to display (large, friendly)
  final IconData icon;

  /// Title text (e.g., "No Messages Yet")
  final String title;

  /// Subtitle/description text (e.g., "Start a conversation with a friend!")
  final String subtitle;

  /// Optional action button label (e.g., "Find Friends")
  final String? actionLabel;

  /// Optional callback for action button tap
  final VoidCallback? onAction;

  /// Optional icon color (defaults to theme's primary color with opacity)
  final Color? iconColor;

  /// Optional icon size (defaults to iconXXL * 2)
  final double? iconSize;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ??
        theme.colorScheme.primary.withOpacity(DesignTokens.opacityMedium);
    final effectiveIconSize = iconSize ?? DesignTokens.iconXXL * 2;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large, friendly icon
            Icon(
              icon,
              size: effectiveIconSize,
              color: effectiveIconColor,
            ),
            const SizedBox(height: DesignTokens.spaceLG),
            // Title
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: DesignTokens.fontSizeXXL,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            // Subtitle
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(
                  DesignTokens.opacityMedium,
                ),
                fontSize: DesignTokens.fontSizeMD,
                height: DesignTokens.lineHeightNormal,
              ),
              textAlign: TextAlign.center,
            ),
            // Optional action button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: DesignTokens.spaceXL),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceLG,
                    vertical: DesignTokens.spaceMD,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
