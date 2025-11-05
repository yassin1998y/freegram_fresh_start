// lib/blocs/search_bloc.dart

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/models/page_model.dart';
import 'package:freegram/repositories/search_repository.dart';
import 'package:freegram/repositories/post_repository.dart';

// Events
abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class SearchQueryChanged extends SearchEvent {
  final String query;

  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class ClearSearchHistory extends SearchEvent {
  const ClearSearchHistory();
}

// States
abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {
  final List<String> recentSearches;
  final List<String> trendingHashtags;

  const SearchInitial({
    this.recentSearches = const [],
    this.trendingHashtags = const [],
  });

  @override
  List<Object?> get props => [recentSearches, trendingHashtags];
}

class SearchLoading extends SearchState {
  const SearchLoading();
}

class SearchResultsLoaded extends SearchState {
  final List<PostModel> posts;
  final List<UserModel> users;
  final List<PageModel> pages;
  final List<PostModel> hashtags; // Posts with matching hashtags
  final String query;

  const SearchResultsLoaded({
    required this.posts,
    required this.users,
    required this.pages,
    required this.hashtags,
    required this.query,
  });

  @override
  List<Object?> get props => [posts, users, pages, hashtags, query];

  bool get hasResults =>
      posts.isNotEmpty ||
      users.isNotEmpty ||
      pages.isNotEmpty ||
      hashtags.isNotEmpty;
}

class SearchError extends SearchState {
  final String message;

  const SearchError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchRepository _searchRepository;
  final PostRepository _postRepository;
  final FirebaseAuth _auth;
  Timer? _debounceTimer;

  SearchBloc({
    required SearchRepository searchRepository,
    required PostRepository postRepository,
    FirebaseAuth? auth,
  })  : _searchRepository = searchRepository,
        _postRepository = postRepository,
        _auth = auth ?? FirebaseAuth.instance,
        super(const SearchInitial()) {
    on<SearchQueryChanged>(_onSearchQueryChanged);
    on<ClearSearchHistory>(_onClearSearchHistory);

    // Load initial data (recent searches and trending hashtags)
    _loadInitialData();
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }

  /// Load initial data for SearchInitial state
  Future<void> _loadInitialData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return; // Can't load user-specific data without auth
      }

      // Load recent searches and trending hashtags in parallel
      final results = await Future.wait([
        _searchRepository.getRecentSearches(user.uid),
        _postRepository.getTrendingHashtags(),
      ]);

      final recentSearches = List<String>.from(results[0]);
      final trendingHashtags = List<String>.from(results[1]);

      // ignore: invalid_use_of_visible_for_testing_member
      emit(SearchInitial(
        recentSearches: recentSearches,
        trendingHashtags: trendingHashtags,
      ));
    } catch (e) {
      debugPrint('SearchBloc: Error loading initial data: $e');
      // Still emit initial state even if loading fails
      // ignore: invalid_use_of_visible_for_testing_member
      emit(const SearchInitial());
    }
  }

  Future<void> _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    final query = event.query.trim();

    // If query is empty, return to initial state
    if (query.isEmpty) {
      await _loadInitialData();
      return;
    }

    // Debounce: wait 300ms before actually searching
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query, emit);
    });
  }

  Future<void> _performSearch(
    String query,
    Emitter<SearchState> emit,
  ) async {
    emit(const SearchLoading());

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Save search query to history (fire and forget)
        _searchRepository.saveSearch(user.uid, query).catchError((e) {
          debugPrint('SearchBloc: Error saving search: $e');
        });
      }

      // Perform all searches in parallel
      final results = await Future.wait([
        _searchRepository.searchPosts(query),
        _searchRepository.searchUsers(query),
        _searchRepository.searchPages(query),
        _searchRepository.searchHashtags(query),
      ]);

      final posts = List<PostModel>.from(results[0]);
      final users = List<UserModel>.from(results[1]);
      final pages = List<PageModel>.from(results[2]);
      final hashtags = List<PostModel>.from(results[3]);

      emit(SearchResultsLoaded(
        posts: posts,
        users: users,
        pages: pages,
        hashtags: hashtags,
        query: query,
      ));
    } catch (e) {
      debugPrint('SearchBloc: Error performing search: $e');
      emit(SearchError(e.toString()));
    }
  }

  Future<void> _onClearSearchHistory(
    ClearSearchHistory event,
    Emitter<SearchState> emit,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        emit(const SearchError('User not authenticated'));
        return;
      }

      await _searchRepository.clearSearchHistory(user.uid);

      // Reload initial data to update recent searches
      await _loadInitialData();
    } catch (e) {
      debugPrint('SearchBloc: Error clearing search history: $e');
      emit(SearchError(e.toString()));
    }
  }
}
