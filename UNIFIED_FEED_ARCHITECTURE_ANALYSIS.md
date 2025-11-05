# Unified Feed Architecture - Deep Analysis & Refactor Plan

## Executive Summary

**Current Problem:** Feeds are merged visually but separated logically. DisplayType badges are assigned at fetch time based on source, not actual post performance scores. This causes:
- Duplicated posts in feeds
- User posts appearing in wrong positions
- Inconsistent badge display (not reflecting actual scores)
- Dead code from multiple mixing strategies
- Poor UX with posts appearing at bottom or randomly

**Solution:** Create a unified feed system with:
1. **Single Unified Feed BLoC** - One source of truth for all feeds
2. **Score-Based Badge System** - DisplayType determined by actual post metrics, not source
3. **Proper Deduplication** - Remove duplicate posts across all sources
4. **Guaranteed Top Positioning** - User's own recent posts always at top
5. **Clean Architecture** - Remove dead code and consolidate logic

---

## Current Architecture Analysis

### 1. Feed Structure Overview

```
FeedScreen (TabView)
├── ForYouFeedTab
│   └── ForYouFeedBloc
│       ├── Fetches: trending, nearby, boosted, user posts, ads, suggestions
│       └── Mixes: Complex ratio-based algorithm (60% trending, 25% nearby, 15% boosted)
│
├── NearbyFeedTab (Reels)
│   └── NearbyFeedBloc
│       └── Fetches: Nearby posts only
│
└── FollowingFeedTab (Not in FeedScreen, but exists)
    └── FollowingFeedBloc
        ├── Fetches: Friends' posts + public posts
        └── Mixes: Simple chronological merge
```

### 2. Current Problems Identified

#### Problem 1: DisplayType Assigned at Source (Not by Score)
**Location:** `for_you_feed_bloc.dart:283-309`
```dart
// ❌ BAD: DisplayType assigned when fetched, not by actual score
final forYouPosts = trending.map((p) => PostFeedItem(
  post: p,
  displayType: PostDisplayType.trending, // Always "trending" regardless of score
)).toList();

final boostedPosts = boosted.map((p) => PostFeedItem(
  post: p,
  displayType: PostDisplayType.boosted, // Always "boosted" regardless of engagement
)).toList();
```

**Issue:** A post with `trendingScore = 0.5` gets "Trending" badge, while a post with `trendingScore = 100` from "nearby" gets "Near You" badge. This is backwards!

#### Problem 2: Duplicated Fetching Logic
- `ForYouFeedBloc` fetches user posts separately
- `FollowingFeedBloc` also fetches user posts separately
- Both can appear in different feeds, causing duplication

#### Problem 3: Separate Mixing Algorithms
- `ForYouFeedBloc._mixFeedItems()` - Complex 200+ line algorithm with ratios
- `FollowingFeedBloc._mixPagePosts()` - Simple chronological merge
- Different logic for same purpose = dead code

#### Problem 4: User Posts Not Guaranteed Top Position
- User posts added after fetching, could be inserted in middle
- No priority system ensures top position

#### Problem 5: No Unified Scoring System
- `trendingScore` exists but not used for badge assignment
- `boostStats` exists but not used for prioritization
- No single "feed score" that determines order AND badge

---

## Proposed Unified Architecture

### 1. Unified Feed Scoring Service

**New File:** `lib/services/feed_scoring_service.dart`

