// lib/blocs/reels_feed/reels_feed_event.dart

import 'package:equatable/equatable.dart';

abstract class ReelsFeedEvent extends Equatable {
  const ReelsFeedEvent();

  @override
  List<Object?> get props => [];
}

class LoadReelsFeed extends ReelsFeedEvent {
  const LoadReelsFeed();
}

class LoadMoreReels extends ReelsFeedEvent {
  const LoadMoreReels();
}

class PlayReel extends ReelsFeedEvent {
  final String reelId;

  const PlayReel(this.reelId);

  @override
  List<Object?> get props => [reelId];
}

class PauseReel extends ReelsFeedEvent {
  final String reelId;

  const PauseReel(this.reelId);

  @override
  List<Object?> get props => [reelId];
}

class LikeReel extends ReelsFeedEvent {
  final String reelId;

  const LikeReel(this.reelId);

  @override
  List<Object?> get props => [reelId];
}

class UnlikeReel extends ReelsFeedEvent {
  final String reelId;

  const UnlikeReel(this.reelId);

  @override
  List<Object?> get props => [reelId];
}

class ShareReel extends ReelsFeedEvent {
  final String reelId;

  const ShareReel(this.reelId);

  @override
  List<Object?> get props => [reelId];
}

class ViewReel extends ReelsFeedEvent {
  final String reelId;

  const ViewReel(this.reelId);

  @override
  List<Object?> get props => [reelId];
}

class RefreshReelsFeed extends ReelsFeedEvent {
  const RefreshReelsFeed();
}

class LoadMyReels extends ReelsFeedEvent {
  final String userId;
  const LoadMyReels(this.userId);

  @override
  List<Object> get props => [userId];
}

/// Record watch time for a reel
class RecordWatchTime extends ReelsFeedEvent {
  final String reelId;
  final double watchTime; // seconds
  final double watchPercentage; // 0-100

  const RecordWatchTime({
    required this.reelId,
    required this.watchTime,
    required this.watchPercentage,
  });

  @override
  List<Object> get props => [reelId, watchTime, watchPercentage];
}

/// Mark reel as completed (watched >95%)
class MarkReelCompleted extends ReelsFeedEvent {
  final String reelId;

  const MarkReelCompleted(this.reelId);

  @override
  List<Object> get props => [reelId];
}

/// Mark reel as skipped (swiped away <3 seconds)
class MarkReelSkipped extends ReelsFeedEvent {
  final String reelId;

  const MarkReelSkipped(this.reelId);

  @override
  List<Object> get props => [reelId];
}

/// User marked reel/creator as not interested
class MarkNotInterested extends ReelsFeedEvent {
  final String reelId;
  final String creatorId;

  const MarkNotInterested({
    required this.reelId,
    required this.creatorId,
  });

  @override
  List<Object> get props => [reelId, creatorId];
}
