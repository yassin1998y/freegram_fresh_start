// lib/widgets/story_widgets/viewer/story_user_header.dart

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/blocs/story_viewer_cubit.dart';
import 'package:freegram/utils/image_url_validator.dart';
import 'package:freegram/models/story_media_model.dart';

/// User header for story viewer with glassmorphic design
/// Shows progress segments, avatar, username, timestamp, and action buttons
class StoryUserHeader extends StatelessWidget {
  final StoryUser? user;
  final DateTime? timestamp;
  final VoidCallback? onOptionsPressed;
  final VoidCallback? onClosePressed;
  final List<StoryMedia> stories;
  final int currentStoryIndex;
  final Map<String, double> progressMap;
  final bool isPaused;

  const StoryUserHeader({
    Key? key,
    this.user,
    this.timestamp,
    this.onOptionsPressed,
    this.onClosePressed,
    required this.stories,
    required this.currentStoryIndex,
    required this.progressMap,
    required this.isPaused,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final safeAreaTop = MediaQuery.of(context).padding.top;

    return Positioned(
      top: safeAreaTop + DesignTokens.spaceSM,
      left: DesignTokens.spaceMD,
      right: DesignTokens.spaceMD,
      child: AnimatedSwitcher(
        duration: AnimationTokens.normal,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        child: ClipRRect(
          key: ValueKey(user!.userId),
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: DesignTokens.blurMedium,
              sigmaY: DesignTokens.blurMedium,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity( 0.3),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                border: Border.all(
                  color: Colors.white.withOpacity( 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress segments at the top
                  if (stories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DesignTokens.spaceMD,
                        DesignTokens.spaceSM,
                        DesignTokens.spaceMD,
                        DesignTokens.spaceXS,
                      ),
                      child: _buildProgressSegments(),
                    ),
                  // User info row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceMD,
                      vertical: DesignTokens.spaceSM,
                    ),
                    child: Row(
                      children: [
                        // Avatar with border
                        Container(
                          padding: const EdgeInsets.all(2.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity( 0.3),
                              width: 2.0,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: DesignTokens.avatarSize / 2,
                            backgroundColor: theme.colorScheme.surface,
                            backgroundImage: ImageUrlValidator.isValidUrl(
                                    user!.userAvatarUrl)
                                ? CachedNetworkImageProvider(
                                    user!.userAvatarUrl)
                                : null,
                            child: !ImageUrlValidator.isValidUrl(
                                    user!.userAvatarUrl)
                                ? Icon(
                                    Icons.person,
                                    size: DesignTokens.iconMD,
                                    color: Colors.white.withOpacity( 0.8),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceSM),
                        // Username and timestamp
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user!.username,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: DesignTokens.fontSizeLG,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (timestamp != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _formatTimestamp(timestamp!),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withOpacity( 0.7),
                                    fontSize: DesignTokens.fontSizeXS,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Options button
                        if (onOptionsPressed != null)
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: DesignTokens.iconMD,
                            ),
                            onPressed: onOptionsPressed,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                          ),
                        // Close button
                        if (onClosePressed != null)
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: DesignTokens.iconMD,
                            ),
                            onPressed: onClosePressed,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSegments() {
    return Row(
      children: List.generate(stories.length, (index) {
        final story = stories[index];
        final progress = progressMap[story.storyId] ?? 0.0;
        final isActive = index == currentStoryIndex;

        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(
              right: index < stories.length - 1 ? DesignTokens.spaceXS : 0,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity( 0.3),
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
                            gradient: isPaused
                                ? LinearGradient(
                                    colors: [
                                      SemanticColors.warning,
                                      SemanticColors.warning
                                          .withOpacity( 0.8),
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity( 0.9),
                                    ],
                                  ),
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusXS),
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
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
