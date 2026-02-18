import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/blocs/unified_feed_bloc.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/feed/feed_item_entrance.dart';
import 'package:freegram/widgets/feed_widgets/stories_tray.dart';
import 'package:freegram/widgets/feed_widgets/create_post_widget.dart';
import 'package:freegram/widgets/feed_widgets/trending_reels_carousel.dart';
import 'package:freegram/widgets/feed_widgets/trending_posts_section.dart';
import 'package:freegram/widgets/feed_widgets/post_card.dart';
import 'package:freegram/widgets/skeletons/feed_loading_skeleton.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

final GlobalKey<FeedScreenState> kFeedScreenKey = GlobalKey<FeedScreenState>();

class FeedScreen extends StatefulWidget {
  final ValueChanged<bool>? onScrollDirectionChanged;
  final bool isVisible;

  FeedScreen({
    Key? key,
    this.onScrollDirectionChanged,
    this.isVisible = true,
  }) : super(key: key ?? kFeedScreenKey);

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  late UnifiedFeedBloc _feedBloc;
  double _lastScrollOffset = 0;

  void scrollToTopAndRefresh() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
    _feedBloc.add(LoadUnifiedFeedEvent(
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      refresh: true,
    ));
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _feedBloc = locator<UnifiedFeedBloc>();

    // Initial fetch if needed
    if (_feedBloc.state is UnifiedFeedInitial) {
      _feedBloc.add(LoadUnifiedFeedEvent(
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      ));
    }
  }

  void _onScroll() {
    if (!mounted) return;

    final currentOffset = _scrollController.offset;

    // Handle bottom navigation bar hiding/showing
    if (currentOffset > _lastScrollOffset && currentOffset > 100) {
      // Scrolling down
      widget.onScrollDirectionChanged?.call(true);
    } else if (currentOffset < _lastScrollOffset) {
      // Scrolling up
      widget.onScrollDirectionChanged?.call(false);
    }
    _lastScrollOffset = currentOffset;

    // Infinite scroll trigger
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _feedBloc.add(LoadMoreUnifiedFeedEvent(
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      ));
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

    return BlocProvider<UnifiedFeedBloc>.value(
      value: _feedBloc,
      child: BlocBuilder<UnifiedFeedBloc, UnifiedFeedState>(
        builder: (context, state) {
          if (state is UnifiedFeedLoading) {
            return const FeedLoadingSkeleton();
          }

          if (state is UnifiedFeedError) {
            return _buildErrorState(context, state.error);
          }

          if (state is UnifiedFeedLoaded) {
            final items = state.items;

            return RefreshIndicator(
              onRefresh: () async {
                _feedBloc.add(LoadUnifiedFeedEvent(
                  userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                  refresh: true,
                ));
                await Future.delayed(const Duration(milliseconds: 800));
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. SliverAppBar (Identity) - Lean version
                  SliverAppBar(
                    automaticallyImplyLeading: false,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    floating: true,
                    title: Text(
                      'Freegram',
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: SonarPulseTheme.primaryAccent,
                                fontSize: DesignTokens.fontSizeDisplay,
                                height: DesignTokens.lineHeightTight,
                              ),
                    ),
                  ),

                  // 2. Stories Tray (SliverPadding for 16px margins)
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(
                        horizontal: DesignTokens.spaceMD, vertical: 8.0),
                    sliver: SliverToBoxAdapter(
                      child: StoriesTrayWidget(),
                    ),
                  ),

                  // 3. Create Post Widget (SliverToBoxAdapter)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 0.0),
                      child: CreatePostWidget(),
                    ),
                  ),

                  // 4. Trending Reels Carousel Widget (Discovery Priority - Always Visible)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spaceMD, vertical: 8.0),
                    sliver: SliverToBoxAdapter(
                      child: TrendingReelsCarouselWidget(
                        reels: state.trendingReels,
                      ),
                    ),
                  ),

                  // 5. Unified Feed Content (Main Trending/Friend Posts)
                  if (state.boostedPosts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: TrendingPostsSectionWidget(
                        trendingPosts: state.boostedPosts,
                      ),
                    ),

                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= items.length) return null;
                        return FeedItemEntrance(
                          index: index,
                          child: PostCard(
                            item: items[index],
                            isVisible: widget.isVisible,
                            loadMedia: true,
                          ),
                        );
                      },
                      childCount: items.length,
                    ),
                  ),

                  // Loading more indicator
                  if (state.isLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: DesignTokens.spaceXL),
                        child: Center(child: AppProgressIndicator()),
                      ),
                    ),

                  // Bottom spacing for navigation bar
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 120),
                  ),
                ],
              ),
            );
          }

          return const Center(child: AppProgressIndicator());
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _feedBloc.add(LoadUnifiedFeedEvent(
              userId: FirebaseAuth.instance.currentUser?.uid ?? '',
              refresh: true,
            )),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
