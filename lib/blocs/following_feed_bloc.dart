// lib/blocs/following_feed_bloc.dart
//
// DEPRECATED: This BLoC is deprecated in favor of UnifiedFeedBloc.
// UnifiedFeedBloc provides unified feed with score-based sorting.
//
// This file is kept for backward compatibility with FollowingFeedTab.
// TODO: Consider migrating FollowingFeedTab to use UnifiedFeedBloc.

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/page_repository.dart';

// Events
abstract class FollowingFeedEvent extends Equatable {
  const FollowingFeedEvent();

  @override
  List<Object?> get props => [];
}

class LoadFollowingFeedEvent extends FollowingFeedEvent {
  final String userId;
  final bool refresh;

  const LoadFollowingFeedEvent({
    required this.userId,
    this.refresh = false,
  });

  @override
  List<Object?> get props => [userId, refresh];
}

class LoadMoreFollowingFeedEvent extends FollowingFeedEvent {
  final String userId;

  const LoadMoreFollowingFeedEvent({required this.userId});

  @override
  List<Object?> get props => [userId];
}

// States
abstract class FollowingFeedState extends Equatable {
  const FollowingFeedState();

  @override
  List<Object?> get props => [];
}

class FollowingFeedInitial extends FollowingFeedState {
  const FollowingFeedInitial();
}

class FollowingFeedLoading extends FollowingFeedState {
  const FollowingFeedLoading();
}

class FollowingFeedLoaded extends FollowingFeedState {
  final List<PostFeedItem> posts;
  final bool hasMore;
  final bool isLoadingMore;
  final DocumentSnapshot? lastDocument;

  const FollowingFeedLoaded({
    required this.posts,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.lastDocument,
  });

  FollowingFeedLoaded copyWith({
    List<PostFeedItem>? posts,
    bool? hasMore,
    bool? isLoadingMore,
    DocumentSnapshot? lastDocument,
  }) {
    return FollowingFeedLoaded(
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastDocument: lastDocument ?? this.lastDocument,
    );
  }

  @override
  List<Object?> get props => [posts, hasMore, isLoadingMore, lastDocument];
}

class FollowingFeedError extends FollowingFeedState {
  final String error;

  const FollowingFeedError(this.error);

  @override
  List<Object?> get props => [error];
}

// BLoC
@Deprecated('Use UnifiedFeedBloc instead. This BLoC uses outdated feed logic.')
class FollowingFeedBloc extends Bloc<FollowingFeedEvent, FollowingFeedState> {
  final PostRepository _postRepository;
  final PageRepository? _pageRepository;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;

  FollowingFeedBloc({
    required PostRepository postRepository,
    PageRepository? pageRepository,
  })  : _postRepository = postRepository,
        _pageRepository = pageRepository,
        super(const FollowingFeedInitial()) {
    on<LoadFollowingFeedEvent>(_onLoadFollowingFeed);
    on<LoadMoreFollowingFeedEvent>(_onLoadMoreFollowingFeed);
  }

