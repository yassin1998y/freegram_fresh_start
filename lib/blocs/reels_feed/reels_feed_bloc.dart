// lib/blocs/reels_feed/reels_feed_bloc.dart

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_event.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_state.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/repositories/reel_repository.dart';

class ReelsFeedBloc extends Bloc<ReelsFeedEvent, ReelsFeedState> {
  final ReelRepository _reelRepository;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 20;

  ReelsFeedBloc({
    required ReelRepository reelRepository,
  })  : _reelRepository = reelRepository,
        super(const ReelsFeedInitial()) {
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
  }

  Future<void> _onLoadReelsFeed(
    LoadReelsFeed event,
    Emitter<ReelsFeedState> emit,
  ) async {
    emit(const ReelsFeedLoading());

    try {
      _lastDocument = null;
      final reels = await _reelRepository.getReelsFeed(limit: _pageSize);

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

      emit(ReelsFeedLoaded(
        reels: reels,
        currentPlayingReelId: reels.isNotEmpty ? reels.first.reelId : null,
        hasMore: reels.length == _pageSize,
      ));
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error loading reels feed: $e');
      emit(ReelsFeedError(e.toString()));
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
}

