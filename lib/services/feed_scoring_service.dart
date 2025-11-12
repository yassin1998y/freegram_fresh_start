// lib/services/feed_scoring_service.dart
// Unified Feed Scoring Service - Determines both ORDER and BADGE for posts

import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/utils/enums.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

/// Unified feed score that determines both sorting order and badge display
class UnifiedFeedScore {
  final double score;
  final PostDisplayType badgeType;
  final String reason;

  UnifiedFeedScore({
    required this.score,
    required this.badgeType,
    required this.reason,
  });

  @override
  String toString() =>
      'UnifiedFeedScore(score: $score, badge: $badgeType, reason: $reason)';
}

/// Service that calculates unified feed scores for posts
/// This determines both the ORDER (sorting) and BADGE (display type) of posts
class FeedScoringService {
  /// Calculate unified feed score for a post
  /// This score determines both ORDER and BADGE based on actual post metrics
  ///
  /// Priority order (highest to lowest):
  /// 1. User's own recent posts (< 5 minutes) - Always at top, no badge
  /// 2. Boosted posts - High priority, "Promoted" badge
  /// 3. Trending posts (trendingScore > 50) - Medium-high priority, "Trending" badge
  /// 4. Nearby posts (within 10km) - Medium priority, "Near You" badge
  /// 5. Organic posts - Chronological, no badge
  static UnifiedFeedScore calculateScore(
    PostModel post, {
    required String currentUserId,
    GeoPoint? userLocation,
    TimeFilter timeFilter = TimeFilter.allTime,
  }) {
    final now = DateTime.now();
    final isOwnPost = post.authorId == currentUserId;
    final ageInMinutes = now.difference(post.timestamp).inMinutes;

    // Priority 1: User's own recent posts (always at top, no badge)
    if (isOwnPost && ageInMinutes < 5) {
      return UnifiedFeedScore(
        score: 10000.0 - ageInMinutes, // Higher score for newer posts
        badgeType: PostDisplayType.organic, // No badge for own posts
        reason: 'User own recent post ($ageInMinutes min old)',
      );
    }

    // Priority 2: Boosted posts (calculate engagement-weighted score)
    if (post.isBoosted && post.boostEndTime != null) {
      final boostEndTime = post.boostEndTime!.toDate();
      final hoursRemaining = boostEndTime.difference(now).inHours;

      // Only include active boosts
      if (hoursRemaining > 0) {
        final boostScore = _calculateBoostScore(post);
        return UnifiedFeedScore(
          score: 5000.0 + boostScore, // Boosted posts get high priority
          badgeType: PostDisplayType.boosted,
          reason:
              'Boosted post (${hoursRemaining}h remaining, score: $boostScore)',
        );
      }
    }

    // Priority 3: Trending posts (by actual trendingScore)
    // Show "Trending" badge for posts with meaningful engagement
    // Lowered threshold to 50.0 to make trending section more visible
    // Formula: (reactions * 1) + (comments * 2) + recencyBonus
    // A post with 10 reactions + 5 comments = 20, plus recency bonus can easily hit 50+
    if (post.trendingScore >= 50.0) {
      return UnifiedFeedScore(
        score: 3000.0 + post.trendingScore,
        badgeType: PostDisplayType.trending,
        reason: 'Trending post (score: ${post.trendingScore})',
      );
    }

    // Priority 4: Nearby posts (by location proximity)
    if (userLocation != null && post.location != null) {
      final distanceKm = _calculateDistanceKm(userLocation, post.location!);
      if (distanceKm < 10.0) {
        // Within 10km - show "Near You" badge
        // Closer posts get higher score
        return UnifiedFeedScore(
          score: 2000.0 - (distanceKm * 10), // Closer = higher score
          badgeType: PostDisplayType.nearby,
          reason: 'Nearby post (${distanceKm.toStringAsFixed(1)}km away)',
        );
      }
    }

    // Priority 5: Organic posts (chronological with recency bonus)
    // Newer posts get higher score, but lower priority than special types
    final recencyHours = now.difference(post.timestamp).inHours;
    final recencyBonus =
        math.max(0, 24 - recencyHours); // Bonus for posts < 24h old

    return UnifiedFeedScore(
      score: 1000.0 + recencyBonus,
      badgeType: PostDisplayType.organic,
      reason: 'Organic post (${recencyHours}h old)',
    );
  }

