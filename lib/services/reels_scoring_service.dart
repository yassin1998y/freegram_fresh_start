// lib/services/reels_scoring_service.dart

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/models/user_model.dart';

/// Personalized scoring service for reels feed recommendations
///
/// Calculates relevance scores based on:
/// - User Affinity (40%): Creator engagement history, following relationship
/// - Content Relevance (30%): Hashtag/interest matching, topic alignment
/// - Engagement Quality (20%): Like/view ratio, completion rate
/// - Freshness & Diversity (10%): Recency, creator diversity
class ReelsScoringService {
  final FirebaseFirestore _db;

  ReelsScoringService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Calculate personalized score for a reel
  Future<ReelScore> calculateScore({
    required ReelModel reel,
    required String userId,
    required UserModel user,
    required Map<String, int> creatorFrequency,
    required Map<String, double> creatorAffinityCache,
  }) async {
    // Calculate individual components
    final affinityScore = await _calculateUserAffinity(
      reel: reel,
      userId: userId,
      user: user,
      cache: creatorAffinityCache,
    );

    final relevanceScore = _calculateContentRelevance(
      reel: reel,
      user: user,
    );

    final engagementScore = _calculateEngagementQuality(reel);

    final freshnessScore = _calculateFreshnessAndDiversity(
      reel: reel,
      creatorFrequency: creatorFrequency,
    );

    // Weighted final score
    final finalScore = (affinityScore * 0.4) +
        (relevanceScore * 0.3) +
        (engagementScore * 0.2) +
        (freshnessScore * 0.1);

    return ReelScore(
      reelId: reel.reelId,
      score: finalScore,
      affinityScore: affinityScore,
      relevanceScore: relevanceScore,
      engagementScore: engagementScore,
      freshnessScore: freshnessScore,
      reason: _generateRecommendationReason(
        reel: reel,
        user: user,
        affinityScore: affinityScore,
        relevanceScore: relevanceScore,
      ),
    );
  }

  /// Calculate user affinity with creator (40% weight)
  Future<double> _calculateUserAffinity({
    required ReelModel reel,
    required String userId,
    required UserModel user,
    required Map<String, double> cache,
  }) async {
    // Check cache first
    if (cache.containsKey(reel.uploaderId)) {
      return cache[reel.uploaderId]!;
    }

    double score = 0.0;

    try {
      // 1. Following bonus (50 points)
      if (user.friends.contains(reel.uploaderId)) {
        score += 50.0;
      }

      // 2. Past interaction score (50 points max)
      final interactionDoc = await _db
          .collection('users')
          .doc(userId)
          .collection('reelInteractions')
          .where('creatorId', isEqualTo: reel.uploaderId)
          .limit(10)
          .get();

      if (interactionDoc.docs.isNotEmpty) {
        int likes = 0;
        int comments = 0;
        int shares = 0;
        double totalWatchPercentage = 0.0;

        for (var doc in interactionDoc.docs) {
          final data = doc.data();
          if (data['liked'] == true) likes++;
          if (data['commented'] == true) comments++;
          if (data['shared'] == true) shares++;
          totalWatchPercentage += (data['watchPercentage'] ?? 0.0);
        }

        // Calculate interaction score
        final interactionScore = (likes * 2) + (comments * 3) + (shares * 4);
        final avgWatchPercentage =
            totalWatchPercentage / interactionDoc.docs.length;

        score += (interactionScore.toDouble().clamp(0, 30)) +
            (avgWatchPercentage * 0.2); // Max 20 points from watch time
      }

      // Cache the result
      cache[reel.uploaderId] = score;
    } catch (e) {
      debugPrint('ReelsScoringService: Error calculating affinity: $e');
    }

    return score.clamp(0, 100);
  }

