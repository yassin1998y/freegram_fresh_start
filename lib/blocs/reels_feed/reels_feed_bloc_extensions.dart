// lib/blocs/reels_feed/reels_feed_bloc_extensions.dart

import 'package:flutter/foundation.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_bloc.dart';
import 'package:freegram/repositories/reel_repository.dart';
import 'package:freegram/models/reel_interaction_model.dart';

/// Extension methods for ReelsFeedBloc to handle new interaction events
extension ReelsFeedBlocInteractions on ReelsFeedBloc {
  /// Record watch time for a reel
  Future<void> recordWatchTime({
    required String userId,
    required String reelId,
    required String creatorId,
    required double watchTime,
    required double watchPercentage,
    required ReelRepository repository,
  }) async {
    try {
      final interaction = ReelInteractionModel(
        userId: userId,
        reelId: reelId,
        creatorId: creatorId,
        watchTime: watchTime,
        watchPercentage: watchPercentage,
        interactedAt: DateTime.now(),
      );

      await repository.recordReelInteraction(interaction);
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error recording watch time: $e');
    }
  }

  /// Mark reel as completed
  Future<void> markReelCompleted({
    required String userId,
    required String reelId,
    required String creatorId,
    required double duration,
    required ReelRepository repository,
  }) async {
    try {
      final interaction = ReelInteractionModel(
        userId: userId,
        reelId: reelId,
        creatorId: creatorId,
        completed: true,
        watchPercentage: 100.0,
        watchTime: duration,
        interactedAt: DateTime.now(),
      );

      await repository.recordReelInteraction(interaction);
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error marking reel completed: $e');
    }
  }

  /// Mark reel as skipped
  Future<void> markReelSkipped({
    required String userId,
    required String reelId,
    required String creatorId,
    required ReelRepository repository,
  }) async {
    try {
      final interaction = ReelInteractionModel(
        userId: userId,
        reelId: reelId,
        creatorId: creatorId,
        skipped: true,
        interactedAt: DateTime.now(),
      );

      await repository.recordReelInteraction(interaction);
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error marking reel skipped: $e');
    }
  }

  /// Mark content as not interested
  Future<void> markNotInterested({
    required String userId,
    required String reelId,
    required String creatorId,
    required ReelRepository repository,
  }) async {
    try {
      final interaction = ReelInteractionModel(
        userId: userId,
        reelId: reelId,
        creatorId: creatorId,
        notInterested: true,
        interactedAt: DateTime.now(),
      );

      await repository.recordReelInteraction(interaction);
    } catch (e) {
      debugPrint('ReelsFeedBloc: Error marking not interested: $e');
    }
  }
}
