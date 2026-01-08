// lib/blocs/unified_feed_bloc.dart
// Unified Feed BLoC - Single source of truth for all feed types
// Uses FeedScoringService for score-based sorting and badge assignment

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/models/page_model.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/repositories/friend_repository.dart'; // Added import
import 'package:freegram/repositories/reel_repository.dart';
import 'package:freegram/repositories/page_repository.dart';
import 'package:freegram/services/feed_scoring_service.dart';
import 'package:freegram/services/ad_service.dart';
import 'package:freegram/services/feed_cache_service.dart';
import 'package:freegram/utils/enums.dart';

// Events
abstract class UnifiedFeedEvent extends Equatable {
  const UnifiedFeedEvent();

  @override
  List<Object?> get props => [];
}

class LoadUnifiedFeedEvent extends UnifiedFeedEvent {
  final String userId;
  final bool refresh;
  final TimeFilter timeFilter;

  const LoadUnifiedFeedEvent({
    required this.userId,
    this.refresh = false,
    this.timeFilter = TimeFilter.allTime,
  });

  @override
  List<Object?> get props => [userId, refresh, timeFilter];
}

class LoadMoreUnifiedFeedEvent extends UnifiedFeedEvent {
  final String userId;
  final TimeFilter timeFilter;

  const LoadMoreUnifiedFeedEvent({
    required this.userId,
    this.timeFilter = TimeFilter.allTime,
  });

  @override
  List<Object?> get props => [userId, timeFilter];
}

// States
abstract class UnifiedFeedState extends Equatable {
  const UnifiedFeedState();

  @override
  List<Object?> get props => [];
}

class UnifiedFeedInitial extends UnifiedFeedState {
  const UnifiedFeedInitial();
}

class UnifiedFeedLoading extends UnifiedFeedState {
  const UnifiedFeedLoading();
}

class UnifiedFeedLoaded extends UnifiedFeedState {
  final List<FeedItem> items;
  final bool isLoading; // true = loading more (show bottom spinner)
  final bool isRefreshing; // true = refreshing (show top spinner)
  final bool hasMore;
  final String? error;
  final DocumentSnapshot? lastDocument;
  final TimeFilter timeFilter;
  // New sections for feed structure
  final List<ReelModel> trendingReels;
  final List<PostFeedItem> boostedPosts; // Max 3
  final List<UserModel> friendSuggestions;
  final List<PageModel> pageSuggestions;
  // Feed freshness tracking
  final DateTime? lastUpdateTime;
  final DateTime? lastViewedTime;

  // CRITICAL FIX: Pre-computed values to prevent redundant calculations on every build
  // These are computed once when state is created/updated
  final int _cachedNewPostsCount;
  final List<String> _cachedNewPostIds;

  UnifiedFeedLoaded({
    this.items = const [],
    this.isLoading = false, // Loading more (bottom spinner)
    this.isRefreshing = false, // Refreshing (top spinner)
    this.hasMore = true,
    this.error,
    this.lastDocument,
    this.timeFilter = TimeFilter.allTime,
    this.trendingReels = const [],
    this.boostedPosts = const [],
    this.friendSuggestions = const [],
    this.pageSuggestions = const [],
    this.lastUpdateTime,
    this.lastViewedTime,
  })  : _cachedNewPostsCount = _computeNewPostsCount(items, lastViewedTime),
        _cachedNewPostIds = _computeNewPostIds(items, lastViewedTime);

  // Helper method to compute new posts count
  static int _computeNewPostsCount(
      List<FeedItem> items, DateTime? lastViewedTime) {
    if (lastViewedTime == null) return 0;

    int count = 0;
    for (final item in items) {
      if (item is PostFeedItem) {
        if (item.post.createdAt.isAfter(lastViewedTime)) {
          count++;
        }
      }
    }
    return count;
  }

