// lib/screens/feed/for_you_feed_tab.dart
// Refactored: Lightweight view that delegates scroll logic to FeedScrollManager

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/blocs/unified_feed_bloc.dart';
import 'package:freegram/widgets/feed_widgets/post_card.dart';
import 'package:freegram/widgets/feed_widgets/ad_card.dart';
import 'package:freegram/widgets/feed_widgets/suggestion_carousel.dart';
import 'package:freegram/widgets/feed_widgets/stories_tray.dart';
import 'package:freegram/widgets/feed_widgets/create_post_widget.dart';
import 'package:freegram/widgets/feed_widgets/trending_post_card.dart';
import 'package:freegram/widgets/feed_widgets/trending_reels_carousel.dart';
import 'package:freegram/widgets/feed_widgets/boosted_posts_section.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/utils/enums.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/screens/feed/logic/feed_scroll_manager.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/skeletons/feed_loading_skeleton.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final GlobalKey<ForYouFeedTabState> kForYouFeedTabKey =
    GlobalKey<ForYouFeedTabState>();

class ForYouFeedTab extends StatefulWidget {
  final ValueChanged<bool>? onScrollDirectionChanged;
  final VoidCallback? onScrollToTop;

  const ForYouFeedTab({
    super.key,
    this.onScrollDirectionChanged,
    this.onScrollToTop,
  });

  @override
  State<ForYouFeedTab> createState() => ForYouFeedTabState();
}