  /// Calculate boost score based on engagement metrics
  /// Higher engagement = higher score = shown first
  static double _calculateBoostScore(PostModel post) {
    // Component 1: Trending score (normalized to 0-1)
    final trendingComponent = (post.trendingScore / 200.0).clamp(0.0, 1.0);

    // Component 2: Engagement rate (from boost stats if available)
    double engagementRate = 0.0;
    if (post.boostStats != null) {
      final impressions =
          (post.boostStats!['impressions'] as num?)?.toInt() ?? 0;
      final engagement = (post.boostStats!['engagement'] as num?)?.toInt() ?? 0;
      if (impressions > 0) {
        engagementRate = (engagement / impressions).clamp(0.0, 1.0);
      } else {
        // If no impressions yet, use reaction+comment count as proxy
        final totalEngagement = post.reactionCount + post.commentCount;
        engagementRate = (totalEngagement / 100.0).clamp(0.0, 1.0);
      }
    } else {
      // Fallback: use reaction+comment count
      final totalEngagement = post.reactionCount + post.commentCount;
      engagementRate = (totalEngagement / 100.0).clamp(0.0, 1.0);
    }

    // Component 3: Recency bonus (boost ending soon gets priority)
    double recencyBonus = 0.0;
    if (post.boostEndTime != null) {
      final endTime = post.boostEndTime!.toDate();
      final hoursRemaining = endTime.difference(DateTime.now()).inHours;
      if (hoursRemaining > 0 && hoursRemaining <= 24) {
        recencyBonus = (24 - hoursRemaining) /
            24.0; // Higher bonus for less time remaining
      }
    }

    // Weighted composite score
    // Trending: 40%, Engagement: 40%, Recency: 20%
    return (trendingComponent * 0.4) +
        (engagementRate * 0.4) +
        (recencyBonus * 0.2);
  }

  /// Calculate distance between two GeoPoints in kilometers
  /// Uses Haversine formula for accurate distance calculation
  static double _calculateDistanceKm(GeoPoint point1, GeoPoint point2) {
    const double earthRadiusKm = 6371.0;

    final lat1Rad = point1.latitude * (math.pi / 180);
    final lat2Rad = point2.latitude * (math.pi / 180);
    final deltaLat = (point2.latitude - point1.latitude) * (math.pi / 180);
    final deltaLon = (point2.longitude - point1.longitude) * (math.pi / 180);

    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Determine display type badge based on post properties
  /// This is a fallback method if score is not calculated
  static PostDisplayType determineBadgeType(PostModel post,
      {GeoPoint? userLocation}) {
    // Boosted posts always get "Promoted" badge
    if (post.isBoosted && post.boostEndTime != null) {
      final hoursRemaining =
          post.boostEndTime!.toDate().difference(DateTime.now()).inHours;
      if (hoursRemaining > 0) {
        return PostDisplayType.boosted;
      }
    }

    // Trending posts (meaningful engagement - lowered threshold for visibility)
    if (post.trendingScore >= 50.0) {
      return PostDisplayType.trending;
    }

    // Nearby posts (within 10km)
    if (userLocation != null && post.location != null) {
      final distanceKm = _calculateDistanceKm(userLocation, post.location!);
      if (distanceKm < 10.0) {
        return PostDisplayType.nearby;
      }
    }

    // Page posts (different styling, but no special badge)
    if (post.pageId != null) {
      return PostDisplayType.page;
    }

    // Default: organic (no badge)
    return PostDisplayType.organic;
  }
}
