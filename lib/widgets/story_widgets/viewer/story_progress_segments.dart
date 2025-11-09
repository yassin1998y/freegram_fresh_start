// lib/widgets/story_widgets/viewer/story_progress_segments.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/models/story_media_model.dart';

/// Progress segments widget for story viewer
/// Shows progress bars for each story in the current user's reel
/// Uses theme colors and animations
class StoryProgressSegments extends StatefulWidget {
  final List<StoryMedia> stories;
  final int currentStoryIndex;
  final Map<String, double> progressMap;
  final bool isPaused;

  const StoryProgressSegments({
    Key? key,
    required this.stories,
    required this.currentStoryIndex,
    required this.progressMap,
    required this.isPaused,
  }) : super(key: key);

  @override
  State<StoryProgressSegments> createState() => _StoryProgressSegmentsState();
}

class _StoryProgressSegmentsState extends State<StoryProgressSegments>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const SizedBox.shrink();
    }

    final safeAreaTop = MediaQuery.of(context).padding.top;

    return Positioned(
      top: safeAreaTop + DesignTokens.spaceSM,
      left: DesignTokens.spaceSM,
      right: DesignTokens.spaceSM,
      child: Row(
        children: List.generate(widget.stories.length, (index) {
          final story = widget.stories[index];
          final progress = widget.progressMap[story.storyId] ?? 0.0;
          final isActive = index == widget.currentStoryIndex;

          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(
                right: index < widget.stories.length - 1 ? DesignTokens.spaceXS : 0,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Progress fill with smooth curved animation
                  if (isActive)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: progress.clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedProgress, child) {
                        return FractionallySizedBox(
                          widthFactor: animatedProgress,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: widget.isPaused
                                  ? LinearGradient(
                                      colors: [
                                        DesignTokens.warningColor,
                                        DesignTokens.warningColor.withValues(alpha: 0.8),
                                      ],
                                    )
                                  : LinearGradient(
                                      colors: [
                                        SonarPulseTheme.primaryAccent,
                                        SonarPulseTheme.primaryAccent.withValues(alpha: 0.9),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                              boxShadow: [
                                BoxShadow(
                                  color: (widget.isPaused
                                          ? DesignTokens.warningColor
                                          : SonarPulseTheme.primaryAccent)
                                      .withValues(alpha: widget.isPaused ? 0.6 : 0.4),
                                  blurRadius: widget.isPaused ? 6 : 4,
                                  spreadRadius: widget.isPaused ? 1.5 : 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  // Pulse glow effect for paused state
                  if (isActive && widget.isPaused)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: 0.3 + (_pulseController.value * 0.3),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    DesignTokens.warningColor.withValues(alpha: 0.6),
                                    Colors.transparent,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
