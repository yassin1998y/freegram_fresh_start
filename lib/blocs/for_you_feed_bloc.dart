// lib/blocs/for_you_feed_bloc.dart
//
// DEPRECATED: This BLoC is deprecated in favor of UnifiedFeedBloc.
// UnifiedFeedBloc provides score-based sorting and badge assignment,
// eliminating the need for complex mixing algorithms.
//
// This file is kept for backward compatibility with TrendingFeedTab.
// TODO: Migrate TrendingFeedTab to use UnifiedFeedBloc and remove this file.

import 'dart:async';
import 'dart:math' as math;
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/ranked_post.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/models/enums/post_content_type.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/services/ad_service.dart';
import 'package:freegram/utils/enums.dart';

// Events
abstract class ForYouFeedEvent extends Equatable {
  const ForYouFeedEvent();

  @override
  List<Object?> get props => [];
}

class LoadForYouFeedEvent extends ForYouFeedEvent {
  final String userId;
  final bool refresh;
  final TimeFilter timeFilter;

  const LoadForYouFeedEvent({
    required this.userId,
    this.refresh = false,
    this.timeFilter = TimeFilter.allTime,
  });

  @override
  List<Object?> get props => [userId, refresh, timeFilter];
}

class LoadMoreForYouFeedEvent extends ForYouFeedEvent {
  final String userId;
  final TimeFilter timeFilter;

  const LoadMoreForYouFeedEvent({
    required this.userId,
    this.timeFilter = TimeFilter.allTime,
  });

  @override
  List<Object?> get props => [userId, timeFilter];
}

// States
abstract class ForYouFeedState extends Equatable {
  const ForYouFeedState();

  @override
  List<Object?> get props => [];
}

class ForYouFeedInitial extends ForYouFeedState {
  const ForYouFeedInitial();
}

class ForYouFeedLoading extends ForYouFeedState {
  const ForYouFeedLoading();
}

class ForYouFeedLoaded extends ForYouFeedState {
  final List<FeedItem> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final DocumentSnapshot? lastDocument;
  final TimeFilter timeFilter;

  const ForYouFeedLoaded({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.lastDocument,
    this.timeFilter = TimeFilter.allTime,
  });

