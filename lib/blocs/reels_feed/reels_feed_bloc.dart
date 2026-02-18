// lib/blocs/reels_feed/reels_feed_bloc.dart

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_event.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_state.dart';
import 'package:freegram/models/reel_interaction_model.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/repositories/reel_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/services/reels_scoring_service.dart';
import 'package:freegram/utils/reels_feed_diversifier.dart';
import 'package:freegram/services/global_cache_coordinator.dart';
import 'package:flutter/services.dart';

class ReelsFeedBloc extends Bloc<ReelsFeedEvent, ReelsFeedState> {
  final ReelRepository _reelRepository;
  final UserRepository? _userRepository;
  final ReelsScoringService? _scoringService;
  final GlobalCacheCoordinator _globalCacheCoordinator;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 20;
  static const int _scoringBatchSize = 50; // Fetch more for scoring

  // Feature flag for personalized feed
  final bool usePersonalizedFeed;

  // Cache for scoring
  final Map<String, double> _creatorAffinityCache = {};
  final Map<String, int> _creatorFrequency = {};

  ReelsFeedBloc({
    required ReelRepository reelRepository,
    UserRepository? userRepository,
    ReelsScoringService? scoringService,
    GlobalCacheCoordinator? globalCacheCoordinator,
    this.usePersonalizedFeed = true, // Enable by default
  })  : _reelRepository = reelRepository,
        _userRepository = userRepository,
        _scoringService = scoringService,
        _globalCacheCoordinator =
            globalCacheCoordinator ?? GlobalCacheCoordinator(),
        super(const ReelsFeedInitial()) {
    _globalCacheCoordinator.init();
    on<LoadReelsFeed>(_onLoadReelsFeed);
    on<LoadMoreReels>(_onLoadMoreReels);
    on<PlayReel>(_onPlayReel);
    on<PauseReel>(_onPauseReel);
    on<LikeReel>(_onLikeReel);
    on<UnlikeReel>(_onUnlikeReel);
    on<ShareReel>(_onShareReel);
    on<ViewReel>(_onViewReel);
    on<RefreshReelsFeed>(_onRefreshReelsFeed);
    on<LoadMyReels>(_onLoadMyReels);
    on<RecordWatchTime>(_onRecordWatchTime);
    on<MarkReelCompleted>(_onMarkReelCompleted);
    on<MarkReelSkipped>(_onMarkReelSkipped);
    on<MarkNotInterested>(_onMarkNotInterested);
  }

