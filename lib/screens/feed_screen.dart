// lib/screens/feed_screen.dart
// Facebook-style Feed with integrated Reels (swipe to access)

import 'package:flutter/material.dart';
import 'package:freegram/screens/feed/for_you_feed_tab.dart'
    show ForYouFeedTab, kForYouFeedTabKey;
import 'package:freegram/locator.dart';
import 'package:freegram/blocs/unified_feed_bloc.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/repositories/friend_repository.dart'; // Added import
import 'package:freegram/repositories/reel_repository.dart';
import 'package:freegram/repositories/page_repository.dart';
import 'package:freegram/services/ad_service.dart';
import 'package:freegram/services/feed_cache_service.dart';
import 'package:freegram/utils/enums.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/reels_feed_screen.dart';

class FeedScreen extends StatefulWidget {
  final ValueChanged<bool>?
      onScrollDirectionChanged; // Forward scroll direction to MainScreen
  final bool isVisible; // Controls video playback status

  const FeedScreen({
    Key? key,
    this.onScrollDirectionChanged,
    this.isVisible = true,
  }) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  bool _isNavigatingToReels = false;
  late UnifiedFeedBloc _feedBloc;
  bool _hasInitializedFeed = false;
  bool _hideTabBar =
      false; // Track tab bar visibility - visible by default, hide on scroll down

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

    // Create BLoC once in initState to preserve state
    _feedBloc = UnifiedFeedBloc(
      postRepository: locator<PostRepository>(),
      userRepository: locator<UserRepository>(),
      friendRepository: locator<FriendRepository>(), // Added injection
      adService: locator<AdService>(),
      reelRepository: locator<ReelRepository>(),
      pageRepository: locator<PageRepository>(),
      feedCacheService: locator<FeedCacheService>(),
    );

    // Ensure tab bar is visible on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _hideTabBar = false;
        });
      }
    });
  }

  void _handleTabChange() {
    // Safety check: navigate to Reels if tab changes to index 1
    if (_tabController.index == 1 && !_isNavigatingToReels && mounted) {
      _navigateToReels();
    }
  }

  void _navigateToReels() {
    if (_isNavigatingToReels || !mounted) return;

    setState(() {
      _isNavigatingToReels = true;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReelsFeedScreen(),
        fullscreenDialog: false,
      ),
    ).then((_) {
      // Reset navigation flag when returning
      if (mounted) {
        setState(() {
          _isNavigatingToReels = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);

    // Load feed only once on first build
    if (!_hasInitializedFeed) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _feedBloc.add(LoadUnifiedFeedEvent(
              userId: userId,
              refresh: false, // Don't refresh if already loaded
              timeFilter: TimeFilter.allTime,
            ));
            _hasInitializedFeed = true;
          }
        });
      }
    }

    // FeedScreen is embedded in MainScreen, so no Scaffold needed
    // When extendBodyBehindAppBar is true, body starts at y=0 (behind AppBar)
    // Use Stack with Positioned TabBar to overlay content and slide up smoothly
    // Calculate AppBar height to match MainScreen's AppBar toolbarHeight exactly
    final mediaQuery = MediaQuery.of(context);
    final appBarHeight = kToolbarHeight + mediaQuery.padding.top;

    return Stack(
      clipBehavior:
          Clip.none, // Allow TabBar to extend beyond Stack bounds if needed
      children: [
        // Content area - starts from top (y=0), no padding needed
        GestureDetector(
          // Intercept horizontal swipes to navigate to Reels
          // Only detect horizontal swipes, let vertical scrolling pass through
          onHorizontalDragEnd: (details) {
            // Swipe left (towards Reels) - navigate immediately
            if (details.primaryVelocity != null &&
                details.primaryVelocity! < -500) {
              if (!_isNavigatingToReels && mounted) {
                _navigateToReels();
              }
            }
          },
          behavior: HitTestBehavior.translucent, // Allow taps to pass through
          child: TabBarView(
            controller: _tabController,
            // Disable default swiping - we handle it manually via gesture detector
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // For You Tab - Use BlocProvider.value to reuse existing BLoC
              BlocProvider.value(
                value: _feedBloc,
                child: ForYouFeedTab(
                  key: kForYouFeedTabKey,
                  isVisible: widget.isVisible,
                  onScrollDirectionChanged: (isScrollingDown) {
                    if (mounted) {
                      setState(() {
                        _hideTabBar = isScrollingDown;
                      });
                    }
                    widget.onScrollDirectionChanged?.call(isScrollingDown);
                  },
                  onScrollToTop: () {
                    // Show nav bars when scroll-to-top button is pressed
                    setState(() {
                      _hideTabBar = false; // Show tab bar
                    });
                    // Forward to MainScreen for bottom nav bar
                    widget.onScrollDirectionChanged?.call(false);
                  },
                ),
              ),
              // Reels Tab - Never shown, navigation happens immediately
              Container(
                color: theme.scaffoldBackgroundColor,
              ),
            ],
          ),
        ),
        // TabBar positioned directly under AppBar - slides up when hidden
        Positioned(
          top: appBarHeight,
          left: 0,
          right: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0,
              _hideTabBar ? -60 : 0,
              0,
            ),
            child: Transform.translate(
              offset: const Offset(
                  0, -60.0), // Pull TabBar up slightly to close gap
              child: Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor,
                      width: 0.5,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'For You'),
                    Tab(text: 'Reels'),
                  ],
                  indicatorColor: SonarPulseTheme.primaryAccent,
                  labelColor: SonarPulseTheme.primaryAccent,
                  unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(
                    DesignTokens.opacityMedium,
                  ),
                  labelStyle: const TextStyle(
                    fontSize: DesignTokens.fontSizeMD,
                    fontWeight: FontWeight.w600,
                  ),
                  onTap: (index) {
                    // Navigate to Reels when tapped
                    if (index == 1) {
                      _navigateToReels();
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
