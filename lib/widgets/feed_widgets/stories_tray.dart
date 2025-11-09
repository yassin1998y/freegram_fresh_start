// lib/widgets/feed_widgets/stories_tray.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/story_tray_data_model.dart';
import 'package:freegram/widgets/story_widgets/story_creator_type_screen.dart';
import 'package:freegram/widgets/story_widgets/feed/create_story_card.dart';
import 'package:freegram/widgets/story_widgets/feed/story_feed_card.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/story_repository.dart';
import 'package:freegram/screens/story_viewer_screen.dart';
import 'package:freegram/services/media_prefetch_service.dart';
import 'package:freegram/services/upload_progress_service.dart';
import 'package:freegram/theme/design_tokens.dart';

class StoriesTrayWidget extends StatelessWidget {
  const StoriesTrayWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get prefetch service for story thumbnails
    final prefetchService = locator<MediaPrefetchService>();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const SizedBox.shrink();
    }

    final storyRepository = locator<StoryRepository>();
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      height: 160,
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSM),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.horizontal) {
            return true;
          }
          return false;
        },
        child: ListenableBuilder(
          listenable: UploadProgressService(),
          builder: (context, _) {
            return StreamBuilder<StoryTrayData>(
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

            // 1. Add Create Story Card (always first) - now includes upload progress border
            storyWidgets.add(
              CreateStoryCard(
                user: currentUser,
                onTap: () {
                  StoryCreatorTypeScreen.show(context);
                },
              ),
            );

            // 2. Add My Story (always second, if it exists)
            if (storyData.myStory != null) {
              final myStory = storyData.myStory!;
              storyWidgets.add(
                StoryFeedCard(
                  story: myStory,
                  username: storyData.usernames[myStory.authorId] ?? 'You',
                  userAvatarUrl: storyData.userAvatars[myStory.authorId] ?? '',
                  isUnread: false, // Own stories are never unread
                  onTap: () => _openStory(context, myStory.authorId),
                ),
              );
            }

            // 3. Add Unread Friends' Stories
            final unreadStoriesList = storyData.unreadStories;
            for (final story in unreadStoriesList) {
              storyWidgets.add(
                StoryFeedCard(
                  story: story,
                  username: storyData.usernames[story.authorId] ?? 'Unknown',
                  userAvatarUrl: storyData.userAvatars[story.authorId] ?? '',
                  isUnread: true,
                  onTap: () => _openStory(context, story.authorId),
                ),
              );
            }

            // 4. Add Seen Friends' Stories
            final seenStoriesList = storyData.seenStories;
            for (final story in seenStoriesList) {
              storyWidgets.add(
                StoryFeedCard(
                  story: story,
                  username: storyData.usernames[story.authorId] ?? 'Unknown',
                  userAvatarUrl: storyData.userAvatars[story.authorId] ?? '',
                  isUnread: false,
                  onTap: () => _openStory(context, story.authorId),
                ),
              );
            }

            // Prefetch story thumbnails for better performance
            final allStories = [
              if (storyData.myStory != null) storyData.myStory!,
              ...unreadStoriesList,
              ...seenStoriesList,
            ];
                prefetchService.prefetchStoryThumbnails(allStories);

                // Build the horizontal ListView
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
                  itemCount: storyWidgets.length,
                  itemBuilder: (context, index) {
                    return storyWidgets[index];
                  },
                );
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
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
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
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
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