  ForYouFeedLoaded copyWith({
    List<FeedItem>? items,
    bool? isLoading,
    bool? hasMore,
    String? error,
    DocumentSnapshot? lastDocument,
    TimeFilter? timeFilter,
  }) {
    return ForYouFeedLoaded(
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

class ForYouFeedError extends ForYouFeedState {
  final String error;

  const ForYouFeedError(this.error);

  @override
  List<Object?> get props => [error];
}

// BLoC
@Deprecated(
    'Use UnifiedFeedBloc instead. This BLoC uses outdated mixing algorithms.')
class ForYouFeedBloc extends Bloc<ForYouFeedEvent, ForYouFeedState> {
  final PostRepository _postRepository;
  final UserRepository? _userRepository;
  final AdService? _adService;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  int _adCounter = 0;

  ForYouFeedBloc({
    required PostRepository postRepository,
    UserRepository? userRepository,
    AdService? adService,
  })  : _postRepository = postRepository,
        _userRepository = userRepository,
        _adService = adService,
        super(const ForYouFeedInitial()) {
    on<LoadForYouFeedEvent>(_onLoadForYouFeed);
    on<LoadMoreForYouFeedEvent>(_onLoadMoreForYouFeed);
  }

  /// Client-Side Ranking Plan: Refactored feed loading with ranking engine
  /// Calculates Score = Affinity × Content Weight × Time Decay on the device
  Future<void> _onLoadForYouFeed(
    LoadForYouFeedEvent event,
    Emitter<ForYouFeedState> emit,
  ) async {
    if (event.refresh) {
      _lastDocument = null;
      _hasMore = true;
      _adCounter = 0;
    }

    emit(const ForYouFeedLoading());

    try {
      // Step 1: Get current user (contains userAffinities map)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        emit(const ForYouFeedError('User not authenticated'));
        return;
      }

      // Get user document (contains userAffinities map)
      final userDoc = await _userRepository?.getUser(currentUser.uid);
      if (userDoc == null) {
        emit(const ForYouFeedError('User not found'));
        return;
      }

      // Step 2: Fetch candidate posts
      final List<PostModel> candidates =
          await _postRepository.getFeedCandidates(currentUser.uid);

      if (candidates.isEmpty) {
        emit(ForYouFeedLoaded(
          items: [],
          isLoading: false,
          hasMore: false,
          timeFilter: event.timeFilter,
        ));
        return;
      }

      // Step 3: Ranking Loop - Calculate score for each post
      final rankedPosts = candidates.map((post) {
        // Calculate Affinity (u)
        final targetId = post.pageId ?? post.authorId;
        final double affinity = userDoc!.getAffinityFor(targetId);

        // Calculate Content Weight (w)
        final double contentWeight = _calculateContentWeight(post);

        // Calculate Time Decay (d)
        final double timeDecay = _calculateTimeDecay(post.timestamp);

        // Calculate final score
        final double score = affinity * contentWeight * timeDecay;

        return RankedPost(post: post, score: score);
      }).toList();

      // Step 4: Sort by score (descending)
      rankedPosts.sort((a, b) => b.score.compareTo(a.score));

      // Step 5: Content Injection (Algorithm 3)
      final List<FeedItem> finalFeed = [];
      int postCount = 0;

      // Separate boosted posts from regular posts
      final boostedPosts = <RankedPost>[];
      final regularPosts = <RankedPost>[];

      for (final rankedPost in rankedPosts) {
        final post = rankedPost.post;
        final isBoosted = post.isBoosted &&
            post.boostEndTime != null &&
            post.boostEndTime!.toDate().isAfter(DateTime.now());

        if (isBoosted) {
          boostedPosts.add(rankedPost);
        } else {
          regularPosts.add(rankedPost);
        }
      }

      // Insert boosted posts at the top
      for (final rankedPost in boostedPosts) {
        finalFeed.add(PostFeedItem(
          post: rankedPost.post,
          displayType: PostDisplayType.boosted,
        ));
      }

      // Add regular posts with ad injection
      for (final rankedPost in regularPosts) {
        // Add the post
        finalFeed.add(PostFeedItem(
          post: rankedPost.post,
          displayType: PostDisplayType.trending,
        ));
        postCount++;

        // Insert ad every 8 posts
        if (postCount % 8 == 0) {
          try {
            final ad = await _adService?.loadNativeAd(
              cacheKey: 'for_you_feed_ad$_adCounter',
            );
            if (ad != null) {
              finalFeed.add(AdFeedItem(
                ad: ad,
                cacheKey: 'for_you_feed_ad$_adCounter',
              ));
              _adCounter++;
            }
          } catch (e) {
            debugPrint('ForYouFeedBloc: Error loading ad: $e');
          }
        }
      }

      // Update hasMore (simple check - could be enhanced with pagination)
      _hasMore = candidates.length >= 50;

      // Step 6: Emit final feed
      emit(ForYouFeedLoaded(
        items: finalFeed,
        isLoading: false,
        hasMore: _hasMore,
        timeFilter: event.timeFilter,
      ));
    } catch (e) {
      debugPrint('ForYouFeedBloc: Error loading feed: $e');
      emit(ForYouFeedError(e.toString()));
    }
  }

  Future<void> _onLoadMoreForYouFeed(
    LoadMoreForYouFeedEvent event,
    Emitter<ForYouFeedState> emit,
  ) async {
    if (state is ForYouFeedLoaded) {
      final currentState = state as ForYouFeedLoaded;
      if (!currentState.hasMore || currentState.isLoading) return;

      emit(currentState.copyWith(isLoading: true));

      try {
        // Get more trending posts
        final moreTrendingPosts = await _postRepository.getTrendingPosts(
          timeFilter: event.timeFilter,
          lastDocument: _lastDocument,
          limit: 10,
        );

        // Get existing post IDs to filter duplicates
        final existingPostIds = currentState.items
            .whereType<PostFeedItem>()
            .map((item) => item.post.id)
            .toSet();

        // Filter out duplicate posts
        final newPosts = moreTrendingPosts
            .where((post) => !existingPostIds.contains(post.id))
            .toList();

        _hasMore = newPosts.length == 10 && moreTrendingPosts.length == 10;

        // Mix with existing items (no new ads/suggestions for load more to keep it simple)
        final morePostItems = newPosts
            .map((post) => PostFeedItem(
                  post: post,
                  displayType: PostDisplayType.trending,
                ))
            .toList();

        emit(currentState.copyWith(
          items: [...currentState.items, ...morePostItems],
          isLoading: false,
          hasMore: _hasMore,
        ));
      } catch (e) {
        debugPrint('ForYouFeedBloc: Error loading more feed: $e');
        emit(currentState.copyWith(isLoading: false));
        emit(ForYouFeedError(e.toString()));
      }
    }
  }

  /// Smart feed mixing algorithm with diversity constraints
  /// Maintains ratio: For You (trending) 60%, Nearby 25%, Boosted 15%
  /// Prevents clustering of posts from same source
  ///
  /// DEPRECATED: This method is no longer used. UnifiedFeedBloc uses
  /// FeedScoringService for score-based sorting instead of manual mixing.
  @Deprecated('Use UnifiedFeedBloc with FeedScoringService instead')
  List<FeedItem> _mixFeedItems({
    List<PostModel> userOwnPosts = const [],
    required List<PostModel> trending,
    required List<PostModel> nearby,
    required List<PostModel> boosted,
    AdFeedItem? ad,
    required List<UserModel> suggestions,
  }) {
    // Separate posts by source with display types
    final forYouPosts = trending
        .map((p) => PostFeedItem(
              post: p,
              displayType: PostDisplayType.trending,
            ))
        .toList();

    final nearbyPosts = nearby
        .map((p) => PostFeedItem(
              post: p,
              displayType: PostDisplayType.nearby,
            ))
        .toList();

    final boostedPosts = boosted
        .map((p) => PostFeedItem(
              post: p,
              displayType: PostDisplayType.boosted,
            ))
        .toList();

    final userPosts = userOwnPosts
        .map((p) => PostFeedItem(
              post: p,
              displayType: PostDisplayType.organic,
            ))
        .toList();

    // Create queues for each source
    final forYouQueue = List<PostFeedItem>.from(forYouPosts);
    final nearbyQueue = List<PostFeedItem>.from(nearbyPosts);
    final boostedQueue = List<PostFeedItem>.from(boostedPosts);
    final userQueue = List<PostFeedItem>.from(userPosts);

    // Interleaving with diversity constraints
    final mergedFeed = <FeedItem>[];
    final sourceCount = <String, int>{
      'forYou': 0,
      'nearby': 0,
      'boosted': 0,
      'user': 0,
    };

    String? lastSource;
    int consecutiveSameSource = 0;
    int totalPosts = 0;

    // Shuffle queues for variety
    forYouQueue.shuffle();
    nearbyQueue.shuffle();
    boostedQueue.shuffle();
    userQueue.shuffle();

    // Interleaving algorithm
    while ((forYouQueue.isNotEmpty ||
            nearbyQueue.isNotEmpty ||
            boostedQueue.isNotEmpty ||
            userQueue.isNotEmpty) &&
        totalPosts < 50) {
      String? nextSource;

      // Rule 1: Don't allow >2 consecutive posts from same source
      if (consecutiveSameSource >= 2 && lastSource != null) {
        // Force different source
        if (lastSource == 'forYou') {
          nextSource = nearbyQueue.isNotEmpty
              ? 'nearby'
              : (boostedQueue.isNotEmpty ? 'boosted' : 'user');
        } else if (lastSource == 'nearby') {
          nextSource = forYouQueue.isNotEmpty
              ? 'forYou'
              : (boostedQueue.isNotEmpty ? 'boosted' : 'user');
        } else if (lastSource == 'boosted') {
          nextSource = forYouQueue.isNotEmpty
              ? 'forYou'
              : (nearbyQueue.isNotEmpty ? 'nearby' : 'user');
        } else {
          nextSource = forYouQueue.isNotEmpty
              ? 'forYou'
              : (nearbyQueue.isNotEmpty ? 'nearby' : 'boosted');
        }
      }
      // Rule 2: Maintain target ratios (For You: 60%, Nearby: 25%, Boosted: 15%)
      else if (totalPosts > 0) {
        final forYouRatio = sourceCount['forYou']! / totalPosts;
        final nearbyRatio = sourceCount['nearby']! / totalPosts;
        final boostedRatio = sourceCount['boosted']! / totalPosts;

        // Prioritize underrepresented sources
        if (forYouRatio > 0.65 && nearbyQueue.isNotEmpty) {
          nextSource = 'nearby';
        } else if (nearbyRatio > 0.3 && boostedQueue.isNotEmpty) {
          nextSource = 'boosted';
        } else if (nearbyRatio < 0.2 &&
            nearbyQueue.isNotEmpty &&
            totalPosts % 4 == 0) {
          nextSource = 'nearby';
        } else if (boostedRatio < 0.1 &&
            boostedQueue.isNotEmpty &&
            totalPosts % 6 == 0) {
          nextSource = 'boosted';
        } else if (forYouRatio < 0.5 && forYouQueue.isNotEmpty) {
          nextSource = 'forYou';
        }
      }

      // Rule 3: Default to highest priority source
      if (nextSource == null) {
        if (forYouQueue.isNotEmpty) {
          nextSource = 'forYou';
        } else if (nearbyQueue.isNotEmpty) {
          nextSource = 'nearby';
        } else if (boostedQueue.isNotEmpty) {
          nextSource = 'boosted';
        } else if (userQueue.isNotEmpty) {
          nextSource = 'user';
        }
      }

      // Rule 4: Fallback to available source
      if (nextSource == 'forYou' && forYouQueue.isEmpty) {
        nextSource = nearbyQueue.isNotEmpty
            ? 'nearby'
            : (boostedQueue.isNotEmpty ? 'boosted' : 'user');
      } else if (nextSource == 'nearby' && nearbyQueue.isEmpty) {
        nextSource = forYouQueue.isNotEmpty
            ? 'forYou'
            : (boostedQueue.isNotEmpty ? 'boosted' : 'user');
      } else if (nextSource == 'boosted' && boostedQueue.isEmpty) {
        nextSource = forYouQueue.isNotEmpty
            ? 'forYou'
            : (nearbyQueue.isNotEmpty ? 'nearby' : 'user');
      } else if (nextSource == 'user' && userQueue.isEmpty) {
        nextSource = forYouQueue.isNotEmpty
            ? 'forYou'
            : (nearbyQueue.isNotEmpty ? 'nearby' : 'boosted');
      }

      // Extract post from selected queue
      PostFeedItem? selectedPost;
      if (nextSource == 'forYou' && forYouQueue.isNotEmpty) {
        selectedPost = forYouQueue.removeAt(0);
      } else if (nextSource == 'nearby' && nearbyQueue.isNotEmpty) {
        selectedPost = nearbyQueue.removeAt(0);
      } else if (nextSource == 'boosted' && boostedQueue.isNotEmpty) {
        selectedPost = boostedQueue.removeAt(0);
      } else if (nextSource == 'user' && userQueue.isNotEmpty) {
        selectedPost = userQueue.removeAt(0);
      }

      if (selectedPost != null && nextSource != null) {
        mergedFeed.add(selectedPost);
        sourceCount[nextSource] = (sourceCount[nextSource] ?? 0) + 1;
        totalPosts++;

        // Update consecutive counter
        if (lastSource == nextSource) {
          consecutiveSameSource++;
        } else {
          consecutiveSameSource = 1;
          lastSource = nextSource;
        }

        // Insert ad every 10 posts (only once per load)
        if (ad != null && totalPosts % 10 == 0 && mergedFeed.length % 10 == 0) {
          mergedFeed.add(ad);
        }

        // Insert suggestion carousel every 12 posts (only once per load)
        if (totalPosts % 12 == 0 &&
            suggestions.isNotEmpty &&
            !mergedFeed.any((item) => item is SuggestionCarouselFeedItem)) {
          mergedFeed.add(SuggestionCarouselFeedItem(
            type: SuggestionType.friends,
            suggestions: suggestions,
          ));
        }
      } else {
        break; // No more posts available
      }
    }

    // Add remaining suggestions if not added yet
    if (suggestions.isNotEmpty &&
        !mergedFeed.any((item) => item is SuggestionCarouselFeedItem)) {
      mergedFeed.add(SuggestionCarouselFeedItem(
        type: SuggestionType.friends,
        suggestions: suggestions,
      ));
    }

    return mergedFeed;
  }

  /// Get nearby posts (uses feed for user as fallback)
  /// TODO: Implement actual nearby posts query with location when location features are ready
  Future<List<PostModel>> _getNearbyPosts(String userId,
      {int limit = 10}) async {
    try {
      // Use feed for user as nearby posts (includes friends + public posts)
      // This provides relevant content for the merged feed
      final posts = await _postRepository.getFeedForUser(
        userId: userId,
        limit: limit,
      );
      return posts;
    } catch (e) {
      debugPrint('ForYouFeedBloc: Error getting nearby posts: $e');
      return [];
    }
  }

  /// Get user's own recent posts to show in their feed
  Future<List<PostModel>> _getUserRecentPosts(String userId,
      {int limit = 5}) async {
    try {
      // Get user's own posts sorted by timestamp (most recent first)
      final posts = await _postRepository.getUserPosts(
        userId: userId,
        limit: limit,
      );
      return posts;
    } catch (e) {
      debugPrint('ForYouFeedBloc: Error getting user recent posts: $e');
      return [];
    }
  }

  /// Get an ad from AdService
  Future<AdFeedItem?> _getAd() async {
    if (_adService == null) return null;

    try {
      final ad = await _adService.loadNativeAd(cacheKey: 'feed_ad$_adCounter');
      if (ad != null) {
        _adCounter++;
        return AdFeedItem(ad: ad, cacheKey: 'feed_ad_${_adCounter - 1}');
      }
    } catch (e) {
      debugPrint('ForYouFeedBloc: Error loading ad: $e');
    }
    return null;
  }

  /// Get ad with timeout to prevent blocking feed load
  Future<AdFeedItem?> _getAdWithTimeout() async {
    try {
      return await _getAd().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint(
              'ForYouFeedBloc: Ad loading timed out, continuing without ad');
          return null;
        },
      );
    } catch (e) {
      debugPrint('ForYouFeedBloc: Error in ad timeout handler: $e');
      return null;
    }
  }