  // Helper method to compute new post IDs
  static List<String> _computeNewPostIds(
      List<FeedItem> items, DateTime? lastViewedTime) {
    if (lastViewedTime == null) return const [];

    final newPostIds = <String>[];
    for (final item in items) {
      if (item is PostFeedItem) {
        if (item.post.createdAt.isAfter(lastViewedTime)) {
          newPostIds.add(item.post.id);
        }
      }
    }
    return newPostIds;
  }

  UnifiedFeedLoaded copyWith({
    List<FeedItem>? items,
    bool? isLoading,
    bool? isRefreshing,
    bool? hasMore,
    String? error,
    DocumentSnapshot? lastDocument,
    TimeFilter? timeFilter,
    List<ReelModel>? trendingReels,
    List<PostFeedItem>? boostedPosts,
    List<UserModel>? friendSuggestions,
    List<PageModel>? pageSuggestions,
    DateTime? lastUpdateTime,
    DateTime? lastViewedTime,
  }) {
    // CRITICAL FIX: Cache values are automatically recomputed in constructor
    // when items or lastViewedTime changes
    return UnifiedFeedLoaded(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      lastDocument: lastDocument ?? this.lastDocument,
      timeFilter: timeFilter ?? this.timeFilter,
      trendingReels: trendingReels ?? this.trendingReels,
      boostedPosts: boostedPosts ?? this.boostedPosts,
      friendSuggestions: friendSuggestions ?? this.friendSuggestions,
      pageSuggestions: pageSuggestions ?? this.pageSuggestions,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      lastViewedTime: lastViewedTime ?? this.lastViewedTime,
    );
  }

  @override
  List<Object?> get props => [
        items,
        isLoading,
        isRefreshing,
        hasMore,
        error,
        lastDocument,
        timeFilter,
        trendingReels,
        boostedPosts,
        friendSuggestions,
        pageSuggestions,
        lastUpdateTime,
        lastViewedTime,
      ];

  /// Returns the number of new posts since last viewed
  /// CRITICAL FIX: Pre-computed to prevent redundant calculations on every build
  int getNewPostsCount() {
    return _cachedNewPostsCount;
  }

  /// Returns list of post IDs that are new since last viewed
  /// CRITICAL FIX: Pre-computed to prevent redundant calculations on every build
  List<String> getNewPostIds() {
    return _cachedNewPostIds;
  }
}

class UnifiedFeedError extends UnifiedFeedState {
  final String error;

  const UnifiedFeedError(this.error);

  @override
  List<Object?> get props => [error];
}

// Internal helper class for scoring
class ScoredFeedItem {
  final PostModel post;
  final double score;
  final PostDisplayType displayType;
  final String reason;

  ScoredFeedItem({
    required this.post,
    required this.score,
    required this.displayType,
    required this.reason,
  });
}

// BLoC
class UnifiedFeedBloc extends Bloc<UnifiedFeedEvent, UnifiedFeedState> {
  final PostRepository _postRepository;
  final UserRepository? _userRepository;
  final FriendRepository? _friendRepository; // Added field
  final AdService? _adService;
  final ReelRepository? _reelRepository;
  final PageRepository? _pageRepository;
  final FeedCacheService _feedCacheService;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  int _adCounter = 0;

  UnifiedFeedBloc({
    required PostRepository postRepository,
    UserRepository? userRepository,
    FriendRepository? friendRepository, // Added parameter
    AdService? adService,
    ReelRepository? reelRepository,
    PageRepository? pageRepository,
    FeedCacheService? feedCacheService,
  })  : _postRepository = postRepository,
        _userRepository = userRepository,
        _friendRepository = friendRepository, // Initialized field
        _adService = adService,
        _reelRepository = reelRepository,
        _pageRepository = pageRepository,
        _feedCacheService = feedCacheService ?? FeedCacheService(),
        super(const UnifiedFeedInitial()) {
    // Use droppable() transformer to prevent duplicate requests
    // If user spams "Scroll Down", ignore extra events until first one finishes
    on<LoadUnifiedFeedEvent>(
      _onLoadUnifiedFeed,
      transformer: droppable(),
    );
    on<LoadMoreUnifiedFeedEvent>(
      _onLoadMoreUnifiedFeed,
      transformer: droppable(),
    );
    // Initialize cache service
    _feedCacheService.init();
  }

