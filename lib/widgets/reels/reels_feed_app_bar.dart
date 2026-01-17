// lib/widgets/reels/reels_feed_app_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/services/reel_upload_service.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

/// AppBar for Reels Feed Screen
/// Includes back button, upload progress indicator, and create reel button
class ReelsFeedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ReelUploadService uploadService;
  final VoidCallback onBackPressed;
  final VoidCallback onCreateReel;

  const ReelsFeedAppBar({
    Key? key,
    required this.uploadService,
    required this.onBackPressed,
    required this.onCreateReel,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // For reels feed, use white text/icons on dark/transparent background
    const iconColor = Colors.white;
    const textColor = Colors.white;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: iconColor,
              size: DesignTokens.iconLG,
            ),
            onPressed: onBackPressed,
          ),
          // Upload progress indicator next to back button
          if (uploadService.isUploading)
            Padding(
              padding: const EdgeInsets.only(left: DesignTokens.spaceXS),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceSM,
                  vertical: DesignTokens.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(DesignTokens.opacityMedium),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppProgressIndicator(
                      size: DesignTokens.iconXS,
                      value: uploadService.uploadProgress,
                      strokeWidth: DesignTokens.elevation1,
                      color: SonarPulseTheme.primaryAccent,
                      backgroundColor: Colors.white.withOpacity(
                        DesignTokens.opacityMedium * 0.5,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceXS),
                    Text(
                      '${(uploadService.uploadProgress * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor,
                        fontSize: DesignTokens.fontSizeXS,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      title: Text(
        'Reels',
        style: theme.textTheme.titleLarge?.copyWith(
          color: textColor,
          fontSize: DesignTokens.fontSizeLG,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        // Create Reel button
        IconButton(
          icon: const Icon(
            Icons.add_circle_outline,
            color: iconColor,
            size: DesignTokens.iconLG,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            onCreateReel();
          },
          tooltip: 'Create Reel',
          padding: const EdgeInsets.all(DesignTokens.spaceSM),
          constraints: const BoxConstraints(
            minWidth: DesignTokens.buttonHeight,
            minHeight: DesignTokens.buttonHeight,
          ),
        ),
        const SizedBox(width: DesignTokens.spaceXS),
      ],
    );
  }
}
