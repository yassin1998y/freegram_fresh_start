// lib/widgets/feed_widgets/stories_tray.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/models/story_tray_data_model.dart';
import 'package:freegram/widgets/feed_widgets/story_preview_card.dart';
import 'package:freegram/widgets/story_widgets/story_creator_type_screen.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/story_repository.dart';
import 'package:freegram/screens/story_viewer_screen.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/utils/image_url_validator.dart';

class StoriesTrayWidget extends StatelessWidget {
  const StoriesTrayWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const SizedBox.shrink();
    }

    final storyRepository = locator<StoryRepository>();
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      height: 160,
      padding: EdgeInsets.symmetric(vertical: DesignTokens.spaceSM),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.horizontal) {
            return true;
          }
          return false;
        },
        child: StreamBuilder<StoryTrayData>(
          stream: storyRepository.getStoryTrayDataStream(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingSkeleton(context);
            }

            if (snapshot.hasError) {
              debugPrint(
                  'StoriesTrayWidget: Error loading stories: ${snapshot.error}');
              return _buildErrorState(context);
            }

            final storyData = snapshot.data;
            if (storyData == null) {
              return _buildLoadingSkeleton(context);
            }

            // Build the list of widgets in the correct order
            final List<Widget> storyWidgets = [];

            // 1. Add Create Story Card (always first)
            storyWidgets.add(_CreateStoryCard(
              user: currentUser,
              onTap: () {
                StoryCreatorTypeScreen.show(context);
              },
            ));

            // 2. Add My Story (always second, if it exists)
            if (storyData.myStory != null) {
              final myStory = storyData.myStory!;
              storyWidgets.add(StoryPreviewCard(
                story: myStory,
                username: storyData.usernames[myStory.authorId] ?? 'You',
                userAvatarUrl: storyData.userAvatars[myStory.authorId] ?? '',
                isUnread: false, // Own stories are never unread
                onTap: () => _openStory(context, myStory.authorId),
              ));
            }

            // 3. Add Unread Friends' Stories
            for (final story in storyData.unreadStories) {
              storyWidgets.add(StoryPreviewCard(
                story: story,
                username: storyData.usernames[story.authorId] ?? 'Unknown',
                userAvatarUrl: storyData.userAvatars[story.authorId] ?? '',
                isUnread: true,
                onTap: () => _openStory(context, story.authorId),
              ));
            }

            // 4. Add Seen Friends' Stories
            for (final story in storyData.seenStories) {
              storyWidgets.add(StoryPreviewCard(
                story: story,
                username: storyData.usernames[story.authorId] ?? 'Unknown',
                userAvatarUrl: storyData.userAvatars[story.authorId] ?? '',
                isUnread: false,
                onTap: () => _openStory(context, story.authorId),
              ));
            }

            // Build the horizontal ListView
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
              itemCount: storyWidgets.length,
              itemBuilder: (context, index) {
                return storyWidgets[index];
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(DesignTokens.spaceMD),
        child: Text(
          'Unable to load stories',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface
                .withValues(alpha: DesignTokens.opacityMedium),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(
            left: index == 0 ? DesignTokens.spaceMD : DesignTokens.spaceSM,
          ),
          child: SizedBox(
            width: 110,
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openStory(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryViewerScreen(startingUserId: userId),
      ),
    );
  }
}

/// Create Story Card - Always first in the stories tray
class _CreateStoryCard extends StatelessWidget {
  final User? user;
  final VoidCallback onTap;

  const _CreateStoryCard({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profilePicUrl = user?.photoURL ?? '';

    return Padding(
      padding: EdgeInsets.only(left: DesignTokens.spaceMD),
      child: SizedBox(
        width: 110,
        child: Stack(
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
              child: Column(
                children: [
                  // Top Half (Image)
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: ImageUrlValidator.isValidUrl(profilePicUrl)
                          ? CachedNetworkImage(
                              imageUrl: profilePicUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  _buildPlaceholder(theme),
                              placeholder: (context, url) =>
                                  _buildPlaceholder(theme),
                            )
                          : _buildPlaceholder(theme),
                    ),
                  ),
                  // Bottom Half (Button)
                  Container(
                    height: 50,
                    color: theme.colorScheme.surface,
                    child: Center(
                      child: Text(
                        'Create a story',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Overlay Button (Positioned at the seam)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: onTap,
                  child: CircleAvatar(
                    radius: DesignTokens.iconLG,
                    backgroundColor: theme.colorScheme.primary,
                    child: Icon(
                      Icons.add,
                      color: theme.colorScheme.onPrimary,
                      size: DesignTokens.iconMD,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.person,
        size: DesignTokens.iconXL,
        color: theme.colorScheme.onSurface
            .withValues(alpha: DesignTokens.opacityMedium),
      ),
    );
  }
}
