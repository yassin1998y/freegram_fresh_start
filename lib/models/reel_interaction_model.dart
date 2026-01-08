// lib/models/reel_interaction_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Tracks individual user interactions with reels for personalization
///
/// Stored in Firestore: users/{userId}/reelInteractions/{reelId}
/// Used by ReelsScoringService to calculate user affinity and preferences
class ReelInteractionModel extends Equatable {
  final String userId;
  final String reelId;
  final String creatorId;
  final bool liked;
  final bool shared;
  final bool commented;
  final double watchTime; // Seconds watched
  final double watchPercentage; // % of reel watched (0-100)
  final bool completed; // Watched to end (>95%)
  final bool skipped; // Skipped before 3 seconds
  final bool notInterested; // User marked as not interested
  final DateTime interactedAt;
  final DateTime? lastUpdatedAt;

  const ReelInteractionModel({
    required this.userId,
    required this.reelId,
    required this.creatorId,
    this.liked = false,
    this.shared = false,
    this.commented = false,
    this.watchTime = 0.0,
    this.watchPercentage = 0.0,
    this.completed = false,
    this.skipped = false,
    this.notInterested = false,
    required this.interactedAt,
    this.lastUpdatedAt,
  });

  factory ReelInteractionModel.fromMap(Map<String, dynamic> data) {
    return ReelInteractionModel(
      userId: data['userId'] ?? '',
      reelId: data['reelId'] ?? '',
      creatorId: data['creatorId'] ?? '',
      liked: data['liked'] ?? false,
      shared: data['shared'] ?? false,
      commented: data['commented'] ?? false,
      watchTime: (data['watchTime'] ?? 0.0).toDouble(),
      watchPercentage: (data['watchPercentage'] ?? 0.0).toDouble(),
      completed: data['completed'] ?? false,
      skipped: data['skipped'] ?? false,
      notInterested: data['notInterested'] ?? false,
      interactedAt: _toDateTime(data['interactedAt']) ?? DateTime.now(),
      lastUpdatedAt: _toDateTime(data['lastUpdatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'reelId': reelId,
      'creatorId': creatorId,
      'liked': liked,
      'shared': shared,
      'commented': commented,
      'watchTime': watchTime,
      'watchPercentage': watchPercentage,
      'completed': completed,
      'skipped': skipped,
      'notInterested': notInterested,
      'interactedAt': Timestamp.fromDate(interactedAt),
      'lastUpdatedAt': lastUpdatedAt != null
          ? Timestamp.fromDate(lastUpdatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  ReelInteractionModel copyWith({
    String? userId,
    String? reelId,
    String? creatorId,
    bool? liked,
    bool? shared,
    bool? commented,
    double? watchTime,
    double? watchPercentage,
    bool? completed,
    bool? skipped,
    bool? notInterested,
    DateTime? interactedAt,
    DateTime? lastUpdatedAt,
  }) {
    return ReelInteractionModel(
      userId: userId ?? this.userId,
      reelId: reelId ?? this.reelId,
      creatorId: creatorId ?? this.creatorId,
      liked: liked ?? this.liked,
      shared: shared ?? this.shared,
      commented: commented ?? this.commented,
      watchTime: watchTime ?? this.watchTime,
      watchPercentage: watchPercentage ?? this.watchPercentage,
      completed: completed ?? this.completed,
      skipped: skipped ?? this.skipped,
      notInterested: notInterested ?? this.notInterested,
      interactedAt: interactedAt ?? this.interactedAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  static DateTime? _toDateTime(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return null;
  }

  @override
  List<Object?> get props => [
        userId,
        reelId,
        creatorId,
        liked,
        shared,
        commented,
        watchTime,
        watchPercentage,
        completed,
        skipped,
        notInterested,
        interactedAt,
        lastUpdatedAt,
      ];
}
