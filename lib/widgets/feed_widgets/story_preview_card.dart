// lib/widgets/feed_widgets/story_preview_card.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/models/story_media_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/utils/image_url_validator.dart';

class StoryPreviewCard extends StatelessWidget {
  final StoryMedia story;
  final String username;
  final String userAvatarUrl;
  final bool isUnread;
  final VoidCallback onTap;

  const StoryPreviewCard({
    Key? key,
    required this.story,
    required this.username,
    required this.userAvatarUrl,
    required this.isUnread,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewUrl = story.thumbnailUrl ?? story.mediaUrl;

    return Padding(
      padding: EdgeInsets.only(left: DesignTokens.spaceSM),
      child: SizedBox(
        width: 110,
        child: GestureDetector(
          onTap: onTap,
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background (Story Media)
                Container(
                  decoration: BoxDecoration(
                    image: ImageUrlValidator.isValidUrl(previewUrl)
                        ? DecorationImage(
                            fit: BoxFit.cover,
                            image: CachedNetworkImageProvider(previewUrl),
                          )
                        : null,
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: !ImageUrlValidator.isValidUrl(previewUrl)
                      ? Center(
                          child: Icon(
                            Icons.image,
                            size: DesignTokens.iconXL,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: DesignTokens.opacityMedium),
                          ),
                        )
                      : null,
                ),

                // Gradient Overlay (for text readability)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),

                // Avatar (Top-Left)
                Positioned(
                  top: DesignTokens.spaceSM,
                  left: DesignTokens.spaceSM,
                  child: Container(
                    padding: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          isUnread ? SonarPulseTheme.appLinearGradient : null,
                      border: !isUnread
                          ? Border.all(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                              width: 2,
                            )
                          : null,
                    ),
                    child: CircleAvatar(
                      radius: DesignTokens.iconMD,
                      backgroundColor: theme.colorScheme.surface,
                      backgroundImage:
                          ImageUrlValidator.isValidUrl(userAvatarUrl)
                              ? CachedNetworkImageProvider(userAvatarUrl)
                              : null,
                      child: !ImageUrlValidator.isValidUrl(userAvatarUrl)
                          ? Icon(
                              Icons.person,
                              size: DesignTokens.iconSM,
                              color: theme.colorScheme.onSurface.withValues(
                                  alpha: DesignTokens.opacityMedium),
                            )
                          : null,
                    ),
                  ),
                ),

                // Username (Bottom-Left)
                Positioned(
                  bottom: DesignTokens.spaceSM,
                  left: DesignTokens.spaceSM,
                  right: DesignTokens.spaceSM,
                  child: Text(
                    username,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
