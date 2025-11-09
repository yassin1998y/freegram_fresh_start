// lib/screens/reels_feed_screen.dart
// Facebook Reels-style full-screen video feed

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_bloc.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_event.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_state.dart';
import 'package:freegram/widgets/reels/reels_player_widget.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/navigation/app_routes.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/services/media_prefetch_service.dart';
import 'package:freegram/services/reel_upload_service.dart';
import 'package:freegram/services/reels_feed_state_service.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class ReelsFeedScreen extends StatefulWidget {
  const ReelsFeedScreen({Key? key}) : super(key: key);

  @override
  State<ReelsFeedScreen> createState() => _ReelsFeedScreenState();
}

class _ReelsFeedScreenState extends State<ReelsFeedScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  late MediaPrefetchService _prefetchService;
  final ReelUploadService _uploadService = ReelUploadService();
  final ReelsFeedStateService _stateService = ReelsFeedStateService();
  bool _hasInitialized = false;
  
  // Phase 4.1: Track scroll velocity and timing for intelligent prefetching
  DateTime? _lastPageChangeTime;
  int? _lastPageIndex;
  double _scrollVelocity = 0.0;
  
  // Phase 4.1: Track if current video is playing
  bool _isCurrentVideoPlaying = true;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: reels_feed_screen.dart');
    // Get the MediaPrefetchService from locator
    _prefetchService = locator<MediaPrefetchService>();
    // Listen to upload progress changes
    _uploadService.addListener(_onUploadProgressChanged);
    
    // Restore scroll position if available
    final savedIndex = _stateService.getSavedScrollPosition();
    if (savedIndex != null && savedIndex > 0) {
      _currentIndex = savedIndex;
      // Initialize PageController with saved index
      _pageController = PageController(initialPage: savedIndex);
    } else {
      _pageController = PageController();
    }
  }

  void _onUploadProgressChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    // Save scroll position before disposing
    _stateService.saveScrollPosition(_currentIndex);
    _uploadService.removeListener(_onUploadProgressChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // PopScope handles device back button automatically
        // No action needed - just let it pop
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: true, // Allow keyboard to resize
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: DesignTokens.iconLG,
                ),
                onPressed: () {
                  // Manual back button - just pop normally
                  Navigator.of(context).pop();
                },
              ),
              // Upload progress indicator next to back button
              if (_uploadService.isUploading)
                Padding(
                  padding: const EdgeInsets.only(left: DesignTokens.spaceXS),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceSM,
                      vertical: DesignTokens.spaceXS,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusSM),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppProgressIndicator(
                          size: 12,
                          value: _uploadService.uploadProgress,
                          strokeWidth: 2,
                          color: SonarPulseTheme.primaryAccent,
                          backgroundColor: Colors.white24,
                        ),
                        const SizedBox(width: DesignTokens.spaceXS),
                        Text(
                          '${(_uploadService.uploadProgress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: DesignTokens.fontSizeXS,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          title: const Text(
            'Reels',
            style: TextStyle(
              color: Colors.white,
              fontSize: DesignTokens.fontSizeLG,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            // Create Reel button
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: Colors.white,
                size: DesignTokens.iconLG,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, AppRoutes.createReel);
              },
              tooltip: 'Create Reel',
              padding: const EdgeInsets.all(DesignTokens.spaceSM),
              constraints: const BoxConstraints(
                minWidth: DesignTokens.buttonHeight,
                minHeight: DesignTokens.buttonHeight,
              ),
            ),
            const SizedBox(width: DesignTokens.spaceXS),
          ],
        ),
        body: BlocProvider(
          create: (context) {
            final bloc = ReelsFeedBloc(
              reelRepository: locator(),
            );
            // Only load if not already loaded (check state service or load fresh)
            // For now, always load - the BLoC will handle caching
            bloc.add(const LoadReelsFeed());
            return bloc;
          },
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
                return const Center(
                  child: AppProgressIndicator(),
                );
              }

              if (state is ReelsFeedError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: DesignTokens.iconXXL,
                        color: Colors.white,
                      ),
                      const SizedBox(height: DesignTokens.spaceMD),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spaceLG,
                        ),
                        child: Text(
                          state.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: DesignTokens.fontSizeMD,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceLG),
                      ElevatedButton(
                        onPressed: () {
                          context
                              .read<ReelsFeedBloc>()
                              .add(const LoadReelsFeed());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SonarPulseTheme.primaryAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (state is ReelsFeedLoaded) {
                // Restore scroll position after feed loads if we have a saved position
                if (!_hasInitialized && state.reels.isNotEmpty) {
                  final savedIndex = _stateService.getSavedScrollPosition();
                  if (savedIndex != null && savedIndex < state.reels.length) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _pageController.hasClients) {
                        _pageController.jumpToPage(savedIndex);
                        _currentIndex = savedIndex;
                        // Play the restored reel
                        context.read<ReelsFeedBloc>().add(
                          PlayReel(state.reels[savedIndex].reelId),
                        );
                      }
                    });
                  }
                  _hasInitialized = true;
                }
                
                if (state.reels.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.video_library_outlined,
                          size: DesignTokens.iconXXL,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        const SizedBox(height: DesignTokens.spaceMD),
                        Text(
                          'No reels available',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: DesignTokens.fontSizeMD,
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
                  );
                }

                // Phase 4.1: Prefetch the first few reels when loaded (only if playing)
                if (state.reels.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _prefetchService.prefetchReelsVideos(
                      state.reels,
                      _currentIndex,
                      isVideoPlaying: _isCurrentVideoPlaying,
                      scrollVelocity: _scrollVelocity,
                    );
                  });
                }

                // CRITICAL FIX: Use PageView.custom to limit cache extent
                // Note: PageView doesn't have cacheExtent parameter, but we control caching
                // through addAutomaticKeepAlives: false and proper widget disposal
                return PageView.custom(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  // CRITICAL FIX: Add physics to prevent overscroll which can cause memory issues
                  physics: const ClampingScrollPhysics(),
                  childrenDelegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Show loading indicator at the end when loading more
                      if (index >= state.reels.length) {
                        return Container(
                          color: Colors.black,
                          child: const Center(
                            child: AppProgressIndicator(),
                          ),
                        );
                      }

                      final reel = state.reels[index];
                      final isCurrentReel = index == _currentIndex &&
                          state.currentPlayingReelId == reel.reelId;
                      
                      // Phase 4.1: Update play state when current reel changes
                      if (isCurrentReel && index == _currentIndex) {
                        _isCurrentVideoPlaying = state.currentPlayingReelId == reel.reelId;
                      }

                      // CRITICAL FIX: Wrap each reel in RepaintBoundary with unique key
                      // Using reelId + index to ensure proper widget recycling
                      return RepaintBoundary(
                        key: ValueKey('reel_${reel.reelId}_$index'),
                        child: ReelsPlayerWidget(
                          key: ValueKey('reels_player_${reel.reelId}_$index'),
                          reel: reel,
                          isCurrentReel: isCurrentReel,
                          prefetchService: _prefetchService,
                        ),
                      );
                    },
                    childCount: state.reels.length + (state.isLoadingMore ? 1 : 0),
                    // CRITICAL FIX: Limit cache to only current page (no automatic keep-alives)
                    addAutomaticKeepAlives: false, // Don't keep off-screen pages alive
                    addRepaintBoundaries: false, // We're adding RepaintBoundary manually for better control
                  ),
                  onPageChanged: (index) {
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

                    // Update current index
                    setState(() => _currentIndex = index);

                    // Phase 4.1: Intelligent prefetch with velocity and play state
                    _prefetchService.prefetchReelsVideos(
                      state.reels,
                      index,
                      isVideoPlaying: _isCurrentVideoPlaying,
                      scrollVelocity: _scrollVelocity,
                    );

                    // Load more if near the end
                    if (index >= state.reels.length - 3 &&
                        state.hasMore &&
                        !state.isLoadingMore) {
                      bloc.add(const LoadMoreReels());
                    }
                  },
                );
              }

              return Container(
                color: Colors.black,
                child: const SizedBox.shrink(),
              );
            },
            ),
          ),
        ),
      ),
    );
  }
}
