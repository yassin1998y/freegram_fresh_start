// lib/widgets/story_widgets/viewer/story_video_display_widget.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

/// Video display widget for story viewer
/// Simple widget that displays a video player controller
/// Controller management remains in parent screen
class StoryVideoDisplayWidget extends StatelessWidget {
  final VideoPlayerController? controller;

  const StoryVideoDisplayWidget({
    Key? key,
    this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return Center(
        child: AppProgressIndicator(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }

    return RepaintBoundary(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller!.value.size.width,
            height: controller!.value.size.height,
            child: VideoPlayer(controller!),
          ),
        ),
      ),
    );
  }
}
