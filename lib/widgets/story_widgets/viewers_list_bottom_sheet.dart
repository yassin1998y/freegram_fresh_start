// lib/widgets/story_widgets/viewers_list_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/story_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/common/app_bottom_sheet.dart';

class ViewersListBottomSheet extends StatelessWidget {
  final String storyId;
  final ScrollController? scrollController;

  const ViewersListBottomSheet({
    Key? key,
    required this.storyId,
    this.scrollController,
  }) : super(key: key);

  static Future<void> show(BuildContext context, String storyId) async {
    await AppBottomSheet.show(
      context: context,
      title: const Text('Viewers & Reactions'),
      showDragHandle: true,
      showCloseButton: false,
      isDraggable: false,
      fixedHeight: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.zero,
      isComplexLayout: true, // Use complex layout to handle ListView properly
      child: const SizedBox.shrink(), // Placeholder, childBuilder will be used
      childBuilder: (scrollController) => ViewersListBottomSheet(
        storyId: storyId,
        scrollController: scrollController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storyRepository = locator<StoryRepository>();
    final userRepository = locator<UserRepository>();

    // Note: This widget is now wrapped by AppBottomSheet.show()
    // So we just return the content without the container/header
    return FutureBuilder<Map<String, dynamic>>(
      future: Future.wait([
        storyRepository.getStoryViewers(storyId),
        storyRepository.getStoryReactions(storyId),
      ]).then((results) => {
            'viewers': results[0] as List<String>,
            'reactions': results[1] as Map<String, String>,
          }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: AppProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading data',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        final data = snapshot.data ?? {};
        final viewerIds = data['viewers'] as List<String>? ?? [];
        final reactions = data['reactions'] as Map<String, String>? ?? {};

        // Combine reactions and viewers, prioritizing reactions
        final Set<String> allUserIds = {};
        final Map<String, String> userReactions = {};

        // Add reactions first (they should appear at the top)
        for (final entry in reactions.entries) {
          allUserIds.add(entry.key);
          userReactions[entry.key] = entry.value;
        }

        // Add viewers (excluding those who already reacted)
        for (final viewerId in viewerIds) {
          if (!allUserIds.contains(viewerId)) {
            allUserIds.add(viewerId);
          }
        }

        if (allUserIds.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.remove_red_eye_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No viewers yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        // Sort: reactions first, then viewers
        final sortedUserIds = allUserIds.toList()
          ..sort((a, b) {
            final aHasReaction = userReactions.containsKey(a);
            final bHasReaction = userReactions.containsKey(b);
            if (aHasReaction && !bHasReaction) return -1;
            if (!aHasReaction && bHasReaction) return 1;
            return 0;
          });

        return ListView.builder(
          controller:
              scrollController, // Use the scroll controller from AppBottomSheet
          itemCount: sortedUserIds.length,
          itemBuilder: (context, index) {
            final userId = sortedUserIds[index];
            final reactionEmoji = userReactions[userId];

            return FutureBuilder(
              future: userRepository.getUser(userId),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      child: const AppProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    title: Text(
                      'Loading...',
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }

                if (userSnapshot.hasError || !userSnapshot.hasData) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.person,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    title: Text(
                      'Unknown user',
                      style: theme.textTheme.bodyMedium,
                    ),
                    trailing: reactionEmoji != null
                        ? Text(
                            reactionEmoji,
                            style: const TextStyle(fontSize: 24),
                          )
                        : null,
                  );
                }

                final user = userSnapshot.data!;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    backgroundImage: user.photoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl)
                        : null,
                    child: user.photoUrl.isEmpty
                        ? Icon(
                            Icons.person,
                            color: theme.colorScheme.onSurface,
                          )
                        : null,
                  ),
                  title: Text(
                    user.username,
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    reactionEmoji != null
                        ? 'Reacted with $reactionEmoji'
                        : 'Viewed',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: reactionEmoji != null
                      ? Text(
                          reactionEmoji,
                          style: const TextStyle(fontSize: 24),
                        )
                      : Icon(
                          Icons.remove_red_eye,
                          size: 20,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                );
              },
            );
          },
        );
      },
    );
  }
}