```dart
class FeedScoringService {
  /// Calculate unified feed score for a post
  /// This score determines both ORDER and BADGE
  static UnifiedFeedScore calculateScore(PostModel post, {
    required String currentUserId,
    GeoPoint? userLocation,
    TimeFilter timeFilter = TimeFilter.allTime,
  }) {
    // Priority 1: User's own posts (if recent)
    final isOwnPost = post.authorId == currentUserId;
    final ageInMinutes = DateTime.now().difference(post.timestamp).inMinutes;
    
    if (isOwnPost && ageInMinutes < 5) {
      return UnifiedFeedScore(
        score: 10000.0, // Highest priority
        badgeType: PostDisplayType.organic, // No badge for own posts
        reason: 'User own recent post',
      );
    }
    
    // Priority 2: Boosted posts (calculate engagement-weighted score)
    if (post.isBoosted && post.boostEndTime != null) {
      final boostScore = _calculateBoostScore(post);
      return UnifiedFeedScore(
        score: 5000.0 + boostScore, // Boosted posts get priority
        badgeType: PostDisplayType.boosted,
        reason: 'Boosted post',
      );
    }
    
    // Priority 3: Trending posts (by actual trendingScore)
    if (post.trendingScore > 50) {
      return UnifiedFeedScore(
        score: 3000.0 + post.trendingScore,
        badgeType: PostDisplayType.trending,
        reason: 'Trending post',
      );
    }
    
    // Priority 4: Nearby posts (by location proximity)
    if (userLocation != null && post.location != null) {
      final distance = _calculateDistance(userLocation, post.location!);
      if (distance < 10.0) { // Within 10km
        return UnifiedFeedScore(
          score: 2000.0 - distance, // Closer = higher score
          badgeType: PostDisplayType.nearby,
          reason: 'Nearby post',
        );
      }
    }
    
    // Priority 5: Organic posts (chronological)
    final recencyHours = DateTime.now().difference(post.timestamp).inHours;
    return UnifiedFeedScore(
      score: 1000.0 - recencyHours, // Newer = higher score
      badgeType: PostDisplayType.organic,
      reason: 'Organic post',
    );
  }
}

class UnifiedFeedScore {
  final double score;
  final PostDisplayType badgeType;
  final String reason;
  
  UnifiedFeedScore({
    required this.score,
    required this.badgeType,
    required this.reason,
  });
}
```

### 2. Unified Feed Repository Method

**New Method in:** `lib/repositories/post_repository.dart`

```dart
/// Get unified feed - merges all post types into one sorted list
/// This is the SINGLE SOURCE OF TRUTH for feed queries
Future<List<PostModel>> getUnifiedFeed({
  required String userId,
  GeoPoint? userLocation,
  TimeFilter timeFilter = TimeFilter.allTime,
  DocumentSnapshot? lastDocument,
  int limit = 20,
}) async {
  // Fetch ALL post types in parallel
  final results = await Future.wait([
    getTrendingPosts(timeFilter: timeFilter, limit: 20),
    getBoostedPosts(userTargeting: {...}, limit: 10),
    getFeedForUser(userId: userId, limit: 20), // Includes friends + public
    getUserPosts(userId: userId, limit: 5), // User's own posts
  ]);
  
  // Merge and deduplicate
  final allPosts = <PostModel>[];
  final seenIds = <String>{};
  
  for (final postList in results) {
    for (final post in postList) {
      if (!seenIds.contains(post.id)) {
        allPosts.add(post);
        seenIds.add(post.id);
      }
    }
  }
  
  return allPosts;
}
```

### 3. Unified Feed BLoC

**New File:** `lib/blocs/unified_feed_bloc.dart`

```dart
class UnifiedFeedBloc extends Bloc<UnifiedFeedEvent, UnifiedFeedState> {
  final PostRepository _postRepository;
  final FeedScoringService _scoringService;
  final UserRepository? _userRepository;
  
  Future<void> _onLoadFeed(LoadUnifiedFeedEvent event) async {
    emit(UnifiedFeedLoading());
    
    try {
      // Get user location for nearby scoring
      GeoPoint? userLocation;
      if (_userRepository != null) {
        final user = await _userRepository.getUser(event.userId);
        userLocation = user.location; // If available
      }
      
      // Fetch unified feed (all post types, deduplicated)
      final posts = await _postRepository.getUnifiedFeed(
        userId: event.userId,
        userLocation: userLocation,
        timeFilter: event.timeFilter,
        limit: 20,
      );
      
      // Calculate scores and determine badges
      final scoredItems = posts.map((post) {
        final score = FeedScoringService.calculateScore(
          post,
          currentUserId: event.userId,
          userLocation: userLocation,
          timeFilter: event.timeFilter,
        );
        
        return ScoredFeedItem(
          post: post,
          score: score.score,
          displayType: score.badgeType,
        );
      }).toList();
      
      // Sort by score (highest first)
      scoredItems.sort((a, b) => b.score.compareTo(a.score));
      
      // Ensure user's own recent posts are at top
      final userOwnRecent = scoredItems.where((item) {
        final ageInMinutes = DateTime.now()
            .difference(item.post.timestamp)
            .inMinutes;
        return item.post.authorId == event.userId && ageInMinutes < 5;
      }).toList();
      
      final otherItems = scoredItems.where((item) {
        final ageInMinutes = DateTime.now()
            .difference(item.post.timestamp)
            .inMinutes;
        return !(item.post.authorId == event.userId && ageInMinutes < 5);
      }).toList();
      
      // Combine: user posts first, then others
      final finalItems = [
        ...userOwnRecent.map((item) => PostFeedItem(
          post: item.post,
          displayType: item.displayType,
        )),
        ...otherItems.map((item) => PostFeedItem(
          post: item.post,
          displayType: item.displayType,
        )),
      ];
      
      emit(UnifiedFeedLoaded(items: finalItems));
    } catch (e) {
      emit(UnifiedFeedError(e.toString()));
    }
  }
}

class ScoredFeedItem {
  final PostModel post;
  final double score;
  final PostDisplayType displayType;
  
  ScoredFeedItem({
    required this.post,
    required this.score,
    required this.displayType,
  });
}
```

