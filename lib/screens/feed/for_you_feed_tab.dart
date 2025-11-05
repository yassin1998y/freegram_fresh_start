// lib/screens/feed/for_you_feed_tab.dart

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
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/utils/enums.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/services/feed_scoring_service.dart';

final GlobalKey<ForYouFeedTabState> kForYouFeedTabKey =
    GlobalKey<ForYouFeedTabState>();

class ForYouFeedTab extends StatefulWidget {
  const ForYouFeedTab({Key? key}) : super(key: key);

  @override
  ForYouFeedTabState createState() => ForYouFeedTabState();
}

class ForYouFeedTabState extends State<ForYouFeedTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final _auth = FirebaseAuth.instance;

  @override
  bool get wantKeepAlive => true;

  void scrollToTopAndRefresh() {
    if (_scrollController.hasClients) {
      try {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (e) {
        // If animation fails, just jump to top
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
      }
    }
    final userId = _auth.currentUser?.uid;
    if (userId != null && mounted) {
      context.read<UnifiedFeedBloc>().add(LoadUnifiedFeedEvent(
            userId: userId,
            refresh: true,
            timeFilter: TimeFilter.allTime,
          ));
    }
  }

  @override
  void initState() {
    super.initState();
    // Load initial feed - BLoC is now provided by FeedScreen parent
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      // Use WidgetsBinding to ensure context is available after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          context.read<UnifiedFeedBloc>().add(
                LoadUnifiedFeedEvent(
                  userId: userId,
                  refresh: true,
                  timeFilter: TimeFilter.allTime,
                ),
              );
        }
      });
    }

    // Infinite scroll detection
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        context.read<UnifiedFeedBloc>().add(
              LoadMoreUnifiedFeedEvent(
                userId: userId,
                timeFilter: TimeFilter.allTime,
              ),
            );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    // BLoC is provided by FeedScreen parent
    return BlocBuilder<UnifiedFeedBloc, UnifiedFeedState>(
      builder: (context, state) {
        if (state is UnifiedFeedLoading) {
          return _buildLoadingSkeleton();
        }

        if (state is UnifiedFeedError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${state.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
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
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state is UnifiedFeedLoaded) {
          if (state.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.explore, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No content to discover yet',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
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
              }
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              controller: _scrollController,
              itemCount: 3 + state.items.length + (state.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                // Header 0: Stories Tray (at the top)
                if (index == 0) {
                  return Padding(
                    padding: EdgeInsets.only(
                      top: DesignTokens.spaceSM,
                      bottom: DesignTokens.spaceXS,
                    ),
                    child: const StoriesTrayWidget(),
                  );
                }
                // Header 1: Create Post Widget
                if (index == 1) {
                  return const CreatePostWidget();
                }
                // Header 2: Trending horizontal
                if (index == 2) {
                  return _buildTrendingSection();
                }

                final adjustedIndex = index - 3;
                // Show loading indicator at the end
                if (adjustedIndex == state.items.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                // Handle different FeedItem types
                final item = state.items[adjustedIndex];
                return _buildFeedItem(item);
              },
            ),
          );
        }

        return const Center(child: Text('Initializing feed...'));
      },
    );
  }

  Widget _buildTrendingSection() {
    return BlocBuilder<UnifiedFeedBloc, UnifiedFeedState>(
      builder: (context, state) {
        // Extract trending posts from loaded state
        List<PostFeedItem> trendingPosts = [];
        if (state is UnifiedFeedLoaded) {
          trendingPosts = state.items
              .whereType<PostFeedItem>()
              .where((item) => item.displayType == PostDisplayType.trending)
              .take(8)
              .toList();
        }

        // If no trending posts, show highest scoring posts instead
        if (trendingPosts.isEmpty && state is UnifiedFeedLoaded) {
          final userId = _auth.currentUser?.uid;
          if (userId != null) {
            // Get all posts from the feed (excluding user's own recent posts)
            final allPosts = state.items
                .whereType<PostFeedItem>()
                .where((item) =>
                    item.post.authorId != userId || // Include non-user posts
                    item.displayType !=
                        PostDisplayType
                            .organic) // Or user posts that aren't organic
                .map((item) => item.post)
                .toList();

            if (allPosts.isNotEmpty) {
              // Score all posts and get the highest scoring ones
              // Note: userLocation is optional, scoring will work without it
              final scoredPosts = allPosts.map((post) {
                final score = FeedScoringService.calculateScore(
                  post,
                  currentUserId: userId,
                  userLocation:
                      null, // Optional - scoring works without location
                  timeFilter: state.timeFilter,
                );
                return (post: post, score: score.score);
              }).toList();

              // Sort by score (highest first) and take top 8
              scoredPosts.sort((a, b) => b.score.compareTo(a.score));
              final topPosts = scoredPosts.take(8).map((scored) {
                return PostFeedItem(
                  post: scored.post,
                  displayType:
                      PostDisplayType.trending, // Show as trending in trail
                );
              }).toList();

              if (topPosts.isNotEmpty) {
                trendingPosts = topPosts;
              }
            }
          }
        }

        // Show placeholder if loading or empty
        if (trendingPosts.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMD,
                  vertical: DesignTokens.spaceSM,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      size: DesignTokens.iconMD,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    SizedBox(width: DesignTokens.spaceSM),
                    Text(
                      'Trending',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  padding:
                      EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, i) => Container(
                    width: 220,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMD),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: DesignTokens.spaceSM),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceSM,
                            vertical: DesignTokens.spaceSM,
                          ),
                          child: Container(
                            height: 10,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusXS),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  separatorBuilder: (_, __) =>
                      SizedBox(width: DesignTokens.spaceMD),
                  itemCount: 4,
                ),
              ),
            ],
          );
        }

        // Show actual trending posts
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceMD,
                vertical: DesignTokens.spaceSM,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: DesignTokens.iconMD,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  SizedBox(width: DesignTokens.spaceSM),
                  Text(
                    'Trending',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
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
                      EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemBuilder: (context, i) {
                    final post = trendingPosts[i];
                    return TrendingPostCard(item: post);
                  },
                  separatorBuilder: (_, __) =>
                      SizedBox(width: DesignTokens.spaceMD),
                  itemCount: trendingPosts.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeedItem(FeedItem item) {
    if (item is PostFeedItem) {
      return PostCard(item: item);
    } else if (item is AdFeedItem) {
      return AdCard(adCacheKey: item.cacheKey);
    } else if (item is SuggestionCarouselFeedItem) {
      return SuggestionCarouselWidget(
        type: item.type,
        suggestions: item.suggestions,
        onDismiss: () {
          // TODO: Implement dismiss logic to remove from feed
          debugPrint('Dismissing suggestion carousel');
        },
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[400],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 16,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 12,
                width: double.infinity,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Container(
                height: 12,
                width: 200,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
