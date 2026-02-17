import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:freegram/widgets/lqip_image.dart';

/// Video display widget for story viewer
/// Implements cross-fading between LQIP placeholder and live video
class StoryVideoDisplayWidget extends StatelessWidget {
  final VideoPlayerController? controller;
  final String? placeholderUrl;

  const StoryVideoDisplayWidget({
    Key? key,
    this.controller,
    this.placeholderUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background LQIP Blurred Layer (Instant Visual continuity)
        if (placeholderUrl != null)
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                LQIPImage(
                  imageUrl: placeholderUrl!,
                  fit: BoxFit.cover,
                ),
                ClipRRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Video Player with refined cross-fade
        if (controller != null)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller!,
            builder: (context, value, child) {
              final isInitialized = value.isInitialized;

              return AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isInitialized ? 1.0 : 0.0,
                curve: Curves.easeIn,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: isInitialized ? value.aspectRatio : 16 / 9,
                    child: VideoPlayer(controller!),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
