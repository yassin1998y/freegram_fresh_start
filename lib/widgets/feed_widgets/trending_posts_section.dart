// lib/widgets/feed_widgets/trending_posts_section.dart
// Trending Posts Horizontal Carousel Widget

import 'package:flutter/material.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/feed_widgets/trending_post_card.dart';

class TrendingPostsSectionWidget extends StatelessWidget {
  final List<PostFeedItem> trendingPosts;

  const TrendingPostsSectionWidget({
    Key? key,
    required this.trendingPosts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Hide if no trending posts
    if (trendingPosts.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

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
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: DesignTokens.spaceSM),
              Text(
                'Trending Posts',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.horizontal) {
                return true;
              }
              return false;
            },
            child: ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: trendingPosts.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: DesignTokens.spaceMD),
              itemBuilder: (context, index) {
                return TrendingPostCard(
                  item: trendingPosts[index],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.spaceSM),
      ],
    );
  }
}
