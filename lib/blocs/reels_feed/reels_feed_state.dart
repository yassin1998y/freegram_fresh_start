// lib/blocs/reels_feed/reels_feed_state.dart

import 'package:equatable/equatable.dart';
import 'package:freegram/models/reel_model.dart';

abstract class ReelsFeedState extends Equatable {
  const ReelsFeedState();

  @override
  List<Object?> get props => [];
}

class ReelsFeedInitial extends ReelsFeedState {
  const ReelsFeedInitial();
}

class ReelsFeedLoading extends ReelsFeedState {
  const ReelsFeedLoading();
}

class ReelsFeedLoaded extends ReelsFeedState {
  final List<ReelModel> reels;
  final String? currentPlayingReelId;
  final bool hasMore;
  final bool isLoadingMore;

  const ReelsFeedLoaded({
    required this.reels,
    this.currentPlayingReelId,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  ReelsFeedLoaded copyWith({
    List<ReelModel>? reels,
    String? currentPlayingReelId,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ReelsFeedLoaded(
      reels: reels ?? this.reels,
      currentPlayingReelId: currentPlayingReelId ?? this.currentPlayingReelId,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [reels, currentPlayingReelId, hasMore, isLoadingMore];
}

class ReelsFeedError extends ReelsFeedState {
  final String message;

  const ReelsFeedError(this.message);

  @override
  List<Object?> get props => [message];
}

