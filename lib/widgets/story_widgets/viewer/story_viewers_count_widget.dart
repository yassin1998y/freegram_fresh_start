// lib/widgets/story_widgets/viewer/story_viewers_count_widget.dart

import 'package:flutter/material.dart';
import 'package:freegram/models/story_media_model.dart';
import 'package:freegram/widgets/story_widgets/viewers_list_bottom_sheet.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

/// Viewers count widget for story viewer
/// Shows reaction count and viewer count for story owners
class StoryViewersCountWidget extends StatelessWidget {
  final StoryMedia story;
  final int reactionCount;

  const StoryViewersCountWidget({
    Key? key,
    required this.story,
    required this.reactionCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewerCount = story.viewerCount;

    return Positioned(
      bottom: DesignTokens.spaceXXXL - DesignTokens.spaceMD,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () {
            ViewersListBottomSheet.show(context, story.storyId);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMD,
              vertical: DesignTokens.spaceSM,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface
                  .withOpacity(DesignTokens.opacityMedium),
              borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                width: DesignTokens.elevation1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (reactionCount > 0) ...[
                  const Icon(
                    Icons.favorite,
                    color: SonarPulseTheme.primaryAccent,
                    size: DesignTokens.iconSM,
                  ),
                  const SizedBox(width: DesignTokens.spaceXS),
                  Text(
                    '$reactionCount',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSM),
                ],
                Icon(
                  Icons.remove_red_eye,
                  color: theme.colorScheme.onSurface,
                  size: DesignTokens.iconSM,
                ),
                const SizedBox(width: DesignTokens.spaceXS),
                Text(
                  '$viewerCount',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
