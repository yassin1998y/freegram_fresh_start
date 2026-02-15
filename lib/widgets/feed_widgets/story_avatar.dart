// lib/widgets/feed_widgets/story_avatar.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/models/story_tray_item_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

class StoryAvatarWidget extends StatelessWidget {
  final StoryTrayItem storyItem;
  final VoidCallback onTap;

  const StoryAvatarWidget({
    Key? key,
    required this.storyItem,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceXS),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Clean gradient ring for unread stories (using app theme gradient)
                  if (storyItem.hasUnreadStory)
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SonarPulseTheme.appLinearGradient,
                      ),
                    ),
                  // Border container
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: storyItem.hasUnreadStory
                            ? Colors.transparent
                            : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      backgroundColor: theme.colorScheme.surface,
                      backgroundImage: (storyItem.userAvatarUrl.isNotEmpty &&
                              storyItem.userAvatarUrl.trim().isNotEmpty &&
                              (storyItem.userAvatarUrl.startsWith('http://') ||
                                  storyItem.userAvatarUrl
                                      .startsWith('https://')))
                          ? CachedNetworkImageProvider(storyItem.userAvatarUrl)
                          : null,
                      child: (storyItem.userAvatarUrl.isEmpty ||
                              storyItem.userAvatarUrl.trim().isEmpty ||
                              !(storyItem.userAvatarUrl.startsWith('http://') ||
                                  storyItem.userAvatarUrl
                                      .startsWith('https://')))
                          ? Icon(
                              Icons.person,
                              color:
                                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spaceXS / 2 + 1),
            Text(
              storyItem.username,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
