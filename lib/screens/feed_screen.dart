// lib/screens/feed_screen.dart
// Facebook-style Feed with integrated Reels (swipe to access)

import 'package:flutter/material.dart';
import 'package:freegram/screens/feed/for_you_feed_tab.dart'
    show ForYouFeedTab, kForYouFeedTabKey;
import 'package:freegram/locator.dart';
import 'package:freegram/blocs/unified_feed_bloc.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
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
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  bool _isNavigatingToReels = false;
  late UnifiedFeedBloc _feedBloc;
  bool _hasInitializedFeed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: feed_screen.dart');
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    
    // Create BLoC once in initState to preserve state
    _feedBloc = UnifiedFeedBloc(
      postRepository: locator<PostRepository>(),
      userRepository: locator<UserRepository>(),
      adService: locator<AdService>(),
      reelRepository: locator<ReelRepository>(),
      pageRepository: locator<PageRepository>(),
      feedCacheService: locator<FeedCacheService>(),
    );
  }

  void _handleTabChange() {
    // This listener is only for safety - manual navigation is handled by gesture
    // If somehow the tab changes to index 1, navigate immediately
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
    // Don't close BLoC here - let it persist for state preservation
    // It will be closed when FeedScreen is permanently disposed
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
    return Column(
      children: [
        // Facebook-style TabBar
        Container(
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
        Expanded(
          child: GestureDetector(
        // Intercept horizontal swipes to navigate to Reels
        // Only detect horizontal swipes, let vertical scrolling pass through
        onHorizontalDragEnd: (details) {
          // Swipe left (towards Reels) - navigate immediately
          if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
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
              child: ForYouFeedTab(key: kForYouFeedTabKey),
            ),
            // Reels Tab - Never shown, navigation happens immediately
            Container(
              color: theme.scaffoldBackgroundColor,
            ),
          ],
        ),
          ),
        ),
      ],
    );
  }
}
