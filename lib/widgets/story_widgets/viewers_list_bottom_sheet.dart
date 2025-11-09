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
      title: const Text('Story Viewers'),
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
    return FutureBuilder<List<String>>(
      future: storyRepository.getStoryViewers(storyId),
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
                  'Error loading viewers',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        final viewerIds = snapshot.data ?? [];
        if (viewerIds.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.remove_red_eye_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No viewers yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: scrollController, // Use the scroll controller from AppBottomSheet
          itemCount: viewerIds.length,
          itemBuilder: (context, index) {
            final viewerId = viewerIds[index];
            return FutureBuilder(
              future: userRepository.getUser(viewerId),
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
                    '@${user.username}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
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
