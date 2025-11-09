// lib/widgets/reels/my_reels_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_bloc.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_event.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_state.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/repositories/reel_repository.dart';
import 'package:freegram/locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/lqip_image.dart';

class MyReelsTab extends StatefulWidget {
  const MyReelsTab({Key? key}) : super(key: key);

  @override
  State<MyReelsTab> createState() => _MyReelsTabState();
}

class _MyReelsTabState extends State<MyReelsTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            'Please log in to view your reels',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return BlocProvider(
      create: (context) => ReelsFeedBloc(
        reelRepository: locator<ReelRepository>(),
      )..add(LoadMyReels(currentUser.uid)),
      child: BlocBuilder<ReelsFeedBloc, ReelsFeedState>(
        builder: (context, state) {
          if (state is ReelsFeedLoading) {
            return Container(
              color: Colors.black,
              child: const Center(
                child: AppProgressIndicator(
                  color: SonarPulseTheme.primaryAccent,
                ),
              ),
            );
          }

          if (state is ReelsFeedError) {
            return Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: DesignTokens.iconXXL,
                    ),
                    const SizedBox(height: DesignTokens.spaceMD),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spaceLG,
                      ),
                      child: Text(
                        state.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is ReelsFeedLoaded) {
            if (state.reels.isEmpty) {
              return Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.video_library_outlined,
                        color: Colors.white.withOpacity(DesignTokens.opacityMedium),
                        size: DesignTokens.iconXXL * 1.6,
                      ),
                      const SizedBox(height: DesignTokens.spaceMD),
                      Text(
                        'No reels yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white.withOpacity(DesignTokens.opacityHigh),
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceSM),
                      Text(
                        'Tap the + button to create your first reel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(DesignTokens.opacityMedium),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
              color: Colors.black,
              child: GridView.builder(
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
              ),
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
                  color: Colors.black.withOpacity(DesignTokens.opacityHigh),
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

