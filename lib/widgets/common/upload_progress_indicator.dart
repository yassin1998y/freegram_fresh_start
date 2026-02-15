// lib/widgets/common/upload_progress_indicator.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Circular progress indicator for upload progress
class UploadProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final String? currentStep;
  final double size;
  final double strokeWidth;

  const UploadProgressIndicator({
    Key? key,
    required this.progress,
    this.currentStep,
    this.size = 40.0,
    this.strokeWidth = 4.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // CRITICAL FIX: Use RepaintBoundary to isolate repaints and prevent shaking
    // Use fixed-size container to prevent layout shifts
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background circle
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: strokeWidth,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  SonarPulseTheme.primaryAccent,
                ),
              ),
            ),
            // Percentage text - fixed width to prevent size changes
            SizedBox(
              width: size * 0.7,
              child: Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.bold,
                  // Use textBaseline to ensure consistent vertical alignment
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact upload progress indicator with step text
class CompactUploadProgressIndicator extends StatelessWidget {
  final double progress;
  final String currentStep;

  const CompactUploadProgressIndicator({
    Key? key,
    required this.progress,
    required this.currentStep,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UploadProgressIndicator(
          progress: progress,
          size: 32.0,
          strokeWidth: 3.0,
        ),
        const SizedBox(width: DesignTokens.spaceSM),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: DesignTokens.fontSizeSM,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              currentStep,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: DesignTokens.fontSizeXS,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

