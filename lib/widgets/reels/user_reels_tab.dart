// lib/widgets/reels/user_reels_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_bloc.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_event.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_state.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/repositories/reel_repository.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/lqip_image.dart';

/// Widget to display a specific user's reels in a grid
/// Used in ProfileScreen for viewing any user's reels
class UserReelsTab extends StatelessWidget {
  final String userId;

  const UserReelsTab({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (context) => ReelsFeedBloc(
        reelRepository: locator<ReelRepository>(),
        userRepository: locator(), // Support personalized feed
        usePersonalizedFeed: false, // Disable for user-specific reels
      )..add(LoadMyReels(userId)),
      child: BlocBuilder<ReelsFeedBloc, ReelsFeedState>(
        builder: (context, state) {
          if (state is ReelsFeedLoading) {
            return const Padding(
              padding: EdgeInsets.all(DesignTokens.spaceXL),
              child: Center(
                child: AppProgressIndicator(
                  color: SonarPulseTheme.primaryAccent,
                ),
              ),
            );
          }

          if (state is ReelsFeedError) {
            return Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceLG),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: DesignTokens.iconXXL,
                    ),
                    const SizedBox(height: DesignTokens.spaceMD),
                    Text(
                      state.message,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is ReelsFeedLoaded) {
            if (state.reels.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceXL),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.video_library_outlined,
                        color: theme.colorScheme.onSurface.withValues(alpha: 
                          DesignTokens.opacityMedium,
                        ),
                        size: DesignTokens.iconXXL * 1.6,
                      ),
                      const SizedBox(height: DesignTokens.spaceMD),
                      Text(
                        'No reels yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 
                            DesignTokens.opacityHigh,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: DesignTokens.spaceSM,
                mainAxisSpacing: DesignTokens.spaceSM,
                childAspectRatio: 9 / 16, // Vertical video aspect ratio
              ),
              itemCount: state.reels.length,
              itemBuilder: (context, index) {
                final reel = state.reels[index];
                return _ReelGridItem(reel: reel);
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ReelGridItem extends StatelessWidget {
  final ReelModel reel;

  const _ReelGridItem({required this.reel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        // Navigate to reel detail or play in full screen
        // TODO: Implement reel detail view
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
          color: Colors.grey[900],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail - Using LQIP for fast loading
            ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
              child: LQIPImage(
                imageUrl: reel.thumbnailUrl,
                fit: BoxFit.cover,
              ),
            ),
            // Overlay with view count
            Positioned(
              bottom: DesignTokens.spaceXS,
              left: DesignTokens.spaceXS,
              right: DesignTokens.spaceXS,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceXS,
                  vertical: DesignTokens.spaceXS / 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: DesignTokens.opacityHigh),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: DesignTokens.iconXS,
                    ),
                    const SizedBox(width: DesignTokens.spaceXS / 2),
                    Text(
                      _formatCount(reel.viewCount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontSize: DesignTokens.fontSizeXS,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
