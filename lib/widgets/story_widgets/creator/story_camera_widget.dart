// lib/widgets/story_widgets/creator/story_camera_widget.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Camera widget for story creator
/// Handles camera preview, controls, and capture buttons
class StoryCameraWidget extends StatelessWidget {
  final CameraController controller;
  final List<CameraDescription> cameras;
  final bool isRecordingVideo;
  final VoidCallback onClose;
  final VoidCallback? onSwitchCamera;
  final VoidCallback onTakePicture;
  final VoidCallback onStartVideoRecording;
  final VoidCallback onStopVideoRecording;

  const StoryCameraWidget({
    Key? key,
    required this.controller,
    required this.cameras,
    required this.isRecordingVideo,
    required this.onClose,
    this.onSwitchCamera,
    required this.onTakePicture,
    required this.onStartVideoRecording,
    required this.onStopVideoRecording,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSwitchCamera = cameras.length > 1;

    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: CameraPreview(controller),
        ),

        // Top controls (close, camera switch)
        Positioned(
          top: MediaQuery.of(context).padding.top + DesignTokens.spaceMD,
          left: DesignTokens.spaceMD,
          right: DesignTokens.spaceMD,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: theme.colorScheme.onSurface,
                  size: DesignTokens.iconLG,
                ),
                onPressed: onClose,
              ),
              if (canSwitchCamera && onSwitchCamera != null)
                IconButton(
                  icon: Icon(
                    Icons.flip_camera_ios,
                    color: theme.colorScheme.onSurface,
                    size: DesignTokens.iconLG,
                  ),
                  onPressed: onSwitchCamera,
                ),
            ],
          ),
        ),

        // Bottom controls (capture buttons)
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + DesignTokens.spaceXL,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Photo capture button
              _CaptureButton(
                icon: Icons.camera,
                onTap: onTakePicture,
                size: DesignTokens.spaceXXXL - DesignTokens.spaceXS * 2,
              ),
              SizedBox(width: DesignTokens.spaceXL),
              // Video record button (long press)
              _VideoRecordButton(
                isRecording: isRecordingVideo,
                onLongPressStart: onStartVideoRecording,
                onLongPressEnd: onStopVideoRecording,
                size: DesignTokens.spaceXXXL - DesignTokens.spaceXS * 2,
              ),
            ],
          ),
        ),

        // Recording indicator
        if (isRecordingVideo)
          Positioned(
            top: MediaQuery.of(context).padding.top +
                DesignTokens.spaceXL * 2 +
                DesignTokens.iconLG,
            left: 0,
            right: 0,
            child: _RecordingIndicator(theme: theme),
          ),
      ],
    );
  }
}

/// Photo capture button
class _CaptureButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _CaptureButton({
    required this.icon,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.onSurface,
            width: DesignTokens.elevation1,
          ),
          color: Colors.transparent,
        ),
        child: Icon(
          icon,
          color: theme.colorScheme.onSurface,
          size: DesignTokens.iconXL,
        ),
      ),
    );
  }
}

/// Video record button with long press support
class _VideoRecordButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;
  final double size;

  const _VideoRecordButton({
    required this.isRecording,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recordingColor = theme.colorScheme.error;

    return GestureDetector(
      onLongPressStart: (_) => onLongPressStart(),
      onLongPressEnd: (_) => onLongPressEnd(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isRecording ? recordingColor : theme.colorScheme.onSurface,
            width: DesignTokens.elevation1,
          ),
          color: isRecording
              ? recordingColor.withOpacity(DesignTokens.opacityMedium)
              : Colors.transparent,
        ),
        child: Icon(
          Icons.videocam,
          color: isRecording ? recordingColor : theme.colorScheme.onSurface,
          size: DesignTokens.iconXL,
        ),
      ),
    );
  }
}

/// Recording indicator
class _RecordingIndicator extends StatelessWidget {
  final ThemeData theme;

  const _RecordingIndicator({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: DesignTokens.spaceSM,
          horizontal: DesignTokens.spaceMD,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withOpacity(DesignTokens.opacityHigh),
          borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
        ),
        child: Text(
          'Recording...',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onError,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
