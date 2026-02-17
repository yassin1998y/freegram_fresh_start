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
              height: 1, // 1px Progress Segments requirement
              margin: EdgeInsets.only(
                right: index < widget.stories.length - 1
                    ? DesignTokens.spaceXS
                    : 0,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15), // Subtle inactive
                borderRadius: BorderRadius.circular(1),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Completed segments
                  if (index < widget.currentStoryIndex)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: SonarPulseTheme.primaryAccent,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  // Progress fill for active segment
                  if (isActive)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: progress.clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.linear,
                      builder: (context, animatedProgress, child) {
                        return FractionallySizedBox(
                          widthFactor: animatedProgress,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.isPaused
                                  ? SemanticColors.warning
                                  : SonarPulseTheme.primaryAccent,
                              borderRadius: BorderRadius.circular(1),
                              boxShadow: [
                                if (!widget.isPaused)
                                  BoxShadow(
                                    color: SonarPulseTheme.primaryAccent
                                        .withValues(alpha: 0.5),
                                    blurRadius: 2,
                                    spreadRadius: 0.5,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
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
