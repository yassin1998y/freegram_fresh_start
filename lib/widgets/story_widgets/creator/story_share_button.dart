// lib/widgets/story_widgets/creator/story_share_button.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

/// Share button for story creator
/// Shows upload progress or share button
class StoryShareButton extends StatelessWidget {
  final bool isUploading;
  final VoidCallback onShare;
  final double? uploadProgress;

  const StoryShareButton({
    Key? key,
    required this.isUploading,
    required this.onShare,
    this.uploadProgress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + DesignTokens.spaceLG,
      right: DesignTokens.spaceLG,
      child: isUploading
          ? Container(
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: DesignTokens.shadowMedium,
              ),
              child: SizedBox(
                width: DesignTokens.iconLG,
                height: DesignTokens.iconLG,
                child: AppProgressIndicator(
                  strokeWidth: DesignTokens.elevation1,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            )
          : GestureDetector(
              onTap: onShare,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceLG,
                  vertical: DesignTokens.spaceMD,
                ),
                decoration: BoxDecoration(
                  color: SonarPulseTheme.primaryAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                  border: Border.all(
                    color: SonarPulseTheme.primaryAccent.withValues(alpha: 0.5),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.send,
                      size: DesignTokens.iconMD,
                      color: SonarPulseTheme.primaryAccent,
                    ),
                    const SizedBox(width: DesignTokens.spaceSM),
                    Text(
                      'Share',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: SonarPulseTheme.primaryAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