  Future<void> _onLoadFollowingFeed(
    LoadFollowingFeedEvent event,
    Emitter<FollowingFeedState> emit,
  ) async {
    // Phase 4: Reset pagination when refresh is requested
    if (event.refresh) {
      _lastDocument = null;
      _hasMore = true;
      emit(const FollowingFeedLoading());
    } else {
      // For non-refresh loads, show loading more indicator if already loaded
      if (state is FollowingFeedLoaded) {
        final currentState = state as FollowingFeedLoaded;
        emit(currentState.copyWith(isLoadingMore: true));
      } else {
        emit(const FollowingFeedLoading());
      }
    }

    try {
      // Phase 4: Fetch from network (not cache) when refreshing
      // Reset lastDocument to null to ensure we get fresh data
      final result = await _postRepository.getFeedForUserWithPagination(
        userId: event.userId,
        lastDocument: event.refresh ? null : _lastDocument,
        limit: 10,
      );

      var posts = result.$1;
      var lastDoc = result.$2;

      // NOTE: User's own posts are now handled by UnifiedFeedBloc's getUnifiedFeed() method
      // which ensures they appear at the top. This duplicate logic is kept for backward
      // compatibility but can be removed if FollowingFeedTab is migrated to UnifiedFeedBloc.
      //
      // For now, we still check for user's own recent posts here to ensure they appear
      // in the Following feed tab (if it's still using this BLoC).
      try {
        final userRecentPosts = await _postRepository.getUserPosts(
          userId: event.userId,
          limit: 1,
        );
        if (userRecentPosts.isNotEmpty) {
          final mostRecent = userRecentPosts.first;
          final ageInMinutes =
              DateTime.now().difference(mostRecent.timestamp).inMinutes;

          // If post is less than 5 minutes old and not already in feed
          if (ageInMinutes < 5 && !posts.any((p) => p.id == mostRecent.id)) {
            // Prepend to the beginning of the feed
            posts.insert(0, mostRecent);
            debugPrint(
                'FollowingFeedBloc: Added user\'s recent post to top of feed (${ageInMinutes} minutes old)');
          }
        }
      } catch (e) {
        debugPrint('FollowingFeedBloc: Error checking user\'s recent post: $e');
        // Continue with regular feed - this is not critical
      }

      // Also get posts from followed pages and mix them in
      if (_pageRepository != null) {
        try {
          final pagePosts = await _pageRepository.getPageFeed(
            userId: event.userId,
            limit: 5, // Get fewer page posts to mix in
          );
          // Mix page posts into regular feed (maintain chronological order)
          posts = _mixPagePosts(posts, pagePosts);
        } catch (e) {
          debugPrint('FollowingFeedBloc: Error getting page feed: $e');
          // Continue with regular posts only
        }
      }

      _lastDocument = lastDoc;
      _hasMore = posts.length == 10; // Assuming limit is 10

      // Map to PostFeedItem with correct display type
      final postItems = posts.map((post) {
        return PostFeedItem(
          post: post,
          displayType: post.pageId != null
              ? PostDisplayType.page
              : PostDisplayType.organic,
        );
      }).toList();

      // Phase 4: Replace list when refreshing, append when loading more
      if (event.refresh) {
        // Replace the entire list with fresh data
        emit(FollowingFeedLoaded(
          posts: postItems,
          hasMore: _hasMore,
          lastDocument: _lastDocument,
        ));
      } else {
        // Append to existing list (for infinite scroll)
        final currentState = state;
        if (currentState is FollowingFeedLoaded) {
          emit(currentState.copyWith(
            posts: [...currentState.posts, ...postItems],
            hasMore: _hasMore,
            isLoadingMore: false,
            lastDocument: _lastDocument,
          ));
        } else {
          // First load
          emit(FollowingFeedLoaded(
            posts: postItems,
            hasMore: _hasMore,
            lastDocument: _lastDocument,
          ));
        }
      }
    } catch (e) {
      debugPrint('FollowingFeedBloc: Error loading feed: $e');
      emit(FollowingFeedError(e.toString()));
    }
  }

  Future<void> _onLoadMoreFollowingFeed(
    LoadMoreFollowingFeedEvent event,
    Emitter<FollowingFeedState> emit,
  ) async {
    if (state is FollowingFeedLoaded) {
      final currentState = state as FollowingFeedLoaded;
      if (!currentState.hasMore || currentState.isLoadingMore) return;

      emit(currentState.copyWith(isLoadingMore: true));

      try {
        // Get more posts
        final result = await _postRepository.getFeedForUserWithPagination(
          userId: event.userId,
          lastDocument: _lastDocument,
          limit: 10,
        );

        var morePosts = result.$1;
        var lastDoc = result.$2;

        // Get more page posts if available
        if (_pageRepository != null && morePosts.length < 10) {
          try {
            final pagePosts = await _pageRepository.getPageFeed(
              userId: event.userId,
              lastDocument:
                  _lastDocument, // Note: PageRepository may need pagination support
              limit: 5,
            );
            morePosts = _mixPagePosts(morePosts, pagePosts);
          } catch (e) {
            debugPrint('FollowingFeedBloc: Error loading more page posts: $e');
          }
        }

        _lastDocument = lastDoc;
        _hasMore = morePosts.length == 10;

        // Map to PostFeedItem
        final morePostItems = morePosts.map((post) {
          return PostFeedItem(
            post: post,
            displayType: post.pageId != null
                ? PostDisplayType.page
                : PostDisplayType.organic,
          );
        }).toList();

        emit(currentState.copyWith(
          posts: [...currentState.posts, ...morePostItems],
          hasMore: _hasMore,
          isLoadingMore: false,
          lastDocument: _lastDocument,
        ));
      } catch (e) {
        debugPrint('FollowingFeedBloc: Error loading more feed: $e');
        emit(currentState.copyWith(isLoadingMore: false));
        emit(FollowingFeedError(e.toString()));
      }
    }
  }

  /// Mix page posts into regular posts, maintaining chronological order
  ///
  /// NOTE: This simple mixing logic is kept for FollowingFeedTab compatibility.
  /// UnifiedFeedBloc uses FeedScoringService for more sophisticated sorting
  /// that handles page posts, boosted posts, trending posts, etc. in a unified way.
  List<PostModel> _mixPagePosts(
    List<PostModel> regularPosts,
    List<PostModel> pagePosts,
  ) {
    // Combine and sort by timestamp (most recent first)
    final allPosts = [...regularPosts, ...pagePosts];
    allPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allPosts;
  }
}
