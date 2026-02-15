// lib/widgets/reels/reel_upload_progress_overlay.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/utils/reel_constants.dart';

/// Upload progress overlay for reels
/// Shows upload progress with percentage
class ReelUploadProgressOverlay extends StatelessWidget {
  final double uploadProgress;

  const ReelUploadProgressOverlay({
    Key? key,
    required this.uploadProgress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      top: MediaQuery.of(context).padding.top + DesignTokens.spaceMD,
      left: DesignTokens.spaceMD,
      right: DesignTokens.spaceMD,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMD,
          vertical: DesignTokens.spaceSM,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: DesignTokens.opacityHigh),
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        ),
        child: Row(
          children: [
            AppProgressIndicator(
              size: ReelConstants.uploadProgressIndicatorSize,
              value: uploadProgress,
              strokeWidth: ReelConstants.uploadProgressIndicatorStrokeWidth,
              color: SonarPulseTheme.primaryAccent,
              backgroundColor: Colors.white.withValues(alpha: 
                DesignTokens.opacityMedium * 0.5,
              ),
            ),
            const SizedBox(width: DesignTokens.spaceSM),
            Expanded(
              child: Text(
                'Uploading ${(uploadProgress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
