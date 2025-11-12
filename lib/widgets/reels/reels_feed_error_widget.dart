// lib/widgets/reels/reels_feed_error_widget.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

/// Error widget for Reels Feed
/// Displays error message with retry button
class ReelsFeedErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ReelsFeedErrorWidget({
    Key? key,
    required this.message,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // For reels feed, use white text/icons on dark background
    final iconColor = Colors.white;
    final textColor = Colors.white;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: DesignTokens.iconXXL,
            color: iconColor,
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceLG,
            ),
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontSize: DesignTokens.fontSizeMD,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLG),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: SonarPulseTheme.primaryAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