### 4. Feed Display Type Logic (Score-Based)

**Update:** `lib/models/feed_item_model.dart`

```dart
/// DisplayType is now determined by SCORE, not source
/// Logic:
/// - trendingScore > 50 → Trending badge
/// - isBoosted && boostEndTime > now → Boosted badge
/// - distance < 10km → Nearby badge
/// - pageId != null → Page badge (no special badge, just different styling)
/// - else → Organic (no badge)
```

---

## Refactoring Steps

### Phase 1: Create Scoring Service
1. ✅ Create `lib/services/feed_scoring_service.dart`
2. ✅ Implement `calculateScore()` method
3. ✅ Test with various post types

### Phase 2: Update PostRepository
1. ✅ Add `getUnifiedFeed()` method
2. ✅ Implement deduplication logic
3. ✅ Test query performance

### Phase 3: Create Unified Feed BLoC
1. ✅ Create `lib/blocs/unified_feed_bloc.dart`
2. ✅ Implement score-based sorting
3. ✅ Ensure user posts at top
4. ✅ Test state management

### Phase 4: Migrate Feed Screens
1. ✅ Update `FeedScreen` to use `UnifiedFeedBloc`
2. ✅ Remove `ForYouFeedBloc` usage
3. ✅ Remove `FollowingFeedBloc` usage (or merge into unified)
4. ✅ Update `FollowingFeedTab` if still needed

### Phase 5: Cleanup Dead Code
1. ✅ Remove `_mixFeedItems()` from `ForYouFeedBloc`
2. ✅ Remove `_mixPagePosts()` from `FollowingFeedBloc`
3. ✅ Remove duplicate user post fetching
4. ✅ Remove unused feed BLoCs (or deprecate)

### Phase 6: Testing & Validation
1. ✅ Test user posts appear at top
2. ✅ Test badges show correctly based on scores
3. ✅ Test no duplicate posts
4. ✅ Test performance with large feeds

---

## Benefits of Unified Architecture

1. **Single Source of Truth**: One BLoC, one query method, one scoring system
2. **Score-Based Badges**: Badges reflect actual post performance, not source
3. **No Duplicates**: Deduplication built into unified fetch
4. **Guaranteed Top Position**: User posts always at top (if recent)
5. **Clean Code**: Removed 200+ lines of duplicate mixing logic
6. **Better UX**: Posts appear in logical order, badges are meaningful
7. **Maintainable**: Changes to feed logic happen in one place

---

## Migration Strategy

### Step 1: Parallel Implementation (Non-Breaking)
- Keep existing BLoCs working
- Create new `UnifiedFeedBloc` alongside
- Test in parallel

### Step 2: Gradual Migration
- Migrate `ForYouFeedTab` first
- Then migrate `FollowingFeedTab`
- Keep old code until fully tested

### Step 3: Remove Old Code
- Delete `ForYouFeedBloc` once fully migrated
- Delete `FollowingFeedBloc` once fully migrated
- Clean up unused methods

---

## Performance Considerations

1. **Query Optimization**: Fetch all types in parallel (already done)
2. **Client-Side Scoring**: Fast, no extra queries
3. **Deduplication**: O(n) operation, efficient
4. **Caching**: Can cache scored items for faster subsequent loads

---

## Risk Mitigation

1. **Backward Compatibility**: Keep old BLoCs until migration complete
2. **Feature Flags**: Use flags to switch between old/new system
3. **A/B Testing**: Test unified feed with subset of users first
4. **Rollback Plan**: Keep old code in git history, easy to revert

---

## Success Metrics

- ✅ User posts appear at top within 5 minutes of creation
- ✅ Badges accurately reflect post performance
- ✅ Zero duplicate posts in feed
- ✅ Feed load time < 2 seconds
- ✅ Code reduction: 200+ lines removed
- ✅ User satisfaction: Better feed quality scores

---

## Next Steps

1. Review this plan
2. Approve unified architecture approach
3. Begin Phase 1 implementation
4. Test incrementally
5. Deploy gradually