  /// Calculate content relevance (30% weight)
  double _calculateContentRelevance({
    required ReelModel reel,
    required UserModel user,
  }) {
    double score = 0.0;

    // 1. Hashtag matching (60 points max)
    if (reel.hashtags.isNotEmpty && user.interests.isNotEmpty) {
      final matchingHashtags = reel.hashtags
          .where((tag) => user.interests.any(
              (interest) => tag.toLowerCase().contains(interest.toLowerCase())))
          .length;

      final hashtagScore = (matchingHashtags / reel.hashtags.length) * 60;
      score += hashtagScore;
    }

    // 2. Location relevance (20 points max)
    if (reel.location != null && user.location != null) {
      // Simple proximity check (could be enhanced with actual distance calculation)
      final reelGeo = reel.location!['geopoint'] as GeoPoint?;
      if (reelGeo != null) {
        final distance = _calculateDistance(
          user.location!.latitude,
          user.location!.longitude,
          reelGeo.latitude,
          reelGeo.longitude,
        );

        // Bonus for nearby content (within 50km)
        if (distance < 50) {
          score += 20 * (1 - (distance / 50));
        }
      }
    }

    // 3. Audio track popularity (20 points max)
    if (reel.audioTrack != null) {
      final usageCount = reel.audioTrack!['usageCount'] ?? 0;
      score += (usageCount / 100).clamp(0, 20).toDouble();
    }

    return score.clamp(0, 100);
  }

  /// Calculate engagement quality (20% weight)
  double _calculateEngagementQuality(ReelModel reel) {
    double score = 0.0;

    if (reel.viewCount == 0) return 0.0;

    // 1. Like-to-view ratio (30 points)
    final likeRatio = (reel.likeCount / reel.viewCount) * 100;
    score += likeRatio.clamp(0, 30);

    // 2. Comment-to-view ratio (30 points)
    final commentRatio = (reel.commentCount / reel.viewCount) * 100;
    score += commentRatio.clamp(0, 30);

    // 3. Share-to-view ratio (40 points)
    final shareRatio = (reel.shareCount / reel.viewCount) * 100;
    score += shareRatio.clamp(0, 40);

    return score.clamp(0, 100);
  }

  /// Calculate freshness and diversity (10% weight)
  double _calculateFreshnessAndDiversity({
    required ReelModel reel,
    required Map<String, int> creatorFrequency,
  }) {
    double score = 0.0;

    // 1. Recency bonus (60 points max)
    final ageInHours = DateTime.now().difference(reel.createdAt).inHours;
    if (ageInHours < 24) {
      score += 60 * (1 - (ageInHours / 24)); // Newer = higher score
    } else if (ageInHours < 168) {
      // 7 days
      score += 30 * (1 - (ageInHours / 168));
    }

    // 2. Creator diversity penalty (40 points max)
    final creatorCount = creatorFrequency[reel.uploaderId] ?? 0;
    if (creatorCount == 0) {
      score += 40; // New creator bonus
    } else if (creatorCount == 1) {
      score += 20; // Second reel from creator
    }
    // No points if already seen 2+ reels from this creator

    return score.clamp(0, 100);
  }

  /// Generate human-readable recommendation reason
  String _generateRecommendationReason({
    required ReelModel reel,
    required UserModel user,
    required double affinityScore,
    required double relevanceScore,
  }) {
    if (affinityScore > 50) {
      if (user.friends.contains(reel.uploaderId)) {
        return 'From @${reel.uploaderUsername} who you follow';
      }
      return 'Based on your engagement with @${reel.uploaderUsername}';
    }

    if (relevanceScore > 50) {
      final matchingHashtags = reel.hashtags
          .where((tag) => user.interests.any(
              (interest) => tag.toLowerCase().contains(interest.toLowerCase())))
          .toList();

      if (matchingHashtags.isNotEmpty) {
        return 'Matches your interest in ${matchingHashtags.first}';
      }
    }

    final ageInHours = DateTime.now().difference(reel.createdAt).inHours;
    if (ageInHours < 24) {
      return 'Trending now';
    }

    return 'Recommended for you';
  }

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }
}

/// Score result for a reel
class ReelScore {
  final String reelId;
  final double score;
  final double affinityScore;
  final double relevanceScore;
  final double engagementScore;
  final double freshnessScore;
  final String reason;

  const ReelScore({
    required this.reelId,
    required this.score,
    required this.affinityScore,
    required this.relevanceScore,
    required this.engagementScore,
    required this.freshnessScore,
    required this.reason,
  });

  @override
  String toString() {
    return 'ReelScore(id: $reelId, score: ${score.toStringAsFixed(2)}, '
        'affinity: ${affinityScore.toStringAsFixed(1)}, '
        'relevance: ${relevanceScore.toStringAsFixed(1)}, '
        'engagement: ${engagementScore.toStringAsFixed(1)}, '
        'freshness: ${freshnessScore.toStringAsFixed(1)})';
  }
}
