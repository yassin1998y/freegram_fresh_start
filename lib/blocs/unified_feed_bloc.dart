// lib/blocs/unified_feed_bloc.dart
// Unified Feed BLoC - Single source of truth for all feed types
// Uses FeedScoringService for score-based sorting and badge assignment

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/services/feed_scoring_service.dart';
import 'package:freegram/services/ad_service.dart';
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
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final DocumentSnapshot? lastDocument;
  final TimeFilter timeFilter;

  const UnifiedFeedLoaded({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.lastDocument,
    this.timeFilter = TimeFilter.allTime,
  });

  UnifiedFeedLoaded copyWith({
    List<FeedItem>? items,
    bool? isLoading,
    bool? hasMore,
    String? error,
    DocumentSnapshot? lastDocument,
    TimeFilter? timeFilter,
  }) {
    return UnifiedFeedLoaded(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      lastDocument: lastDocument ?? this.lastDocument,
      timeFilter: timeFilter ?? this.timeFilter,
    );
  }

  @override
  List<Object?> get props =>
      [items, isLoading, hasMore, error, lastDocument, timeFilter];
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
  final AdService? _adService;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  int _adCounter = 0;

  UnifiedFeedBloc({
    required PostRepository postRepository,
    UserRepository? userRepository,
    AdService? adService,
  })  : _postRepository = postRepository,
        _userRepository = userRepository,
        _adService = adService,
        super(const UnifiedFeedInitial()) {
    on<LoadUnifiedFeedEvent>(_onLoadUnifiedFeed);
    on<LoadMoreUnifiedFeedEvent>(_onLoadMoreUnifiedFeed);
  }

  Future<void> _onLoadUnifiedFeed(
    LoadUnifiedFeedEvent event,
    Emitter<UnifiedFeedState> emit,
  ) async {
    if (event.refresh) {
      _lastDocument = null;
      _hasMore = true;
      _adCounter = 0; // Reset ad counter on refresh
    }

    emit(const UnifiedFeedLoading());

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
      final result = await _postRepository.getUnifiedFeed(
        userId: event.userId,
        userLocation: userLocation, // Can be null if not available
        timeFilter: event.timeFilter,
        lastDocument: _lastDocument,
        limit: 20,
        userTargeting: userTargeting,
      );

      final posts = result.$1;
      final lastDoc = result.$2;

      _lastDocument = lastDoc;
      _hasMore =
          posts.length == 20; // If we got full limit, there might be more

      // Calculate scores and determine badges for each post
      final scoredItems = posts.map((post) {
        final score = FeedScoringService.calculateScore(
          post,
          currentUserId: event.userId,
          userLocation: userLocation,
          timeFilter: event.timeFilter,
        );

        return ScoredFeedItem(
          post: post,
          score: score.score,
          displayType: score.badgeType,
          reason: score.reason,
        );
      }).toList();

      // Sort by score (highest first)
      scoredItems.sort((a, b) => b.score.compareTo(a.score));

      // Separate user's own recent posts (< 5 minutes) from others
      // These should ALWAYS be at the top
      final now = DateTime.now();
      final userOwnRecent = <ScoredFeedItem>[];
      final otherItems = <ScoredFeedItem>[];

      for (final item in scoredItems) {
        final ageInMinutes = now.difference(item.post.timestamp).inMinutes;
        final isOwnPost = item.post.authorId == event.userId;

        if (isOwnPost && ageInMinutes < 5) {
          userOwnRecent.add(item);
        } else {
          otherItems.add(item);
        }
      }

      // Sort user's own posts by recency (newest first)
      userOwnRecent
          .sort((a, b) => b.post.timestamp.compareTo(a.post.timestamp));

      // Convert to FeedItem list
      final feedItems = <FeedItem>[
        // User's own recent posts first (always at top)
        ...userOwnRecent.map((item) => PostFeedItem(
              post: item.post,
              displayType: PostDisplayType.organic, // No badge for own posts
            )),
        // Other posts sorted by score
        ...otherItems.map((item) => PostFeedItem(
              post: item.post,
              displayType: item.displayType, // Badge based on actual score
            )),
      ];

      // Insert ads every 8 posts
      await _insertAdsEveryNPosts(feedItems, startIndex: 0);

      debugPrint(
          'UnifiedFeedBloc: Loaded ${feedItems.length} items (${userOwnRecent.length} user posts, ${otherItems.length} other posts)');

      emit(UnifiedFeedLoaded(
        items: feedItems,
        isLoading: false,
        hasMore: _hasMore,
        timeFilter: event.timeFilter,
        lastDocument: _lastDocument,
      ));
    } catch (e) {
      debugPrint('UnifiedFeedBloc: Error loading unified feed: $e');
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

        // Calculate scores and determine badges
        final scoredItems = newPosts.map((post) {
          final score = FeedScoringService.calculateScore(
            post,
            currentUserId: event.userId,
            userLocation: userLocation,
            timeFilter: event.timeFilter,
          );

          return ScoredFeedItem(
            post: post,
            score: score.score,
            displayType: score.badgeType,
            reason: score.reason,
          );
        }).toList();

        // Sort by score
        scoredItems.sort((a, b) => b.score.compareTo(a.score));

        // Convert to FeedItem list
        final moreFeedItems = scoredItems
            .map((item) => PostFeedItem(
                  post: item.post,
                  displayType: item.displayType,
                ))
            .toList();

        // Count existing posts to determine where to insert ads
        final existingPostCount =
            currentState.items.whereType<PostFeedItem>().length;

        // Insert ads every 8 posts in the new items
        await _insertAdsEveryNPosts(moreFeedItems,
            startIndex: existingPostCount);

        emit(currentState.copyWith(
          items: [...currentState.items, ...moreFeedItems],
          isLoading: false,
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
