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
import 'package:freegram/services/user_stream_provider.dart';
import 'package:freegram/models/user_model.dart';

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
                debugPrint(
                    'StoriesTrayWidget: Connection state: ${snapshot.connectionState}');
                debugPrint('StoriesTrayWidget: Has data: ${snapshot.hasData}');
                debugPrint(
                    'StoriesTrayWidget: Has error: ${snapshot.hasError}');

                // Show error state if there's an error
                if (snapshot.hasError) {
                  debugPrint(
                      'StoriesTrayWidget: Error loading stories: ${snapshot.error}');
                  debugPrint(
                      'StoriesTrayWidget: Error stack: ${snapshot.error is Error ? (snapshot.error as Error).stackTrace : "No stack trace"}');
                  // Even on error, show at least Create Story card
                  return _buildEmptyState(context, userId);
                }

                // Show loading skeleton only briefly while waiting for initial data
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  // After 2 seconds, show empty state instead of infinite loading
                  return _buildLoadingSkeleton(context);
                }

                // If we have data, use it (even if connection is still active)
                final storyData = snapshot.data;
                if (storyData == null) {
                  // If no data after waiting, show empty state (at least Create Story card)
                  debugPrint(
                      'StoriesTrayWidget: No story data available - showing empty state');
                  return _buildEmptyState(context, userId);
                }

                debugPrint(
                    'StoriesTrayWidget: Story data - My story: ${storyData.myStory != null}, Unread: ${storyData.unreadStories.length}, Seen: ${storyData.seenStories.length}');

                // Build the list of widgets in the correct order
                final List<Widget> storyWidgets = [];

                // 1. Add Create Story Card (always first) - now includes upload progress border
                storyWidgets.add(
                  StreamBuilder<UserModel>(
                    stream: UserStreamProvider().getUserStream(userId),
                    builder: (context, userSnapshot) {
                      final userPhotoUrl = userSnapshot.data?.photoUrl;
                      return CreateStoryCard(
                        photoUrl: userPhotoUrl,
                        onTap: () {
                          StoryCreatorTypeScreen.show(context);
                        },
                      );
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
                      userAvatarUrl:
                          storyData.userAvatars[myStory.authorId] ?? '',
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
                      username:
                          storyData.usernames[story.authorId] ?? 'Unknown',
                      userAvatarUrl:
                          storyData.userAvatars[story.authorId] ?? '',
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
                      username:
                          storyData.usernames[story.authorId] ?? 'Unknown',
                      userAvatarUrl:
                          storyData.userAvatars[story.authorId] ?? '',
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceMD),
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

  /// Build empty state (only Create Story card)
  Widget _buildEmptyState(BuildContext context, String userId) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
      itemCount: 1,
      itemBuilder: (context, index) {
        return StreamBuilder<UserModel>(
          stream: UserStreamProvider().getUserStream(userId),
          builder: (context, userSnapshot) {
            final userPhotoUrl = userSnapshot.data?.photoUrl;
            return CreateStoryCard(
              photoUrl: userPhotoUrl,
              onTap: () {
                StoryCreatorTypeScreen.show(context);
              },
            );
          },
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
