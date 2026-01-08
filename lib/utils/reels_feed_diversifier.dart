// lib/utils/reels_feed_diversifier.dart

import 'package:freegram/models/reel_model.dart';
import 'package:freegram/services/reels_scoring_service.dart';

/// Utility to ensure feed diversity and freshness
///
/// Applies rules to prevent repetitive content and ensure balanced feed:
/// - Max 2 reels from same creator in top results
/// - Hashtag diversity (avoid clustering)
/// - Freshness injection (include recent content)
/// - Exploration (include content outside user's usual interests)
class ReelsFeedDiversifier {
  /// Apply diversity rules to scored reels
  ///
  /// Returns a diversified list of reels with balanced content
  static List<ReelModel> diversifyFeed({
    required List<ReelModel> reels,
    required Map<String, ReelScore> scores,
    int maxResults = 20,
  }) {
    if (reels.isEmpty) return [];

    // Sort by score first
    final sortedReels = List<ReelModel>.from(reels);
    sortedReels.sort((a, b) {
      final scoreA = scores[a.reelId]?.score ?? 0;
      final scoreB = scores[b.reelId]?.score ?? 0;
      return scoreB.compareTo(scoreA);
    });

    final diversifiedReels = <ReelModel>[];
    final creatorCount = <String, int>{};
    final hashtagCount = <String, int>{};
    final now = DateTime.now();

    // Track fresh content (< 24 hours)
    int freshContentCount = 0;
    const minFreshContent = 3;

    // Track exploration content (low affinity but good engagement)
    int explorationCount = 0;
    const minExplorationContent = 2;

    for (final reel in sortedReels) {
      if (diversifiedReels.length >= maxResults) break;

      final creatorReelCount = creatorCount[reel.uploaderId] ?? 0;
      final score = scores[reel.reelId];

      // Rule 1: Creator diversity - max 2 reels per creator
      if (creatorReelCount >= 2) {
        continue;
      }

      // Rule 2: Hashtag diversity - avoid clustering same hashtags
      if (reel.hashtags.isNotEmpty) {
        final hasClusteredHashtag = reel.hashtags.any((tag) {
          final count = hashtagCount[tag] ?? 0;
          return count >= 3; // Max 3 reels with same hashtag
        });

        if (hasClusteredHashtag && diversifiedReels.length > 10) {
          continue; // Skip if we already have enough content
        }
      }

      // Add the reel
      diversifiedReels.add(reel);
      creatorCount[reel.uploaderId] = creatorReelCount + 1;

      // Update hashtag counts
      for (final tag in reel.hashtags) {
        hashtagCount[tag] = (hashtagCount[tag] ?? 0) + 1;
      }

      // Track fresh content
      final ageInHours = now.difference(reel.createdAt).inHours;
      if (ageInHours < 24) {
        freshContentCount++;
      }

      // Track exploration content (low affinity but good engagement)
      if (score != null &&
          score.affinityScore < 30 &&
          score.engagementScore > 50) {
        explorationCount++;
      }
    }

    // Rule 3: Ensure minimum fresh content
    if (freshContentCount < minFreshContent) {
      final freshReels = sortedReels.where((reel) {
        final ageInHours = now.difference(reel.createdAt).inHours;
        return ageInHours < 24 && !diversifiedReels.contains(reel);
      }).take(minFreshContent - freshContentCount);

      diversifiedReels.addAll(freshReels);
    }

    // Rule 4: Ensure exploration content
    if (explorationCount < minExplorationContent) {
      final explorationReels = sortedReels.where((reel) {
        final score = scores[reel.reelId];
        return score != null &&
            score.affinityScore < 30 &&
            score.engagementScore > 50 &&
            !diversifiedReels.contains(reel);
      }).take(minExplorationContent - explorationCount);

      diversifiedReels.addAll(explorationReels);
    }

    // Trim to max results
    return diversifiedReels.take(maxResults).toList();
  }

  /// Inject trending reels into personalized feed
  ///
  /// Adds high-engagement recent reels to ensure users see viral content
  static List<ReelModel> injectTrendingContent({
    required List<ReelModel> personalizedReels,
    required List<ReelModel> trendingReels,
    int trendingCount = 3,
  }) {
    if (trendingReels.isEmpty) return personalizedReels;

    final result = List<ReelModel>.from(personalizedReels);
    final existingIds = result.map((r) => r.reelId).toSet();

    // Add trending reels that aren't already in the feed
    final newTrending = trendingReels
        .where((reel) => !existingIds.contains(reel.reelId))
        .take(trendingCount);

    // Insert at strategic positions (every 7 reels)
    int insertPosition = 6;
    for (final trending in newTrending) {
      if (insertPosition < result.length) {
        result.insert(insertPosition, trending);
        insertPosition += 7;
      } else {
        result.add(trending);
      }
    }

    return result;
  }

  /// Remove reels from creators user marked as "not interested"
  static List<ReelModel> filterNotInterestedCreators({
    required List<ReelModel> reels,
    required Set<String> notInterestedCreators,
  }) {
    if (notInterestedCreators.isEmpty) return reels;

    return reels
        .where((reel) => !notInterestedCreators.contains(reel.uploaderId))
        .toList();
  }

  /// Remove reels with hashtags user marked as "not interested"
  static List<ReelModel> filterNotInterestedHashtags({
    required List<ReelModel> reels,
    required Set<String> notInterestedHashtags,
  }) {
    if (notInterestedHashtags.isEmpty) return reels;

    return reels.where((reel) {
      // Filter out if any hashtag matches not interested list
      return !reel.hashtags
          .any((tag) => notInterestedHashtags.contains(tag.toLowerCase()));
    }).toList();
  }
}