  Future<void> _onLoadReelsFeed(
    LoadReelsFeed event,
    Emitter<ReelsFeedState> emit,
  ) async {
    emit(const ReelsFeedLoading());

    // SWR: Try to load from cache first
    try {
      final cachedReels =
          await _globalCacheCoordinator.getCachedItems<ReelModel>();
      if (cachedReels.isNotEmpty) {
        emit(ReelsFeedLoaded(
          reels: cachedReels,
          currentPlayingReelId: cachedReels.first.reelId,
          hasMore: false,
        ));
        // Trigger HapticFeedback.lightImpact() as requested
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error loading from global cache: $e');
    }

    try {
      _lastDocument = null;
      _creatorAffinityCache.clear();
      _creatorFrequency.clear();

      List<ReelModel> reels;

      // Use personalized feed if enabled and dependencies available
      if (usePersonalizedFeed &&
          _userRepository != null &&
          _scoringService != null) {
        reels = await _loadPersonalizedFeed();
      } else {
        // Fallback to chronological feed
        reels = await _reelRepository.getReelsFeed(limit: _pageSize);
      }

      if (reels.isEmpty) {
        emit(const ReelsFeedLoaded(
          reels: [],
          hasMore: false,
        ));
        return;
      }

      // Auto-play first reel
      if (reels.isNotEmpty) {
        await _incrementViewCount(reels.first.reelId);
      }

      _lastDocument = await _getLastDocument(reels);

      // Cache the fresh reels
      try {
        await _globalCacheCoordinator.cacheItems<ReelModel>(reels);
        debugPrint('ReelsFeedBloc: Cached ${reels.length} reels');
      } catch (e) {
        debugPrint('ReelsFeedBloc: Error caching reels: $e');
      }

      emit(ReelsFeedLoaded(
        reels: reels,
        currentPlayingReelId: reels.isNotEmpty ? reels.first.reelId : null,
        hasMore: reels.length == _pageSize,
      ));
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error loading reels feed: $e');

      // Fallback to cache if strictly necessary and we failed to load fresh
      // (Though with SWR we might have already emitted cached content,
      // but if an error occurred we might want to ensure we stay on cached content or show error)
      // If we already emitted cached content, we might already be in a Loaded state visually,
      // but this catch block intercepts the flow.
      // If we are here, it means fresh load failed.

      if (state is ReelsFeedLoaded &&
          (state as ReelsFeedLoaded).reels.isNotEmpty) {
        debugPrint('ReelsFeedBloc: Keeping cached content after error');
        // Start playing if not already
        if ((state as ReelsFeedLoaded).currentPlayingReelId == null) {
          emit((state as ReelsFeedLoaded).copyWith(
              currentPlayingReelId:
                  (state as ReelsFeedLoaded).reels.first.reelId));
        }
      } else {
        // If we have nothing, try cache again (redundant maybe but safe)
        try {
          final cachedReels =
              await _globalCacheCoordinator.getCachedItems<ReelModel>();
          if (cachedReels.isNotEmpty) {
            emit(ReelsFeedLoaded(
              reels: cachedReels,
              currentPlayingReelId: cachedReels.first.reelId,
              hasMore: false,
            ));
            return;
          }
        } catch (_) {}

        emit(ReelsFeedError(e.toString()));
      }
    }
  }

  Future<void> _onLoadMoreReels(
    LoadMoreReels event,
    Emitter<ReelsFeedState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ReelsFeedLoaded ||
        currentState.isLoadingMore ||
        !currentState.hasMore) {
      return;
    }

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final moreReels = await _reelRepository.getReelsFeed(
        limit: _pageSize,
        lastDocument: _lastDocument,
      );

      if (moreReels.isEmpty) {
        emit(currentState.copyWith(
          hasMore: false,
          isLoadingMore: false,
        ));
        return;
      }

      _lastDocument = await _getLastDocument(moreReels);

      final updatedReels = [...currentState.reels, ...moreReels];

      emit(currentState.copyWith(
        reels: updatedReels,
        hasMore: moreReels.length == _pageSize,
        isLoadingMore: false,
      ));
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error loading more reels: $e');
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  void _onPlayReel(
    PlayReel event,
    Emitter<ReelsFeedState> emit,
  ) {
    final currentState = state;
    if (currentState is ReelsFeedLoaded) {
      emit(currentState.copyWith(currentPlayingReelId: event.reelId));
      _incrementViewCount(event.reelId);
    }
  }

  void _onPauseReel(
    PauseReel event,
    Emitter<ReelsFeedState> emit,
  ) {
    final currentState = state;
    if (currentState is ReelsFeedLoaded &&
        currentState.currentPlayingReelId == event.reelId) {
      emit(currentState.copyWith(currentPlayingReelId: null));
    }
  }

  Future<void> _onLikeReel(
    LikeReel event,
    Emitter<ReelsFeedState> emit,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final currentState = state;
    if (currentState is! ReelsFeedLoaded) return;

    try {
      await _reelRepository.likeReel(event.reelId, currentUser.uid);

      // Update local state optimistically
      final updatedReels = currentState.reels.map((reel) {
        if (reel.reelId == event.reelId) {
          return ReelModel(
            reelId: reel.reelId,
            uploaderId: reel.uploaderId,
            uploaderUsername: reel.uploaderUsername,
            uploaderAvatarUrl: reel.uploaderAvatarUrl,
            videoUrl: reel.videoUrl,
            thumbnailUrl: reel.thumbnailUrl,
            duration: reel.duration,
            caption: reel.caption,
            hashtags: reel.hashtags,
            mentions: reel.mentions,
            likeCount: reel.likeCount + 1,
            commentCount: reel.commentCount,
            shareCount: reel.shareCount,
            viewCount: reel.viewCount,
            createdAt: reel.createdAt,
            updatedAt: reel.updatedAt,
            isActive: reel.isActive,
            location: reel.location,
            audioTrack: reel.audioTrack,
          );
        }
        return reel;
      }).toList();

      emit(currentState.copyWith(reels: updatedReels));
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error liking reel: $e');
    }
  }

  Future<void> _onUnlikeReel(
    UnlikeReel event,
    Emitter<ReelsFeedState> emit,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final currentState = state;
    if (currentState is! ReelsFeedLoaded) return;

    try {
      await _reelRepository.unlikeReel(event.reelId, currentUser.uid);

      // Update local state optimistically
      final updatedReels = currentState.reels.map((reel) {
        if (reel.reelId == event.reelId) {
          return ReelModel(
            reelId: reel.reelId,
            uploaderId: reel.uploaderId,
            uploaderUsername: reel.uploaderUsername,
            uploaderAvatarUrl: reel.uploaderAvatarUrl,
            videoUrl: reel.videoUrl,
            thumbnailUrl: reel.thumbnailUrl,
            duration: reel.duration,
            caption: reel.caption,
            hashtags: reel.hashtags,
            mentions: reel.mentions,
            likeCount: (reel.likeCount - 1).clamp(0, double.infinity).toInt(),
            commentCount: reel.commentCount,
            shareCount: reel.shareCount,
            viewCount: reel.viewCount,
            createdAt: reel.createdAt,
            updatedAt: reel.updatedAt,
            isActive: reel.isActive,
            location: reel.location,
            audioTrack: reel.audioTrack,
          );
        }
        return reel;
      }).toList();

      emit(currentState.copyWith(reels: updatedReels));
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error unliking reel: $e');
    }
  }

  Future<void> _onShareReel(
    ShareReel event,
    Emitter<ReelsFeedState> emit,
  ) async {
    try {
      await _reelRepository.incrementShareCount(event.reelId);

      final currentState = state;
      if (currentState is ReelsFeedLoaded) {
        // Update local state optimistically
        final updatedReels = currentState.reels.map((reel) {
          if (reel.reelId == event.reelId) {
            return ReelModel(
              reelId: reel.reelId,
              uploaderId: reel.uploaderId,
              uploaderUsername: reel.uploaderUsername,
              uploaderAvatarUrl: reel.uploaderAvatarUrl,
              videoUrl: reel.videoUrl,
              thumbnailUrl: reel.thumbnailUrl,
              duration: reel.duration,
              caption: reel.caption,
              hashtags: reel.hashtags,
              mentions: reel.mentions,
              likeCount: reel.likeCount,
              commentCount: reel.commentCount,
              shareCount: reel.shareCount + 1,
              viewCount: reel.viewCount,
              createdAt: reel.createdAt,
              updatedAt: reel.updatedAt,
              isActive: reel.isActive,
              location: reel.location,
              audioTrack: reel.audioTrack,
            );
          }
          return reel;
        }).toList();

        emit(currentState.copyWith(reels: updatedReels));
      }
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error sharing reel: $e');
    }
  }

  Future<void> _onViewReel(
    ViewReel event,
    Emitter<ReelsFeedState> emit,
  ) async {
    await _incrementViewCount(event.reelId);
  }

  Future<void> _onRefreshReelsFeed(
    RefreshReelsFeed event,
    Emitter<ReelsFeedState> emit,
  ) async {
    add(const LoadReelsFeed());
  }

  Future<void> _onLoadMyReels(
    LoadMyReels event,
    Emitter<ReelsFeedState> emit,
  ) async {
    emit(const ReelsFeedLoading());

    try {
      final reels = await _reelRepository.getUserReels(event.userId);

      if (reels.isEmpty) {
        emit(const ReelsFeedLoaded(
          reels: [],
          hasMore: false,
        ));
        return;
      }

      emit(ReelsFeedLoaded(
        reels: reels,
        hasMore: false, // User reels don't need pagination for now
      ));
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error loading my reels: $e');
      emit(ReelsFeedError(e.toString()));
    }
  }

  Future<void> _incrementViewCount(String reelId) async {
    try {
      await _reelRepository.incrementViewCount(reelId);
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error incrementing view count: $e');
    }
  }

  Future<DocumentSnapshot?> _getLastDocument(List<ReelModel> reels) async {
    if (reels.isEmpty) return null;

    try {
      final lastReel = reels.last;
      final doc = await FirebaseFirestore.instance
          .collection('reels')
          .doc(lastReel.reelId)
          .get();
      return doc;
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error getting last document: $e');
      return null;
    }
  }

  /// Load personalized feed using scoring service
  Future<List<ReelModel>> _loadPersonalizedFeed() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null ||
        _userRepository == null ||
        _scoringService == null) {
      // Fallback to chronological
      return await _reelRepository.getReelsFeed(limit: _pageSize);
    }

