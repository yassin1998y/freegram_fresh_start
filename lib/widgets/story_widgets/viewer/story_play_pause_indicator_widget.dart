// lib/widgets/story_widgets/viewer/story_play_pause_indicator_widget.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Play/pause indicator widget for story viewer
/// Shows pause icon when video is paused
class StoryPlayPauseIndicatorWidget extends StatelessWidget {
  final bool isPaused;
  final DateTime? pauseIndicatorHideTime;

  const StoryPlayPauseIndicatorWidget({
    Key? key,
    required this.isPaused,
    this.pauseIndicatorHideTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final shouldShow = isPaused &&
        (pauseIndicatorHideTime == null ||
            DateTime.now().difference(pauseIndicatorHideTime!) <
                const Duration(seconds: 3));

    final theme = Theme.of(context);

    return AnimatedOpacity(
      opacity: shouldShow ? DesignTokens.opacityFull : 0.0,
      duration: AnimationTokens.fast,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(DesignTokens.spaceLG),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface
                  .withValues(alpha: DesignTokens.opacityMedium),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.surface.withValues(alpha: 0.5),
                  blurRadius: DesignTokens.spaceLG,
                  spreadRadius: DesignTokens.spaceXS,
                ),
              ],
            ),
            child: Icon(
              Icons.pause,
              color: theme.colorScheme.onSurface,
              size: DesignTokens.iconXXL,
            ),
          ),
        ),
      ),
    );
  }
}
