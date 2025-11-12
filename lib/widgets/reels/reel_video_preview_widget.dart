// lib/widgets/reels/reel_video_preview_widget.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

/// Video preview widget for reels
/// Shows video preview with upload progress and caption input
class ReelVideoPreviewWidget extends StatelessWidget {
  final VideoPlayerController? videoController;
  final bool isUploading;
  final double uploadProgress;
  final Widget? captionInput;
  final Widget? uploadProgressOverlay;

  const ReelVideoPreviewWidget({
    Key? key,
    this.videoController,
    required this.isUploading,
    required this.uploadProgress,
    this.captionInput,
    this.uploadProgressOverlay,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video preview
        Positioned.fill(
          child: videoController != null && videoController!.value.isInitialized
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: videoController!.value.size.width,
                      height: videoController!.value.size.height,
                      child: VideoPlayer(videoController!),
                    ),
                  ),
                )
              : const Center(
                  child: AppProgressIndicator(color: Colors.white),
                ),
        ),
        // Upload progress overlay
        if (uploadProgressOverlay != null) uploadProgressOverlay!,
        // Caption input (bottom)
        if (captionInput != null && !isUploading) captionInput!,
      ],
    );
  }
}
