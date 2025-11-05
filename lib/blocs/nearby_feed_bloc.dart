// lib/blocs/nearby_feed_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/utils/enums.dart';

// Events
abstract class NearbyFeedEvent extends Equatable {
  const NearbyFeedEvent();

  @override
  List<Object?> get props => [];
}

class LoadNearbyFeedEvent extends NearbyFeedEvent {
  final String userId;
  final bool refresh;

  const LoadNearbyFeedEvent({
    required this.userId,
    this.refresh = false,
  });

  @override
  List<Object?> get props => [userId, refresh];
}

class LoadMoreNearbyFeedEvent extends NearbyFeedEvent {
  final String userId;

  const LoadMoreNearbyFeedEvent({required this.userId});

  @override
  List<Object?> get props => [userId];
}

// States
abstract class NearbyFeedState extends Equatable {
  const NearbyFeedState();

  @override
  List<Object?> get props => [];
}

class NearbyFeedInitial extends NearbyFeedState {
  const NearbyFeedInitial();
}

class NearbyFeedLoading extends NearbyFeedState {
  const NearbyFeedLoading();
}

class NearbyFeedLoaded extends NearbyFeedState {
  final List<FeedItem> items;
  final List<PostFeedItem> nearbyTrending;
  final List<PostFeedItem> nearbyReels;
  final bool isLoading;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;

  const NearbyFeedLoaded({
    required this.items,
    required this.nearbyTrending,
    required this.nearbyReels,
    this.isLoading = false,
    required this.hasMore,
    this.lastDocument,
  });

  @override
  List<Object?> get props =>
      [items, nearbyTrending, nearbyReels, isLoading, hasMore];
}

class NearbyFeedError extends NearbyFeedState {
  final String error;

  const NearbyFeedError(this.error);

  @override
  List<Object?> get props => [error];
}

// BLoC
class NearbyFeedBloc extends Bloc<NearbyFeedEvent, NearbyFeedState> {
  final PostRepository _postRepository;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;

  NearbyFeedBloc({
    required PostRepository postRepository,
  })  : _postRepository = postRepository,
        super(const NearbyFeedInitial()) {
    on<LoadNearbyFeedEvent>(_onLoadNearbyFeed);
    on<LoadMoreNearbyFeedEvent>(_onLoadMoreNearbyFeed);
  }

  Future<void> _onLoadNearbyFeed(
    LoadNearbyFeedEvent event,
    Emitter<NearbyFeedState> emit,
  ) async {
    if (event.refresh) {
      _lastDocument = null;
      _hasMore = true;
    }

    emit(const NearbyFeedLoading());

    try {
      // Get nearby posts, nearby trending, and nearby reels
      final results = await Future.wait([
        _getNearbyPosts(event.userId, limit: 10),
        _getNearbyTrending(event.userId, limit: 5),
        _getNearbyReels(event.userId, limit: 5),
      ]);

      final nearbyPosts = results[0] as List<PostModel>;
      final nearbyTrendingPosts = results[1] as List<PostModel>;
      final nearbyReelsPosts = results[2] as List<PostModel>;

      // Update hasMore
      _hasMore = nearbyPosts.length == 10;

      // Convert to FeedItems
      final feedItems = nearbyPosts
          .map((p) => PostFeedItem(
                post: p,
                displayType: PostDisplayType.nearby,
              ))
          .toList();

      final trendingItems = nearbyTrendingPosts
          .map((p) => PostFeedItem(
                post: p,
                displayType: PostDisplayType.trending,
              ))
          .toList();

      final reelsItems = nearbyReelsPosts
          .map((p) => PostFeedItem(
                post: p,
                displayType: PostDisplayType
                    .organic, // Reels don't have special display type
              ))
          .toList();

      emit(NearbyFeedLoaded(
        items: feedItems,
        nearbyTrending: trendingItems,
        nearbyReels: reelsItems,
        isLoading: false,
        hasMore: _hasMore,
        lastDocument: _lastDocument,
      ));
    } catch (e) {
      debugPrint('NearbyFeedBloc: Error loading feed: $e');
      emit(NearbyFeedError(e.toString()));
    }
  }

  Future<void> _onLoadMoreNearbyFeed(
    LoadMoreNearbyFeedEvent event,
    Emitter<NearbyFeedState> emit,
  ) async {
    if (!_hasMore || state is! NearbyFeedLoaded) return;

    final currentState = state as NearbyFeedLoaded;
    emit(currentState.copyWith(isLoading: true));

    try {
      final nearbyPosts = await _getNearbyPosts(
        event.userId,
        limit: 10,
        lastDocument: _lastDocument,
      );

      _hasMore = nearbyPosts.length == 10;

      final newItems = nearbyPosts
          .map((p) => PostFeedItem(
                post: p,
                displayType: PostDisplayType.nearby,
              ))
          .toList();

      emit(currentState.copyWith(
        items: [...currentState.items, ...newItems],
        isLoading: false,
        hasMore: _hasMore,
        lastDocument: _lastDocument,
      ));
    } catch (e) {
      debugPrint('NearbyFeedBloc: Error loading more: $e');
      emit(currentState.copyWith(isLoading: false));
    }
  }

  /// Get nearby posts
  Future<List<PostModel>> _getNearbyPosts(
    String userId, {
    int limit = 10,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      // TODO: Implement actual nearby posts query with location
      // For now, return public posts as fallback
      final posts = await _postRepository.getFeedForUser(
        userId: userId,
        lastDocument: lastDocument,
        limit: limit,
      );
      return posts;
    } catch (e) {
      debugPrint('NearbyFeedBloc: Error getting nearby posts: $e');
      return [];
    }
  }

  /// Get nearby trending posts
  Future<List<PostModel>> _getNearbyTrending(
    String userId, {
    int limit = 5,
  }) async {
    try {
      // Get trending posts filtered by location if available
      // For now, return regular trending posts
      final posts = await _postRepository.getTrendingPosts(
        timeFilter: TimeFilter.today,
        limit: limit,
      );
      return posts;
    } catch (e) {
      debugPrint('NearbyFeedBloc: Error getting nearby trending: $e');
      return [];
    }
  }

  /// Get nearby reels (video posts)
  Future<List<PostModel>> _getNearbyReels(
    String userId, {
    int limit = 5,
  }) async {
    try {
      // TODO: Filter by video media type and location
      // For now, return regular posts as placeholder
      final posts = await _postRepository.getFeedForUser(
        userId: userId,
        limit: limit,
      );
      // Filter for posts with video media (reels)
      return posts
          .where((p) =>
              p.postType == PostType.video || p.postType == PostType.mixed)
          .toList();
    } catch (e) {
      debugPrint('NearbyFeedBloc: Error getting nearby reels: $e');
      return [];
    }
  }
}

// Helper extension for copyWith
extension NearbyFeedLoadedCopyWith on NearbyFeedLoaded {
  NearbyFeedLoaded copyWith({
    List<FeedItem>? items,
    List<PostFeedItem>? nearbyTrending,
    List<PostFeedItem>? nearbyReels,
    bool? isLoading,
    bool? hasMore,
    DocumentSnapshot? lastDocument,
  }) {
    return NearbyFeedLoaded(
      items: items ?? this.items,
      nearbyTrending: nearbyTrending ?? this.nearbyTrending,
      nearbyReels: nearbyReels ?? this.nearbyReels,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastDocument: lastDocument ?? this.lastDocument,
    );
  }
}