    try {
      // Get user profile
      final user = await _userRepository.getUser(currentUser.uid);

      // Fetch larger batch for scoring
      final allReels = await _reelRepository.getPersonalizedReelsFeed(
        userId: currentUser.uid,
        limit: _scoringBatchSize,
      );

      if (allReels.isEmpty) return [];

      // Get not interested creators
      final notInterestedCreators =
          await _reelRepository.getNotInterestedCreators(currentUser.uid);

      // Filter out not interested content
      var filteredReels = ReelsFeedDiversifier.filterNotInterestedCreators(
        reels: allReels,
        notInterestedCreators: notInterestedCreators,
      );

      // Score all reels
      final scores = <String, ReelScore>{};
      for (final reel in filteredReels) {
        final score = await _scoringService.calculateScore(
          reel: reel,
          userId: currentUser.uid,
          user: user,
          creatorFrequency: _creatorFrequency,
          creatorAffinityCache: _creatorAffinityCache,
        );
        scores[reel.reelId] = score;
        _creatorFrequency[reel.uploaderId] =
            (_creatorFrequency[reel.uploaderId] ?? 0) + 1;
      }

      // Apply diversity rules and get top results
      final diversifiedReels = ReelsFeedDiversifier.diversifyFeed(
        reels: filteredReels,
        scores: scores,
        maxResults: _pageSize,
      );

      debugPrint(
          'ReelsFeedBloc: Loaded ${diversifiedReels.length} personalized reels');
      return diversifiedReels;
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error loading personalized feed: $e');
      // Fallback to chronological
      return await _reelRepository.getReelsFeed(limit: _pageSize);
    }
  }

  /// Record watch time for a reel
  Future<void> _onRecordWatchTime(
    RecordWatchTime event,
    Emitter<ReelsFeedState> emit,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final currentState = state;
    if (currentState is! ReelsFeedLoaded) return;

    try {
      // Find the reel to get creator ID
      final reel = currentState.reels.firstWhere(
        (r) => r.reelId == event.reelId,
        orElse: () => currentState.reels.first,
      );

      final interaction = ReelInteractionModel(
        userId: currentUser.uid,
        reelId: event.reelId,
        creatorId: reel.uploaderId,
        watchTime: event.watchTime,
        watchPercentage: event.watchPercentage,
        interactedAt: DateTime.now(),
      );

      await _reelRepository.recordReelInteraction(interaction);
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error recording watch time: $e');
    }
  }

  /// Mark reel as completed
  Future<void> _onMarkReelCompleted(
    MarkReelCompleted event,
    Emitter<ReelsFeedState> emit,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final currentState = state;
    if (currentState is! ReelsFeedLoaded) return;

    try {
      final reel = currentState.reels.firstWhere(
        (r) => r.reelId == event.reelId,
        orElse: () => currentState.reels.first,
      );

      final interaction = ReelInteractionModel(
        userId: currentUser.uid,
        reelId: event.reelId,
        creatorId: reel.uploaderId,
        completed: true,
        watchPercentage: 100.0,
        watchTime: reel.duration,
        interactedAt: DateTime.now(),
      );

      await _reelRepository.recordReelInteraction(interaction);
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error marking reel completed: $e');
    }
  }

  /// Mark reel as skipped
  Future<void> _onMarkReelSkipped(
    MarkReelSkipped event,
    Emitter<ReelsFeedState> emit,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final currentState = state;
    if (currentState is! ReelsFeedLoaded) return;

    try {
      final reel = currentState.reels.firstWhere(
        (r) => r.reelId == event.reelId,
        orElse: () => currentState.reels.first,
      );

      final interaction = ReelInteractionModel(
        userId: currentUser.uid,
        reelId: event.reelId,
        creatorId: reel.uploaderId,
        skipped: true,
        interactedAt: DateTime.now(),
      );

      await _reelRepository.recordReelInteraction(interaction);
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error marking reel skipped: $e');
    }
  }

  /// Mark content as not interested
  Future<void> _onMarkNotInterested(
    MarkNotInterested event,
    Emitter<ReelsFeedState> emit,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final currentState = state;
    if (currentState is! ReelsFeedLoaded) return;

    try {
      final interaction = ReelInteractionModel(
        userId: currentUser.uid,
        reelId: event.reelId,
        creatorId: event.creatorId,
        notInterested: true,
        interactedAt: DateTime.now(),
      );

      await _reelRepository.recordReelInteraction(interaction);

      // Remove reels from this creator from current feed
      final filteredReels = currentState.reels
          .where((reel) => reel.uploaderId != event.creatorId)
          .toList();

      emit(currentState.copyWith(reels: filteredReels));
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error marking not interested: $e');
    }
  }
}