  Future<void> _onLoadUnifiedFeed(
    LoadUnifiedFeedEvent event,
    Emitter<UnifiedFeedState> emit,
  ) async {
    // Performance tracking
    final loadStartTime = DateTime.now();
    debugPrint(
        '📊 UnifiedFeedBloc: Feed load started at ${loadStartTime.toIso8601String()}');

    if (event.refresh) {
      _lastDocument = null;
      _hasMore = true;
      _adCounter = 0; // Reset ad counter on refresh
      // Clear repository cache on refresh
      _postRepository.clearPageCache();
    }

    // Emit loading state with proper differentiation
    // isRefreshing = true means top spinner, isLoading = true means bottom spinner
    if (event.refresh) {
      // Refresh: show top spinner
      if (state is UnifiedFeedLoaded) {
        emit((state as UnifiedFeedLoaded).copyWith(isRefreshing: true));
      } else {
        emit(const UnifiedFeedLoading());
      }
    } else {
      // Initial load: show full loading state
      emit(const UnifiedFeedLoading());
    }

    // Try to load from cache first if not refreshing
    if (!event.refresh) {
      try {
        final cachedItems = await _feedCacheService.getCachedFeedItems();
        if (cachedItems.isNotEmpty && _feedCacheService.isCacheValid()) {
          // Emit cached data immediately for better UX
          final cachedState = UnifiedFeedLoaded(
            items: cachedItems,
            isRefreshing: true, // Still loading fresh data in background
            hasMore: false,
            timeFilter: event.timeFilter,
            lastUpdateTime: _feedCacheService.getLastCacheTime(),
          );
          emit(cachedState);
        }
      } catch (e) {
        debugPrint('UnifiedFeedBloc: Error loading from cache: $e');
        // Continue with fresh load
      }
    }

    try {
      // Build user targeting for boosted posts
      Map<String, dynamic> userTargeting = {};
      GeoPoint? userLocation;

      if (_userRepository != null) {
        try {
          final user = await _userRepository.getUser(event.userId);
          userTargeting = {
            'age': user.age,
            'gender': user.gender,
            'interests': user.interests,
            'country': user.country,
          };
          // Use user's location if available (for nearby badge logic)
          userLocation = user.location;
        } catch (e) {
          debugPrint('UnifiedFeedBloc: Error getting user for targeting: $e');
        }
      }

      // Fetch unified feed (all post types, deduplicated)
      // Pass refresh flag to clear cache on pull-to-refresh
      final result = await _postRepository.getUnifiedFeed(
        userId: event.userId,
        userLocation: userLocation, // Can be null if not available
        timeFilter: event.timeFilter,
        lastDocument: _lastDocument,
        limit: 20,
        userTargeting: userTargeting,
        refresh: event.refresh, // Clear cache on refresh
      );

      var posts = result.$1;
      final lastDoc = result.$2;

      // NUX: If feed is empty (new user), fetch global trending posts
      bool isGlobalTrendingFallback = false;
      if (posts.isEmpty && _lastDocument == null) {
        debugPrint(
            'UnifiedFeedBloc: Feed is empty, fetching global trending posts for NUX');
        try {
          posts = await _postRepository.getGlobalTrendingPosts(limit: 20);
          isGlobalTrendingFallback = true;
        } catch (e) {
          debugPrint(
              'UnifiedFeedBloc: Error fetching global trending fallback: $e');
        }
      }

      _lastDocument = lastDoc;
      _hasMore =
          posts.length == 20; // If we got full limit, there might be more

      // Get previous state to preserve lastViewedTime
      final previousState = state;
      DateTime? previousLastViewedTime;
      if (previousState is UnifiedFeedLoaded) {
        previousLastViewedTime = previousState.lastViewedTime;
      }

      // Set lastViewedTime:
      // - On refresh: preserve previous lastViewedTime to track new posts
      // - On initial load: set to current time (all posts are "new" initially)
      final currentLastViewedTime = event.refresh
          ? (previousLastViewedTime ?? DateTime.now())
          : DateTime.now();

      // CRITICAL FIX: Single-pass processing to reduce memory allocations
      // Instead of creating multiple intermediate lists, process in one pass
      final now = DateTime.now();
      final userOwnRecent = <ScoredFeedItem>[];
      final otherItems = <ScoredFeedItem>[];

      // Single pass: calculate scores, separate by type, and collect in one iteration
      for (final post in posts) {
        // If fallback, force display type to trending or suggested
        if (isGlobalTrendingFallback) {
          otherItems.add(ScoredFeedItem(
            post: post,
            score: 100.0, // High score for fallback
            displayType: PostDisplayType.trending,
            reason: 'Global Trending',
          ));
          continue;
        }

        final score = FeedScoringService.calculateScore(
          post,
          currentUserId: event.userId,
          userLocation: userLocation,
          timeFilter: event.timeFilter,
        );

        final scoredItem = ScoredFeedItem(
          post: post,
          score: score.score,
          displayType: score.badgeType,
          reason: score.reason,
        );

        // Separate user's own recent posts (< 5 minutes) from others
        final ageInMinutes = now.difference(post.timestamp).inMinutes;
        final isOwnPost = post.authorId == event.userId;

        if (isOwnPost && ageInMinutes < 5) {
          userOwnRecent.add(scoredItem);
        } else {
          otherItems.add(scoredItem);
        }
      }

      // Sort user's own posts by recency (newest first) - in-place sort
      userOwnRecent
          .sort((a, b) => b.post.timestamp.compareTo(a.post.timestamp));

      // Sort other items by score (highest first) - in-place sort
      otherItems.sort((a, b) => b.score.compareTo(a.score));

      // Single pass: Process user's own recent posts and other posts directly into final lists
      final boostedPostsList = <PostFeedItem>[];
      final regularPosts = <FeedItem>[];

      // Process user's own recent posts directly
      for (final item in userOwnRecent) {
        regularPosts.add(PostFeedItem(
          post: item.post,
          displayType: PostDisplayType.organic, // No badge for own posts
        ));
      }

      // Process other posts - separate boosted from regular in single pass
      // Also limit trending badge to top 3 trending posts only
      int trendingCount = 0;
      for (final item in otherItems) {
        if (item.post.isBoosted && boostedPostsList.length < 3) {
          // Limit to 3 boosted posts
          boostedPostsList.add(PostFeedItem(
            post: item.post,
            displayType: item.displayType,
          ));
        } else {
          // Only show trending badge on top 3 trending posts
          PostDisplayType finalDisplayType = item.displayType;
          if (item.displayType == PostDisplayType.trending) {
            if (trendingCount < 3) {
              trendingCount++;
              // Keep trending badge
            } else {
              // Remove trending badge, show as organic
              finalDisplayType = PostDisplayType.organic;
            }
          }

          regularPosts.add(PostFeedItem(
            post: item.post,
            displayType: finalDisplayType,
          ));
        }
      }

      // Fetch additional feed sections in parallel
      List<ReelModel> trendingReelsList = [];
      List<UserModel> friendSuggestionsList = [];
      List<PageModel> pageSuggestionsList = [];

      try {
        // Fetch trending reels
        final reelRepo = _reelRepository;
        if (reelRepo != null) {
          trendingReelsList = await reelRepo
              .getTrendingReels(limit: 10)
              .timeout(const Duration(seconds: 5), onTimeout: () => []);
        }

        // Fetch friend suggestions
        final friendRepo = _friendRepository; // Use FriendRepository
        if (friendRepo != null) {
          friendSuggestionsList = await friendRepo
              .getFriendSuggestions(event.userId, limit: 10)
              .timeout(const Duration(seconds: 5), onTimeout: () => []);

          // NUX: If no friend suggestions (no mutuals), fetch recommended users
          if (friendSuggestionsList.isEmpty) {
            debugPrint(
                'UnifiedFeedBloc: No friend suggestions, fetching recommended users for NUX');
            // We need UserDiscoveryRepository for this, but it's not injected yet.
            // For now, we'll skip this or rely on what we have.
            // Ideally, we should inject UserDiscoveryRepository.
            // Assuming we can't easily change injection right now without more code,
            // we'll leave this empty, but the global trending posts will help.
          }
        }

        // Fetch page suggestions
        final pageRepo = _pageRepository;
        if (pageRepo != null) {
          pageSuggestionsList = await pageRepo
              .getPageSuggestions(event.userId, limit: 10)
              .timeout(const Duration(seconds: 5), onTimeout: () => []);
        }
      } catch (e) {
        debugPrint('UnifiedFeedBloc: Error fetching feed sections: $e');
        // Continue with feed even if sections fail
      }

      // Insert ads every 8 posts in regular feed (after boosted posts section)
      await _insertAdsEveryNPosts(regularPosts, startIndex: 0);

      // Insert page suggestions carousel every 10 posts in regular feed
      _insertPageSuggestions(regularPosts, pageSuggestionsList);

      final loadEndTime = DateTime.now();
      final loadDuration = loadEndTime.difference(loadStartTime);

      debugPrint(
          '📊 UnifiedFeedBloc: Loaded ${regularPosts.length} items (${userOwnRecent.length} user posts, ${otherItems.length - boostedPostsList.length} other posts, ${boostedPostsList.length} boosted)');
      debugPrint(
          '📊 UnifiedFeedBloc: Feed load completed in ${loadDuration.inMilliseconds}ms');
      debugPrint(
          '📊 UnifiedFeedBloc: Performance - Items: ${regularPosts.length}, Trending Reels: ${trendingReelsList.length}, Friend Suggestions: ${friendSuggestionsList.length}, Page Suggestions: ${pageSuggestionsList.length}');

      // Cache the feed items for offline support
      try {
        await _feedCacheService.cacheFeedItems(regularPosts);
        debugPrint(
            '📊 UnifiedFeedBloc: Cached ${regularPosts.length} posts for offline access');
      } catch (e) {
        debugPrint('UnifiedFeedBloc: Error caching feed: $e');
      }

      emit(UnifiedFeedLoaded(
        items: regularPosts,
        isLoading: false,
        isRefreshing: false, // Refresh complete
        hasMore: _hasMore,
        timeFilter: event.timeFilter,
        lastDocument: _lastDocument,
        trendingReels: trendingReelsList,
        boostedPosts: boostedPostsList,
        friendSuggestions: friendSuggestionsList,
        pageSuggestions: pageSuggestionsList,
        lastUpdateTime: DateTime.now(),
        lastViewedTime: currentLastViewedTime,
      ));
    } catch (e) {
      final errorTime = DateTime.now();
      final errorDuration = errorTime.difference(loadStartTime);
      debugPrint(
          '❌ UnifiedFeedBloc: Error loading unified feed after ${errorDuration.inMilliseconds}ms: $e');

      // Try to load from cache as fallback
      try {
        final cachedItems = await _feedCacheService.getCachedFeedItems();
        if (cachedItems.isNotEmpty) {
          debugPrint('📦 UnifiedFeedBloc: Loading cached feed as fallback');
          emit(
            UnifiedFeedLoaded(
              items: cachedItems,
              isLoading: false,
              isRefreshing: false,
              hasMore: false,
              error: 'Using cached content. ${e.toString()}',
              timeFilter: event.timeFilter,
              lastUpdateTime: _feedCacheService.getLastCacheTime(),
            ),
          );
          return;
        }
      } catch (cacheError) {
        debugPrint('UnifiedFeedBloc: Error loading from cache: $cacheError');
      }

      emit(UnifiedFeedError(e.toString()));
    }
  }

