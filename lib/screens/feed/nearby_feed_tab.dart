// lib/screens/feed/nearby_feed_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_bloc.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_event.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_state.dart';
import 'package:freegram/widgets/reels/reels_player_widget.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/navigation/app_routes.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/services/media_prefetch_service.dart';

/// Reels Feed Tab - Displays vertical video feed
class NearbyFeedTab extends StatefulWidget {
  const NearbyFeedTab({Key? key}) : super(key: key);

  @override
  State<NearbyFeedTab> createState() => _NearbyFeedTabState();
}

class _NearbyFeedTabState extends State<NearbyFeedTab>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  late final MediaPrefetchService _prefetchService;
  
  // Phase 4.1: Track scroll velocity and timing for intelligent prefetching
  DateTime? _lastPageChangeTime;
  int? _lastPageIndex;
  double _scrollVelocity = 0.0;
  
  // Phase 4.1: Track if current video is playing
  bool _isCurrentVideoPlaying = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _prefetchService = locator<MediaPrefetchService>();
    // BLoC will be created and initialized in build method
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);

    return BlocProvider(
      create: (context) => ReelsFeedBloc(
        reelRepository: locator(),
      )..add(const LoadReelsFeed()),
      child: BlocListener<ReelsFeedBloc, ReelsFeedState>(
        listener: (context, state) {
          // Phase 4.1: Track pause state for intelligent prefetching
          if (state is ReelsFeedLoaded) {
            _isCurrentVideoPlaying = state.currentPlayingReelId != null;
          }
        },
        child: BlocBuilder<ReelsFeedBloc, ReelsFeedState>(
        builder: (context, state) {
          if (state is ReelsFeedLoading) {
            return Center(
              child: AppProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            );
          }

          if (state is ReelsFeedError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: DesignTokens.iconXXL,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: DesignTokens.spaceMD),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceLG,
                    ),
                    child: Text(
                      state.message,
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceLG),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ReelsFeedBloc>().add(const LoadReelsFeed());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is ReelsFeedLoaded) {
            if (state.reels.isEmpty) {
              return Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.video_library_outlined,
                          size: DesignTokens.iconXXL,
                          color: theme.colorScheme.onSurface.withOpacity(
                            DesignTokens.opacityMedium,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spaceMD),
                        Text(
                          'No reels available',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(
                              DesignTokens.opacityMedium,
                            ),
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spaceXL),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.createReel);
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Create Your First Reel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SonarPulseTheme.primaryAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceLG,
                              vertical: DesignTokens.spaceMD,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Floating action button
                  Positioned(
                    bottom: DesignTokens.spaceXL,
                    right: DesignTokens.spaceXL,
                    child: FloatingActionButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.createReel);
                      },
                      backgroundColor: SonarPulseTheme.primaryAccent,
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              );
            }

            return Stack(
              children: [
                // CRITICAL FIX: Use PageView.custom to limit cache extent and prevent memory leaks
                PageView.custom(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  childrenDelegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= state.reels.length) {
                        return Container(
                          color: theme.scaffoldBackgroundColor,
                          child: const Center(
                            child: AppProgressIndicator(),
                          ),
                        );
                      }
                      
                      final reel = state.reels[index];
                      final isCurrentReel = index == _currentIndex &&
                          state.currentPlayingReelId == reel.reelId;

                      return ReelsPlayerWidget(
                        reel: reel,
                        isCurrentReel: isCurrentReel,
                        prefetchService: _prefetchService,
                      );
                    },
                    childCount: state.reels.length,
                    // CRITICAL FIX: Don't keep off-screen pages alive - prevents memory leaks
                    addAutomaticKeepAlives: false,
                    // Add repaint boundaries for performance
                    addRepaintBoundaries: true,
                  ),
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);

                    final bloc = context.read<ReelsFeedBloc>();

                    // Phase 4.1: Calculate scroll velocity
                    final now = DateTime.now();
                    if (_lastPageChangeTime != null && _lastPageIndex != null) {
                      final timeDelta = now.difference(_lastPageChangeTime!).inMilliseconds;
                      final pageDelta = (index - _lastPageIndex!).abs();
                      
                      if (timeDelta > 0) {
                        // Calculate velocity in pages per second
                        _scrollVelocity = (pageDelta / timeDelta) * 1000;
                      } else {
                        _scrollVelocity = 0.0;
                      }
                    } else {
                      _scrollVelocity = 0.0;
                    }
                    
                    _lastPageChangeTime = now;
                    _lastPageIndex = index;

                    // Phase 1.2: Controller disposal is handled by widget's didUpdateWidget
                    // This ensures only visible reels (current ± 1) keep their controllers

                    // Pause previous video
                    if (index > 0 && index - 1 < state.reels.length) {
                      bloc.add(PauseReel(state.reels[index - 1].reelId));
                    }

                    // Play current video
                    if (index < state.reels.length) {
                      bloc.add(PlayReel(state.reels[index].reelId));
                      // Phase 4.1: Assume video starts playing when scrolled to
                      _isCurrentVideoPlaying = true;
                    }

                    // Phase 4.1: Intelligent prefetch with velocity and play state
                    _prefetchService.prefetchReelsVideos(
                      state.reels,
                      index,
                      isVideoPlaying: _isCurrentVideoPlaying,
                      scrollVelocity: _scrollVelocity,
                    );

                    // Load more if near the end
                    if (index >= state.reels.length - 3 && state.hasMore) {
                      bloc.add(const LoadMoreReels());
                    }
                  },
                ),
                // Floating action button for creating reels
                Positioned(
                  bottom: DesignTokens.spaceXL,
                  right: DesignTokens.spaceXL,
                  child: FloatingActionButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.createReel)
                          .then((result) {
                        // Refresh reels feed if a reel was successfully created
                        if (result == true) {
                          context.read<ReelsFeedBloc>().add(
                                const LoadReelsFeed(),
                              );
                        }
                      });
                    },
                    backgroundColor: SonarPulseTheme.primaryAccent,
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
        ),
      ),
    );
  }
}
