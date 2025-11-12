// lib/widgets/feed_widgets/trending_reels_carousel.dart
// Trending Reels Horizontal Carousel Widget

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/feed_widgets/create_reel_card.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/screens/reels_feed_screen.dart';

class TrendingReelsCarouselWidget extends StatelessWidget {
  final List<ReelModel> reels;
  final VoidCallback? onTapReel;

  const TrendingReelsCarouselWidget({
    Key? key,
    required this.reels,
    this.onTapReel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Hide if no reels
    if (reels.isEmpty) {
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
                Icons.local_fire_department,
                size: DesignTokens.iconMD,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: DesignTokens.spaceSM),
              Text(
                'Trending Reels',
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
              // Consume horizontal scroll notifications to prevent TabBarView from switching
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
              itemCount: reels.length + 1, // +1 for Create Reel card
              separatorBuilder: (_, __) =>
                  const SizedBox(width: DesignTokens.spaceMD),
              itemBuilder: (context, index) {
                // First item is Create Reel card
                if (index == 0) {
                  return const CreateReelCard();
                }

                // Regular reel cards
                final reel = reels[index - 1];
                return TrendingReelCard(
                  reel: reel,
                  onTap: onTapReel ??
                      () {
                        // Navigate to reels feed with specific reel
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReelsFeedScreen(
                              initialReelId: reel.reelId,
                            ),
                          ),
                        );
                      },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Individual trending reel card
class TrendingReelCard extends StatelessWidget {
  final ReelModel reel;
  final VoidCallback? onTap;

  const TrendingReelCard({
    Key? key,
    required this.reel,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 220,
        height: 160,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail/Video
                CachedNetworkImage(
                  imageUrl: reel.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: AppProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(
                        Icons.videocam,
                        size: 40,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),

                // Gradient overlay at bottom for text
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content overlay (creator name, engagement)
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: SizedBox(
                    height: 52,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          reel.uploaderUsername,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 2,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.play_arrow,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatCount(reel.viewCount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                            if (reel.likeCount > 0) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.favorite,
                                size: DesignTokens.iconXS,
                                color: SonarPulseTheme.primaryAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatCount(reel.likeCount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 2,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Play button overlay (center)
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.play_circle_filled,
                      size: 48,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 4,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
