// lib/widgets/reels/reels_feed_empty_widget.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

/// Empty state widget for Reels Feed
/// Displays when no reels are available
class ReelsFeedEmptyWidget extends StatelessWidget {
  final VoidCallback onCreateReel;

  const ReelsFeedEmptyWidget({
    Key? key,
    required this.onCreateReel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // For reels feed, use white text/icons on dark background
    final iconColor = Colors.white.withOpacity(DesignTokens.opacityMedium);
    final textColor = Colors.white.withOpacity(DesignTokens.opacityMedium);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: DesignTokens.iconXXL,
            color: iconColor,
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          Text(
            'No reels available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontSize: DesignTokens.fontSizeMD,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXL),
          ElevatedButton.icon(
            onPressed: onCreateReel,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Create Your First Reel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SonarPulseTheme.primaryAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceLG,
                vertical: DesignTokens.spaceMD,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
