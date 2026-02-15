import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:freegram/locator.dart';
import 'package:freegram/blocs/unified_feed_bloc.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/repositories/notification_repository.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/feed/feed_item_entrance.dart';
import 'package:freegram/widgets/feed_widgets/stories_tray.dart';
import 'package:freegram/widgets/feed_widgets/create_post_widget.dart';
import 'package:freegram/widgets/feed_widgets/trending_reels_carousel.dart';
import 'package:freegram/widgets/feed_widgets/post_card.dart';
import 'package:freegram/widgets/skeletons/feed_loading_skeleton.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/screens/improved_chat_list_screen.dart';
import 'package:freegram/screens/notifications_screen.dart';

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
  bool _isTransparent = true;

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

    final newOffset = _scrollController.offset;
    const threshold = 200.0; // Past StoriesTray

    if (newOffset >= threshold && _isTransparent) {
      setState(() => _isTransparent = false);
    } else if (newOffset < threshold && !_isTransparent) {
      setState(() => _isTransparent = true);
    }

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

    return BlocProvider<UnifiedFeedBloc>(
      create: (context) => _feedBloc,
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

            // Task 5: Empty states check - DiscoveryModeCard removed
            // If items and trendingReels are empty, the CustomScrollView will be empty
            // but the RefreshIndicator will still be present.

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
                  // DYNAMIC APP BAR (Obsidian Theme)
                  SliverAppBar(
                    pinned: true,
                    floating: true,
                    snap: true,
                    centerTitle: true,
                    elevation: _isTransparent ? 0 : 4,
                    backgroundColor: _isTransparent
                        ? Colors.transparent
                        : SonarPulseTheme.darkSurface,
                    surfaceTintColor: Colors.transparent,
                    title: Image.asset(
                      'assets/freegram_logo.png',
                      height: 32,
                      color: Colors.white,
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.camera_alt_outlined,
                          color: Colors.white),
                      onPressed: () {
                        // Action for camera/story
                      },
                    ),
                    actions: [
                      _AppBarAction(
                        icon: Icons.chat_bubble_outline,
                        stream: locator<ChatRepository>()
                            .getUnreadChatCountStream(
                                FirebaseAuth.instance.currentUser?.uid ?? ''),
                        onPressed: () =>
                            locator<NavigationService>().navigateTo(
                          const ImprovedChatListScreen(),
                        ),
                      ),
                      _AppBarAction(
                        icon: Icons.notifications_outlined,
                        stream: locator<NotificationRepository>()
                            .getUnreadNotificationCountStream(
                                FirebaseAuth.instance.currentUser?.uid ?? ''),
                        onPressed: () {
                          // Notification bottom sheet logic copied from MainScreen
                          _showNotifications(context);
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    flexibleSpace: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: _isTransparent ? 0 : 10,
                          sigmaY: _isTransparent ? 0 : 10,
                        ),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Sliver 1: Stories Tray
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: StoriesTrayWidget(
                          // onStoryTap is now handled inside StoriesTrayWidget or by consumer
                          ),
                    ),
                  ),

                  // Sliver 2: Create Post Widget
                  const SliverToBoxAdapter(
                    child: CreatePostWidget(),
                  ),

                  // Sliver 3: First 2 posts
                  if (items.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= 2) return null; // Only first two for now
                          return FeedItemEntrance(
                            index: index,
                            child: PostCard(
                              item: items[index],
                              isVisible: widget.isVisible,
                              loadMedia: true,
                            ),
                          );
                        },
                        childCount: items.length > 2 ? 2 : items.length,
                      ),
                    ),

                  // Sliver 4: Trending Reels Carousel (inserted after the first 2 posts)
                  if (state.trendingReels.isNotEmpty)
                    SliverToBoxAdapter(
                      child: FeedItemEntrance(
                        index: 2,
                        child: TrendingReelsCarouselWidget(
                          reels: state.trendingReels,
                        ),
                      ),
                    ),

                  // Sliver 5: Remaining posts
                  if (items.length > 2)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final actualIndex = index + 2;
                          if (actualIndex >= items.length) return null;
                          return FeedItemEntrance(
                            index: actualIndex + 1, // Offset for reels
                            child: PostCard(
                              item: items[actualIndex],
                              isVisible: widget.isVisible,
                              loadMedia: true,
                            ),
                          );
                        },
                        childCount: items.length - 2,
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

                  // Bottom spacing
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
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

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusXL)),
      ),
      builder: (modalContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return NotificationsScreen(
              isModal: true,
              scrollController: scrollController,
            );
          },
        );
      },
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

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final Stream<int> stream;
  final VoidCallback onPressed;

  const _AppBarAction({
    required this.icon,
    required this.stream,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
        ),
        StreamBuilder<int>(
          stream: stream,
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            if (count == 0) return const SizedBox.shrink();

            return Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  count > 9 ? '9+' : count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
