// lib/widgets/reels/reel_camera_preview_widget.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/utils/reel_constants.dart';

/// Camera preview widget for recording reels
/// Shows camera preview with recording indicator and controls
class ReelCameraPreviewWidget extends StatelessWidget {
  final CameraController cameraController;
  final bool isRecording;
  final int recordingDuration;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  const ReelCameraPreviewWidget({
    Key? key,
    required this.cameraController,
    required this.isRecording,
    required this.recordingDuration,
    required this.onStartRecording,
    required this.onStopRecording,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: CameraPreview(cameraController),
        ),
        // Recording indicator
        if (isRecording)
          Positioned(
            top: MediaQuery.of(context).padding.top + DesignTokens.spaceMD,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: DesignTokens.spaceSM,
                horizontal: DesignTokens.spaceMD,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 
                  DesignTokens.opacityHigh,
                ),
                borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: ReelConstants.recordingIndicatorWidth,
                    height: ReelConstants.recordingIndicatorHeight,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSM),
                  Text(
                    '${recordingDuration}s',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Bottom controls
        Positioned(
          bottom: DesignTokens.spaceXXL,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onLongPressStart: (_) => onStartRecording(),
                onLongPressEnd: (_) => onStopRecording(),
                child: Container(
                  width: ReelConstants.cameraButtonSize,
                  height: ReelConstants.cameraButtonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isRecording ? theme.colorScheme.error : Colors.white,
                      width: ReelConstants.cameraButtonBorderWidth,
                    ),
                    color: isRecording
                        ? theme.colorScheme.error.withValues(alpha: 
                            DesignTokens.opacityMedium,
                          )
                        : Colors.transparent,
                  ),
                  child: Icon(
                    Icons.videocam,
                    color: isRecording ? theme.colorScheme.error : Colors.white,
                    size: ReelConstants.cameraButtonIconSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