class ForYouFeedTabState extends State<ForYouFeedTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final _auth = FirebaseAuth.instance;

  // Scroll manager handles all scroll logic
  late FeedScrollManager _scrollManager;

  // Cache user location
  GeoPoint? _cachedUserLocation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // Initialize scroll manager
    _scrollManager = FeedScrollManager(
      scrollController: _scrollController,
      onLoadMore: _loadMore,
      onScrollDown: () => widget.onScrollDirectionChanged?.call(true),
      onScrollUp: () => widget.onScrollDirectionChanged?.call(false),
    );

    // Load feed if not already loaded
    final userId = _auth.currentUser?.uid;
    if (userId != null && mounted) {
      final currentState = context.read<UnifiedFeedBloc>().state;
      if (currentState is! UnifiedFeedLoaded) {
        context.read<UnifiedFeedBloc>().add(
              LoadUnifiedFeedEvent(
                userId: userId,
                refresh: false,
                timeFilter: TimeFilter.allTime,
              ),
            );
      }
    }

    _fetchUserLocationOnce();
  }

  Future<void> _fetchUserLocationOnce() async {
    // Fetch user location once and cache it
    // Implementation can be added if needed
  }

  void _loadMore() {
    final userId = _auth.currentUser?.uid;
    if (userId != null && mounted) {
      context.read<UnifiedFeedBloc>().add(
            LoadMoreUnifiedFeedEvent(
              userId: userId,
              timeFilter: TimeFilter.allTime,
            ),
          );
    }
  }

  void scrollToTopAndRefresh() {
    widget.onScrollToTop?.call();
    _scrollManager.scrollToTop();

    final userId = _auth.currentUser?.uid;
    if (userId != null && mounted) {
      context.read<UnifiedFeedBloc>().add(
            LoadUnifiedFeedEvent(
              userId: userId,
              refresh: true,
              timeFilter: TimeFilter.allTime,
            ),
          );
    }
  }

  @override
  void dispose() {
    // CRITICAL: Dispose scroll manager to clean up listeners
    _scrollManager.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<UnifiedFeedBloc, UnifiedFeedState>(
      builder: (context, state) {
        if (state is UnifiedFeedLoading) {
          return const FeedLoadingSkeleton();
        }

        if (state is UnifiedFeedError) {
          return _buildErrorState(context, state.error);
        }

        if (state is UnifiedFeedLoaded) {
          if (state.items.isEmpty) {
            return _buildEmptyState(context);
          }

          return Stack(
            children: [
              // Offline banner
              BlocSelector<ConnectivityBloc, ConnectivityState, bool>(
                selector: (state) => state is Offline,
                builder: (context, isOffline) {
                  if (isOffline) {
                    return Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildOfflineBanner(context),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // New posts banner
              if (state.getNewPostsCount() > 0)
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: _buildNewPostsBanner(context, state),
                ),

              // Main feed list
              RefreshIndicator(
                onRefresh: () async {
                  final userId = _auth.currentUser?.uid;
                  if (userId != null) {
                    context.read<UnifiedFeedBloc>().add(
                          LoadUnifiedFeedEvent(
                            userId: userId,
                            refresh: true,
                            timeFilter: state.timeFilter,
                          ),
                        );
                    // Wait for state update
                    await Future.delayed(const Duration(milliseconds: 500));
                  }
                },
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _calculateItemCount(state),
                  addAutomaticKeepAlives: true, // Keep video state stable
                  addRepaintBoundaries: true,
                  cacheExtent: 500,
                  itemBuilder: (context, index) {
                    return RepaintBoundary(
                      child: _buildFeedItemAtIndex(context, state, index),
                    );
                  },
                ),
              ),

              // Scroll-to-top button
              ValueListenableBuilder<bool>(
                valueListenable: _scrollManager.showScrollToTopNotifier,
                builder: (context, showButton, _) {
                  if (!showButton) return const SizedBox.shrink();

                  final mediaQuery = MediaQuery.of(context);
                  final bottomNavBarHeight =
                      65.0 + mediaQuery.padding.bottom + DesignTokens.spaceSM;

                  return Positioned(
                    bottom: bottomNavBarHeight + DesignTokens.spaceMD,
                    right: DesignTokens.spaceMD,
                    child: FloatingActionButton(
                      onPressed: scrollToTopAndRefresh,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.arrow_upward),
                      tooltip: 'Scroll to top',
                    ),
                  );
                },
              ),
            ],
          );
        }

        return const Center(child: Text('Initializing feed...'));
      },
    );
  }

  int _calculateItemCount(UnifiedFeedLoaded state) {
    int count = 3; // Stories, Create Post, Trending Posts

    if (state.trendingReels.isNotEmpty) count++;
    if (state.boostedPosts.isNotEmpty) count++;
    if (state.friendSuggestions.isNotEmpty) count++;

    count += state.items.length;
    if (state.isLoading) count++;

    return count;
  }

  Widget _buildFeedItemAtIndex(
    BuildContext context,
    UnifiedFeedLoaded state,
    int index,
  ) {
    final hasTrendingReels = state.trendingReels.isNotEmpty;
    final hasBoostedPosts = state.boostedPosts.isNotEmpty;
    final hasFriendSuggestions = state.friendSuggestions.isNotEmpty;

    int currentIndex = 0;

    // 0: Stories Tray
    if (index == currentIndex++) {
      return Padding(
        padding: EdgeInsets.only(
          top: 60.0,
          bottom: DesignTokens.spaceXS,
        ),
        child: const StoriesTrayWidget(),
      );
    }

    // 1: Create Post Widget
    if (index == currentIndex++) {
      return const CreatePostWidget();
    }

    // 2: Trending Posts
    if (index == currentIndex++) {
      final hasTrendingPosts = _hasTrendingPosts(state);
      if (!hasTrendingPosts) {
        currentIndex--;
      } else {
        return _buildTrendingSection(state);
      }
    }

    // 3: Trending Reels
    if (index == currentIndex++) {
      if (hasTrendingReels) {
        return TrendingReelsCarouselWidget(reels: state.trendingReels);
      }
      currentIndex--;
    }

    // 4: Boosted Posts
    if (index == currentIndex++) {
      if (hasBoostedPosts) {
        return BoostedPostsSectionWidget(boostedPosts: state.boostedPosts);
      }
      currentIndex--;
    }

    // 5: Friends Suggestions
    if (index == currentIndex++) {
      if (hasFriendSuggestions) {
        return SuggestionCarouselWidget(
          type: SuggestionType.friends,
          suggestions: state.friendSuggestions,
          onDismiss: () {},
        );
      }
      currentIndex--;
    }

    // Regular feed items
    final feedItemIndex = index - currentIndex;
    if (feedItemIndex >= 0 && feedItemIndex < state.items.length) {
      final item = state.items[feedItemIndex];
      final isNewPost =
          item is PostFeedItem && state.getNewPostIds().contains(item.post.id);

      return _buildFeedItem(item, isNewPost: isNewPost);
    }

    // Loading indicator
    if (feedItemIndex == state.items.length && state.isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: DesignTokens.spaceMD),
        child: Column(
          children: [
            const AppProgressIndicator(),
            SizedBox(height: DesignTokens.spaceSM),
            Text(
              'Loading more posts...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(DesignTokens.opacityMedium),
                  ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFeedItem(FeedItem item, {bool isNewPost = false}) {
    Widget widget;

    if (item is PostFeedItem) {
      widget = Stack(
        children: [
          PostCard(
            item: item,
            loadMedia: true,
            userLocation: _cachedUserLocation,
          ),
          if (isNewPost)
            Positioned(
              top: DesignTokens.spaceSM,
              right: DesignTokens.spaceSM,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceXS,
                  vertical: DesignTokens.spaceXS / 2,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                ),
                child: Text(
                  'NEW',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: DesignTokens.fontSizeXS,
                      ),
                ),
              ),
            ),
        ],
      );
    } else if (item is AdFeedItem) {
      widget = AdCard(adCacheKey: item.cacheKey);
    } else if (item is SuggestionCarouselFeedItem) {
      widget = SuggestionCarouselWidget(
        type: item.type,
        suggestions: item.suggestions,
        onDismiss: () {},
      );
    } else {
      return const SizedBox.shrink();
    }

    return widget;
  }

  bool _hasTrendingPosts(UnifiedFeedLoaded state) {
    final trendingPosts = state.items
        .whereType<PostFeedItem>()
        .where((item) => item.displayType == PostDisplayType.trending)
        .take(8)
        .toList();

    if (trendingPosts.isNotEmpty) return true;

    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      final allPosts = state.items
          .whereType<PostFeedItem>()
          .where((item) => item.post.authorId != userId)
          .toList();
      return allPosts.isNotEmpty;
    }
    return false;
  }

  Widget _buildTrendingSection(UnifiedFeedLoaded state) {
    return BlocBuilder<UnifiedFeedBloc, UnifiedFeedState>(
      builder: (context, blocState) {
        List<PostFeedItem> trendingPosts = [];
        if (blocState is UnifiedFeedLoaded) {
          trendingPosts = blocState.items
              .whereType<PostFeedItem>()
              .where((item) => item.displayType == PostDisplayType.trending)
              .take(8)
              .toList();
        }

        if (trendingPosts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceMD,
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
                        color: Theme.of(context).colorScheme.error,
                      ),
                      SizedBox(width: DesignTokens.spaceSM),
                      Text(
                        'Trending Posts',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 160,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemBuilder: (context, i) {
                  return TrendingPostCard(item: trendingPosts[i]);
                },
                separatorBuilder: (_, __) =>
                    SizedBox(width: DesignTokens.spaceMD),
                itemCount: trendingPosts.length,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNewPostsBanner(BuildContext context, UnifiedFeedLoaded state) {
    final theme = Theme.of(context);
    final newPostsCount = state.getNewPostsCount();

    return SafeArea(
      bottom: false,
      child: Container(
        margin: EdgeInsets.all(DesignTokens.spaceSM),
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMD,
          vertical: DesignTokens.spaceSM,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(DesignTokens.spaceXS),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fiber_new,
                size: DesignTokens.iconSM,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            SizedBox(width: DesignTokens.spaceSM),
            Expanded(
              child: Text(
                '$newPostsCount ${newPostsCount == 1 ? 'new post' : 'new posts'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: theme.colorScheme.onPrimaryContainer,
              onPressed: () {
                final userId = _auth.currentUser?.uid;
                if (userId != null) {
                  context.read<UnifiedFeedBloc>().add(
                        LoadUnifiedFeedEvent(
                          userId: userId,
                          refresh: false,
                          timeFilter: state.timeFilter,
                        ),
                      );
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMD,
          vertical: DesignTokens.spaceSM,
        ),
        decoration: BoxDecoration(
          color: Colors.orange,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.wifi_off,
              color: Colors.white,
              size: DesignTokens.iconMD,
            ),
            SizedBox(width: DesignTokens.spaceSM),
            Expanded(
              child: Text(
                'You\'re offline. Showing cached content.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final theme = Theme.of(context);
    final isNetworkError = error.toLowerCase().contains('network') ||
        error.toLowerCase().contains('connection');

    return Center(
      child: Padding(
        padding: EdgeInsets.all(DesignTokens.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNetworkError ? Icons.wifi_off : Icons.error_outline,
              size: 64,
              color: isNetworkError ? Colors.orange : Colors.red,
            ),
            SizedBox(height: DesignTokens.spaceMD),
            Text(
              isNetworkError ? 'Connection Problem' : 'Something Went Wrong',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: DesignTokens.spaceSM),
            Text(
              isNetworkError
                  ? 'Unable to connect to the server. Please check your internet connection.'
                  : 'We encountered an error loading your feed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface
                    .withOpacity(DesignTokens.opacityMedium),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: DesignTokens.spaceXL),
            ElevatedButton.icon(
              onPressed: () {
                final userId = _auth.currentUser?.uid;
                if (userId != null) {
                  context.read<UnifiedFeedBloc>().add(
                        LoadUnifiedFeedEvent(
                          userId: userId,
                          refresh: true,
                          timeFilter: TimeFilter.allTime,
                        ),
                      );
                }
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceLG,
                  vertical: DesignTokens.spaceSM,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(DesignTokens.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.explore_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            SizedBox(height: DesignTokens.spaceXL),
            Text(
              'Your Feed is Empty',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: DesignTokens.spaceSM),
            Text(
              'Start following people and pages to see posts in your feed',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface
                    .withOpacity(DesignTokens.opacityMedium),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
