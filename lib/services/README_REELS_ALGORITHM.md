// lib/services/README_REELS_ALGORITHM.md

# Reels Algorithm Integration Guide

This guide explains how to integrate the new personalized reels algorithm into your application.

## Quick Start

The new algorithm is ready to use with minimal integration required. Here's what you need to know:

### 1. Core Components (Already Created)

✅ **ReelsScoringService** - Calculates personalized scores  
✅ **ReelInteractionModel** - Tracks user engagement  
✅ **ReelsFeedDiversifier** - Ensures feed variety  
✅ **Enhanced ReelRepository** - Personalized queries  
✅ **ReelWatchTimeTracker** - Monitors viewing duration  
✅ **ReelsFeedbackDialog** - User feedback UI  
✅ **ReelsUIHelpers** - UI utility methods  

### 2. Using the Scoring Service

```dart
import 'package:freegram/services/reels_scoring_service.dart';
import 'package:freegram/utils/reels_feed_diversifier.dart';

// In your bloc or service:
final scoringService = ReelsScoringService();

// Fetch reels
final allReels = await reelRepository.getPersonalizedReelsFeed(
  userId: currentUserId,
  limit: 50,
);

// Score each reel
final scores = <String, ReelScore>{};
for (final reel in allReels) {
  final score = await scoringService.calculateScore(
    reel: reel,
    userId: currentUserId,
    user: currentUser,
    creatorFrequency: {},
    creatorAffinityCache: {},
  );
  scores[reel.reelId] = score;
}

// Apply diversity and get top results
final diversifiedReels = ReelsFeedDiversifier.diversifyFeed(
  reels: allReels,
  scores: scores,
  maxResults: 20,
);
```

### 3. Tracking Watch Time

```dart
import 'package:freegram/services/reel_watch_time_tracker.dart';

// In your player widget:
late ReelWatchTimeTracker _watchTracker;

@override
void initState() {
  super.initState();
  _watchTracker = ReelWatchTimeTracker(
    reelId: widget.reel.reelId,
    duration: widget.reel.duration,
    onWatchTimeUpdate: (watchTime, percentage) {
      // Record watch time periodically
      reelRepository.recordReelInteraction(
        ReelInteractionModel(
          userId: currentUserId,
          reelId: widget.reel.reelId,
          creatorId: widget.reel.uploaderId,
          watchTime: watchTime,
          watchPercentage: percentage,
          interactedAt: DateTime.now(),
        ),
      );
    },
    onCompleted: () {
      // User watched to end
      print('Reel completed!');
    },
    onSkipped: () {
      // User skipped quickly
      print('Reel skipped!');
    },
  );
  _watchTracker.start();
}

// Update position as video plays
void _onVideoPositionChanged(Duration position) {
  _watchTracker.updatePosition(position.inSeconds.toDouble());
}

@override
void dispose() {
  _watchTracker.dispose();
  super.dispose();
}
```

### 4. Adding "Not Interested" Feedback

```dart
import 'package:freegram/utils/reels_ui_helpers.dart';

// In your UI overlay or menu:
IconButton(
  icon: Icon(Icons.more_vert),
  onPressed: () {
    ReelsUIHelpers.showNotInterestedDialog(
      context: context,
      reel: currentReel,
      onFeedbackSubmitted: (creatorId, reason) {
        // Record feedback
        reelRepository.recordReelInteraction(
          ReelInteractionModel(
            userId: currentUserId,
            reelId: currentReel.reelId,
            creatorId: creatorId,
            notInterested: true,
            interactedAt: DateTime.now(),
          ),
        );
        
        // Remove from feed
        // ... update your state
      },
    );
  },
)
```

### 5. Showing Recommendation Reasons

```dart
// Show why a reel was recommended
ReelsUIHelpers.showRecommendationReason(
  context: context,
  reason: reelScore.reason, // From scoring service
);
```

## Algorithm Tuning

### Adjusting Score Weights

Edit `ReelsScoringService.calculateScore()`:

```dart
// Current weights:
final finalScore = (affinityScore * 0.4) +      // User affinity
                   (relevanceScore * 0.3) +      // Content relevance
                   (engagementScore * 0.2) +     // Engagement quality
                   (freshnessScore * 0.1);       // Freshness & diversity

// Adjust based on your analytics:
// - Increase affinity weight to prioritize followed creators
// - Increase relevance weight to match interests more closely
// - Increase engagement weight to show viral content
// - Increase freshness weight to show newer content
```

### Diversity Rules

Edit `ReelsFeedDiversifier.diversifyFeed()`:

```dart
// Current rules:
- Max 2 reels per creator
- Max 3 reels per hashtag
- Min 3 fresh reels (<24h)
- Min 2 exploration reels

// Adjust in the diversifier utility
```

## Data Collection

### Firestore Structure

The algorithm stores interaction data in:

```
users/{userId}/reelInteractions/{reelId}
  - userId: string
  - reelId: string
  - creatorId: string
  - liked: boolean
  - shared: boolean
  - commented: boolean
  - watchTime: number (seconds)
  - watchPercentage: number (0-100)
  - completed: boolean
  - skipped: boolean
  - notInterested: boolean
  - interactedAt: timestamp
```

### Analytics Queries

```dart
// Get user's watch time for a creator
final interactions = await firestore
  .collection('users')
  .doc(userId)
  .collection('reelInteractions')
  .where('creatorId', isEqualTo: creatorId)
  .get();

final totalWatchTime = interactions.docs
  .fold<double>(0, (sum, doc) => sum + (doc.data()['watchTime'] ?? 0));

// Get completion rate
final completed = interactions.docs
  .where((doc) => doc.data()['completed'] == true)
  .length;
final completionRate = completed / interactions.docs.length;
```

## Performance Tips

1. **Batch Scoring**: Score reels in batches to avoid blocking UI
2. **Cache Affinity**: Reuse creator affinity scores within a session
3. **Limit Fetch Size**: Fetch 50 reels, score, then display top 20
4. **Background Upload**: Batch interaction uploads every 5 reels
5. **Server-Side**: Consider moving scoring to Cloud Functions for scale

## Testing

### Test Personalization

1. Create test user with specific interests
2. Like reels from specific creators
3. Verify feed shows more similar content
4. Test "Not Interested" reduces similar content

### Test Diversity

1. Verify no more than 2 reels from same creator
2. Check hashtag distribution
3. Confirm fresh content appears

### Test Tracking

1. Watch reel to completion - verify `completed: true`
2. Skip reel quickly - verify `skipped: true`
3. Watch 50% - verify `watchPercentage: 50`

## Migration from Old System

The new algorithm is **backward compatible**. You can:

1. **Gradual Rollout**: Use old system for some users, new for others
2. **A/B Testing**: Compare engagement metrics
3. **Fallback**: If scoring fails, falls back to chronological

```dart
try {
  // Try personalized feed
  final personalizedReels = await getPersonalizedFeed();
  return personalizedReels;
} catch (e) {
  // Fallback to chronological
  return await reelRepository.getReelsFeed();
}
```

## Next Steps

1. **Integrate into ReelsFeedBloc** - Update bloc to use scoring service
2. **Add to Player** - Integrate watch time tracker
3. **Update UI** - Add feedback controls
4. **Monitor Metrics** - Track engagement improvements
5. **Tune Weights** - Adjust based on user behavior

## Support

For questions or issues, refer to:
- `implementation_plan.md` - Detailed technical plan
- `walkthrough.md` - Implementation walkthrough
- Source code comments in each service
