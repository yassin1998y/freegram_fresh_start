// lib/widgets/story_widgets/creator/story_media_preview_widget.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Media preview widget for story creator
/// Displays image or video preview with proper error handling
class StoryMediaPreviewWidget extends StatelessWidget {
  final String mediaType; // 'image' or 'video'
  final File? mediaFile;
  final Uint8List? mediaBytes; // For web platform
  final VideoPlayerController? videoController;

  const StoryMediaPreviewWidget({
    Key? key,
    required this.mediaType,
    this.mediaFile,
    this.mediaBytes,
    this.videoController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (mediaType == 'image') {
      return _buildImagePreview(context);
    } else {
      return _buildVideoPreview(context);
    }
  }

  Widget _buildImagePreview(BuildContext context) {
    final theme = Theme.of(context);

    if (kIsWeb && mediaBytes != null) {
      return Image.memory(
        mediaBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                  size: DesignTokens.iconXXL,
                ),
                const SizedBox(height: DesignTokens.spaceMD),
                Text(
                  'Error loading image',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else if (!kIsWeb && mediaFile != null) {
      return Image.file(
        mediaFile!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                  size: DesignTokens.iconXXL,
                ),
                const SizedBox(height: DesignTokens.spaceMD),
                Text(
                  'Error loading image',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      return Center(
        child: AppProgressIndicator(
          color: theme.colorScheme.onSurface,
        ),
      );
    }
  }

  Widget _buildVideoPreview(BuildContext context) {
    final theme = Theme.of(context);

    if (videoController != null && videoController!.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: videoController!.value.size.width,
            height: videoController!.value.size.height,
            child: VideoPlayer(videoController!),
          ),
        ),
      );
    } else {
      return Center(
        child: AppProgressIndicator(
          color: theme.colorScheme.onSurface,
        ),
      );
    }
  }
}