  /// Get friend suggestions based on user interests
  Future<List<UserModel>> _getFriendSuggestions(String userId,
      {int limit = 5}) async {
    if (_userRepository == null) return [];

    try {
      // Get current user to access their interests and friends list
      final currentUser = await _userRepository.getUser(userId);

      // Get recommended users based on interests
      if (currentUser.interests.isNotEmpty) {
        final recommendedDocs = await _userRepository.getRecommendedUsers(
          currentUser.interests,
          userId,
        );

        // Filter out already friends and convert to UserModel
        final suggestions = recommendedDocs
            .where((doc) => !currentUser.friends.contains(doc.id))
            .take(limit)
            .map((doc) => UserModel.fromDoc(doc))
            .toList();

        return suggestions;
      }

      // If no interests, try to get users not in friends list
      // Note: This requires accessing FirebaseFirestore, which UserRepository doesn't expose
      // For now, return empty list if no interests
      return [];
    } catch (e) {
      debugPrint('ForYouFeedBloc: Error getting friend suggestions: $e');
      return [];
    }
  }

  /// Safe wrapper for trending posts to catch errors
  Future<List<PostModel>> _safeGetTrendingPosts(TimeFilter timeFilter) async {
    try {
      return await _postRepository
          .getTrendingPosts(
        timeFilter: timeFilter,
        lastDocument: _lastDocument,
        limit: 10,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('ForYouFeedBloc: Trending posts query timed out');
          return <PostModel>[];
        },
      );
    } catch (e) {
      debugPrint('ForYouFeedBloc: Error getting trending posts: $e');
      return [];
    }
  }

  /// Safe wrapper for boosted posts to catch errors
  Future<List<PostModel>> _safeGetBoostedPosts(
      Map<String, dynamic> userTargeting) async {
    try {
      return await _postRepository
          .getBoostedPosts(
        userTargeting: userTargeting,
        limit: 3,
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('ForYouFeedBloc: Boosted posts query timed out');
          return <PostModel>[];
        },
      );
    } catch (e) {
      debugPrint('ForYouFeedBloc: Error getting boosted posts: $e');
      return [];
    }
  }

  /// Client-Side Ranking Plan: Calculate content weight based on post type
  /// Uses contentType enum (which has a default value, so switch is exhaustive)
  double _calculateContentWeight(PostModel post) {
    // Use contentType enum (has default value of PostContentType.text)
    switch (post.contentType) {
      case PostContentType.text:
        return 1.0;
      case PostContentType.image:
        return 1.2;
      case PostContentType.video:
        return 1.5;
      case PostContentType.link:
        return 1.3;
      case PostContentType.poll:
        return 1.1;
      case PostContentType.mixed:
        return 1.4;
    }
  }

  /// Client-Side Ranking Plan: Calculate time decay using exponential decay formula
  /// Formula: e^(-0.1 * hoursSinceCreation)
  /// After 24 hours: ~0.08
  /// After 48 hours: ~0.006
  /// After 72 hours: ~0.0005
  double _calculateTimeDecay(DateTime postTimestamp) {
    final now = DateTime.now();
    final hoursSinceCreation = now.difference(postTimestamp).inHours.toDouble();

    // Exponential decay: e^(-0.1 * hours)
    return math.exp(-0.1 * hoursSinceCreation);
  }
}