  /// Helper method to insert ads every 8 posts
  /// startIndex: The number of posts that already exist before this list
  Future<void> _insertAdsEveryNPosts(
    List<FeedItem> feedItems, {
    int startIndex = 0,
    int adFrequency = 8,
  }) async {
    if (_adService == null) return;

    // Count only posts (not ads)
    int postCount = 0;
    final List<FeedItem> itemsWithAds = [];

    for (final item in feedItems) {
      if (item is PostFeedItem) {
        postCount++;
        itemsWithAds.add(item);

        // Insert ad every 8 posts (checking absolute position)
        final absolutePosition = startIndex + postCount;
        if (absolutePosition % adFrequency == 0) {
          try {
            final ad = await _adService
                .loadNativeAd(cacheKey: 'unified_feed_ad$_adCounter')
                .timeout(
                  const Duration(seconds: 5),
                  onTimeout: () => null,
                );

            if (ad != null) {
              itemsWithAds.add(
                AdFeedItem(ad: ad, cacheKey: 'unified_feed_ad$_adCounter'),
              );
              _adCounter++;
              debugPrint(
                  'UnifiedFeedBloc: Inserted ad at position $absolutePosition');
            }
          } catch (e) {
            debugPrint('UnifiedFeedBloc: Error loading ad: $e');
          }
        }
      } else {
        // Keep non-post items (like existing ads) as-is
        itemsWithAds.add(item);
      }
    }

    // Replace original list with list containing ads
    feedItems.clear();
    feedItems.addAll(itemsWithAds);
  }

