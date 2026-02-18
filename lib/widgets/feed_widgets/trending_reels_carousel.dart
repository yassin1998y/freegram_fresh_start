// lib/widgets/feed_widgets/trending_reels_carousel.dart
// Trending Reels Horizontal Carousel Widget

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/feed_widgets/create_reel_card.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/screens/reels_feed_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/services/user_stream_provider.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/navigation_service.dart';

class TrendingReelsCarouselWidget extends StatefulWidget {
  final List<ReelModel> reels;
  final VoidCallback? onTapReel;

  const TrendingReelsCarouselWidget({
    Key? key,
    required this.reels,
    this.onTapReel,
  }) : super(key: key);

  @override
  State<TrendingReelsCarouselWidget> createState() =>
      _TrendingReelsCarouselWidgetState();
}

class _TrendingReelsCarouselWidgetState
    extends State<TrendingReelsCarouselWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final theme = Theme.of(context);
    final navigationService = locator<NavigationService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 0.0,
            vertical: DesignTokens.spaceSM,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: DesignTokens.iconMD,
                    color: theme.colorScheme.primary,
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
              TextButton(
                onPressed: () {
                  navigationService.navigateTo(const ReelsFeedScreen());
                },
                child: Text(
                  'View More',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180, // Slightly taller for shadows
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.horizontal) {
                return true;
              }
              return false;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                0.0,
                4,
                0.0,
                16, // Bottom padding for shadows
              ),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.reels.length + 2, // +1 Create, +1 View All
              separatorBuilder: (_, __) =>
                  const SizedBox(width: DesignTokens.spaceMD),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  if (userId == null) return const CreateReelCard();
                  return StreamBuilder<UserModel>(
                    stream: UserStreamProvider().getUserStream(userId),
                    builder: (context, userSnapshot) {
                      final userPhotoUrl = userSnapshot.data?.photoUrl;
                      return CreateReelCard(photoUrl: userPhotoUrl);
                    },
                  );
                }

                if (index == widget.reels.length + 1) {
                  return _ViewMoreReelsCard(
                    onTap: () {
                      navigationService.navigateTo(const ReelsFeedScreen());
                    },
                  );
                }

                final reel = widget.reels[index - 1];
                return TrendingReelCard(
                  reel: reel,
                  onTap: widget.onTapReel ??
                      () {
                        navigationService.navigateTo(
                          ReelsFeedScreen(initialReelId: reel.reelId),
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
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140, // More portrait-like for Boutique aesthetic
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Container(
          decoration: Containers.glassCard(context).copyWith(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            border: Border.all(
              color: theme.colorScheme.primary, // 1px Brand Green
              width: 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: reel.thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: AppProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Icon(
                      Icons.videocam,
                      size: 32,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),

              // Gradient overlay at bottom
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
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),

              // Content overlay
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reel.uploaderUsername,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.play_arrow,
                          size: 10,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(reel.viewCount),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class _ViewMoreReelsCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ViewMoreReelsCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 160,
        decoration: Containers.glassCard(context).copyWith(
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'VIEW ALL',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
