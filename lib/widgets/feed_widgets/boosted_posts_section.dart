// lib/widgets/feed_widgets/boosted_posts_section.dart
// Boosted Posts Section Widget - Shows up to 3 boosted/sponsored posts

import 'package:flutter/material.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/widgets/feed_widgets/post_card.dart';
import 'package:freegram/theme/design_tokens.dart';

class BoostedPostsSectionWidget extends StatelessWidget {
  final List<PostFeedItem> boostedPosts;
  final VoidCallback? onDismissPost;

  const BoostedPostsSectionWidget({
    Key? key,
    required this.boostedPosts,
    this.onDismissPost,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Hide if no boosted posts
    if (boostedPosts.isEmpty) {
      return const SizedBox.shrink();
    }

    // Limit to 3 posts
    final postsToShow = boostedPosts.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMD,
            vertical: DesignTokens.spaceSM,
          ),
          child: Row(
            children: [
              Icon(
                Icons.trending_up,
                size: DesignTokens.iconMD,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: DesignTokens.spaceSM),
              Text(
                'Sponsored',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
        ...postsToShow.map((postItem) {
          // Wrap PostCard to add boosted badge
          return PostCard(
            item: PostFeedItem(
              post: postItem.post,
              displayType: PostDisplayType.boosted,
            ),
            loadMedia: true,
          );
        }),
        const SizedBox(height: DesignTokens.spaceMD),
      ],
    );
  }
}