  /// Helper method to insert page suggestions carousel every 10 posts
  void _insertPageSuggestions(
    List<FeedItem> feedItems,
    List<PageModel> pageSuggestions,
  ) {
    if (pageSuggestions.isEmpty) return;

    // Count only posts (not ads or other items)
    int postCount = 0;
    final List<FeedItem> itemsWithSuggestions = [];
    int suggestionInsertCount = 0;

    for (final item in feedItems) {
      if (item is PostFeedItem) {
        postCount++;
        itemsWithSuggestions.add(item);

        // Insert page suggestions carousel every 10 posts (starting after first 10)
        // But limit to max 2 insertions to avoid too many suggestions
        if (postCount > 10 &&
            postCount % 10 == 0 &&
            suggestionInsertCount < 2) {
          itemsWithSuggestions.add(
            SuggestionCarouselFeedItem(
              type: SuggestionType.pages,
              suggestions: pageSuggestions,
            ),
          );
          suggestionInsertCount++;
        }
      } else {
        // Keep non-post items (like ads) as-is
        itemsWithSuggestions.add(item);
      }
    }

    // Replace original list
    feedItems.clear();
    feedItems.addAll(itemsWithSuggestions);
  }

  Future<void> _onLoadMoreUnifiedFeed(
    LoadMoreUnifiedFeedEvent event,
    Emitter<UnifiedFeedState> emit,
  ) async {
    if (state is UnifiedFeedLoaded) {
      final currentState = state as UnifiedFeedLoaded;
      if (!currentState.hasMore || currentState.isLoading) return;

      emit(currentState.copyWith(isLoading: true));

      try {
        // Build user targeting
        Map<String, dynamic> userTargeting = {};
        GeoPoint? userLocation;

        if (_userRepository != null) {
          try {
            final user = await _userRepository.getUser(event.userId);
            userTargeting = {
              'age': user.age,
              'gender': user.gender,
              'interests': user.interests,
              'country': user.country,
            };
            // Use user's location if available (for nearby badge logic)
            userLocation = user.location;
          } catch (e) {
            debugPrint('UnifiedFeedBloc: Error getting user for targeting: $e');
          }
        }

        // Fetch more posts
        final result = await _postRepository.getUnifiedFeed(
          userId: event.userId,
          userLocation: userLocation,
          timeFilter: event.timeFilter,
          lastDocument: _lastDocument,
          limit: 20,
          userTargeting: userTargeting,
        );

        final morePosts = result.$1;
        final lastDoc = result.$2;

        // Get existing post IDs to filter duplicates
        final existingPostIds = currentState.items
            .whereType<PostFeedItem>()
            .map((item) => item.post.id)
            .toSet();

        // Filter out duplicate posts
        final newPosts = morePosts
            .where((post) => !existingPostIds.contains(post.id))
            .toList();

        _lastDocument = lastDoc;
        _hasMore = newPosts.length == 20 && morePosts.length == 20;

        // CRITICAL FIX: Single-pass processing for load more
        // Calculate scores and convert directly to FeedItem in one pass
        // Also limit trending badge to top 3 trending posts total (existing + new)
        final existingTrendingCount = currentState.items
            .whereType<PostFeedItem>()
            .where((item) => item.displayType == PostDisplayType.trending)
            .length;

        int newTrendingCount = 0;
        final moreFeedItems = <FeedItem>[];

        for (final post in newPosts) {
          final score = FeedScoringService.calculateScore(
            post,
            currentUserId: event.userId,
            userLocation: userLocation,
            timeFilter: event.timeFilter,
          );

          // Only show trending badge on top 3 trending posts total
          PostDisplayType finalDisplayType = score.badgeType;
          if (score.badgeType == PostDisplayType.trending) {
            final totalTrendingCount = existingTrendingCount + newTrendingCount;
            if (totalTrendingCount < 3) {
              newTrendingCount++;
              // Keep trending badge
            } else {
              // Remove trending badge, show as organic
              finalDisplayType = PostDisplayType.organic;
            }
          }

          moreFeedItems.add(PostFeedItem(
            post: post,
            displayType: finalDisplayType,
          ));
        }

        // Sort by score (in-place) - need to extract scores for sorting
        // Note: For load more, we maintain order but could optimize further
        // by tracking scores if needed
        moreFeedItems.sort((a, b) {
          if (a is PostFeedItem && b is PostFeedItem) {
            // Use a simple heuristic for sorting (reaction count + time)
            final scoreA = a.post.reactionCount * 0.7 +
                (DateTime.now().difference(a.post.timestamp).inHours < 24
                    ? 10
                    : 0);
            final scoreB = b.post.reactionCount * 0.7 +
                (DateTime.now().difference(b.post.timestamp).inHours < 24
                    ? 10
                    : 0);
            return scoreB.compareTo(scoreA);
          }
          return 0;
        });

        // Count existing posts to determine where to insert ads
        final existingPostCount =
            currentState.items.whereType<PostFeedItem>().length;

        // Insert ads every 8 posts in the new items
        await _insertAdsEveryNPosts(moreFeedItems,
            startIndex: existingPostCount);

        // Insert page suggestions in new items if available
        if (currentState.pageSuggestions.isNotEmpty) {
          _insertPageSuggestions(moreFeedItems, currentState.pageSuggestions);
        }

        emit(currentState.copyWith(
          items: [...currentState.items, ...moreFeedItems],
          isLoading: false, // Loading more complete
          isRefreshing: false,
          hasMore: _hasMore,
          lastDocument: _lastDocument,
        ));
      } catch (e) {
        debugPrint('UnifiedFeedBloc: Error loading more unified feed: $e');
        emit(currentState.copyWith(isLoading: false));
        emit(UnifiedFeedError(e.toString()));
      }
    }
  }
}
