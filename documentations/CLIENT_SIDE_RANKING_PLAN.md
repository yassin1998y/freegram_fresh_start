# Client-Side Ranking Algorithm Implementation Plan
## Alternative to Enterprise Fan-Out Pattern (Simpler Firebase Approach)

**Project:** Sonar Pulse Social App (Flutter, Firebase)  
**Approach:** Fan-on-Read (Client-Side Ranking)  
**Goal:** Implement ranking algorithm `Score = Affinity × Weight × Time Decay` on the client device

---

## Overview: Why This Approach?

### Server-Side Fan-Out (Complex):
- ❌ Requires pre-calculating personalized feeds for every user
- ❌ Backend complexity: fan-out to thousands of followers
- ❌ High write costs (Firestore writes)
- ❌ Complex Cloud Functions with batch operations

### Client-Side Ranking (Simple):
- ✅ Simple backend: only update affinity on interactions
- ✅ Low write costs (only affinity updates)
- ✅ Device handles ranking (free computation)
- ✅ Easier to debug and iterate
- ✅ No fan-out complexity

---

## Phase 1: Data Model Refactor (The "Affinity" Score)

### 1.1 `UserModel` (`lib/models/user_model.dart`)

**Objective:** Add affinity scores storage to track user relationships.

**Changes Required:**

1. **Add new field:**
   ```dart
   /// Affinity scores for users and pages this user interacts with
   /// Key: userId or pageId, Value: affinity score (0.1 to 10.0)
   /// Example: {'user_123': 5.2, 'page_456': 1.5, 'user_789': 3.8}
   /// Default: 1.0 (neutral) if not found
   final Map<String, double> userAffinities;
   ```

2. **Update constructor:**
   ```dart
   this.userAffinities = const {}, // Initialize empty map
   ```

3. **Update `fromMap` factory:**
   ```dart
   userAffinities: _getAffinityMap(data),
   ```
   
   Add helper method:
   ```dart
   /// Parse affinity map from Firestore data
   /// Safely converts Map<String, dynamic> to Map<String, double>
   static Map<String, double> _getAffinityMap(Map<String, dynamic> data) {
     final value = data['userAffinities'];
     if (value is Map) {
       return Map<String, double>.from(
         value.map((key, val) => MapEntry(
           key.toString(), val is num ? val.toDouble() : 1.0,
         )),
       );
     }
     return {};
   }
   ```

4. **Update `toMap` method:**
   ```dart
   'userAffinities': userAffinities,
   ```

5. **Add helper method:**
   ```dart
   /// Get affinity score for a target (user or page)
   /// Returns 1.0 (neutral) if not found
   double getAffinityFor(String targetId) {
     return userAffinities[targetId] ?? 1.0;
   }
   ```

6. **Update `props` for Equatable:**
   ```dart
   userAffinities, // Added for equality checks
   ```

**Note:** This field was already added in Phase 1 of the previous plan, so this may already be complete.

---

### 1.2 `PostModel` (`lib/models/user_model.dart`)

**Objective:** No changes needed. We will calculate `score` on-the-fly in the app.

**Optional Enhancement (Not Required):**
- Add a temporary `double? computedScore;` field that is NOT saved to Firestore (for ranking calculation)
- Or create a wrapper class `RankedPost` that extends `PostModel` with a `score` field

**Recommendation:** Use a wrapper class to avoid polluting the model:
```dart
class RankedPost {
  final PostModel post;
  final double score;
  
  RankedPost({required this.post, required this.score});
}
```

---

## Phase 2: Backend (Cloud Function) Architecture

### 2.1 Simplified Cloud Function: `onUserInteraction`

**Objective:** Update user affinity scores when they interact with posts.

**File:** `functions/index.js`

**Implementation:**

```javascript
/**
 * Update affinity when user likes a post
 * Triggered when a reaction is created in posts/{postId}/reactions/{userId}
 */
exports.onUserInteraction = onDocumentCreated(
  'posts/{postId}/reactions/{userId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data associated with the event');
      return null;
    }
    
    try {
      const postId = event.params.postId;
      const userId = event.params.userId; // User who liked
      
      // Get post to find author
      const postDoc = await admin.firestore()
        .collection('posts')
        .doc(postId)
        .get();
      
      if (!postDoc.exists) {
        return null;
      }
      
      const postData = postDoc.data();
      const postAuthorId = postData.authorId;
      const postPageId = postData.pageId || null;
      
      // Don't update affinity if user interacts with own post
      if (userId === postAuthorId) {
        return null;
      }
      
      // Target is pageId (if page post) or authorId (if user post)
      const targetId = postPageId || postAuthorId;
      
      // Update affinity atomically
      await updateAffinity(userId, targetId, 0.5); // +0.5 for like
      
      console.log(`Updated affinity for user ${userId} -> ${targetId} (like)`);
      return null;
    } catch (error) {
      console.error('Error updating affinity on like:', error);
      return null;
    }
  }
);

/**
 * Update affinity when user comments on a post
 */
exports.onUserInteractionComment = onDocumentCreated(
  'posts/{postId}/comments/{commentId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      return null;
    }
    
    try {
      const commentData = snap.data();
      const userId = commentData.userId; // User who commented
      const postId = event.params.postId;
      
      // Get post to find author
      const postDoc = await admin.firestore()
        .collection('posts')
        .doc(postId)
        .get();
      
      if (!postDoc.exists) {
        return null;
      }
      
      const postData = postDoc.data();
      const postAuthorId = postData.authorId;
      const postPageId = postData.pageId || null;
      
      // Don't update affinity if user comments on own post
      if (userId === postAuthorId) {
        return null;
      }
      
      const targetId = postPageId || postAuthorId;
      
      // Update affinity atomically (comment is worth more than like)
      await updateAffinity(userId, targetId, 1.0); // +1.0 for comment
      
      console.log(`Updated affinity for user ${userId} -> ${targetId} (comment)`);
      return null;
    } catch (error) {
      console.error('Error updating affinity on comment:', error);
      return null;
    }
  }
);

/**
 * Update affinity score atomically
 * Increments affinity by specified amount, clamped between 0.1 and 10.0
 */
async function updateAffinity(userId, targetId, increment) {
  const userRef = admin.firestore().collection('users').doc(userId);
  
  return admin.firestore().runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    if (!userDoc.exists) {
      console.log(`User ${userId} not found for affinity update`);
      return;
    }
    
    const userData = userDoc.data();
    const affinities = userData.userAffinities || {};
    const currentAffinity = affinities[targetId] ?? 1.0;
    
    // Increment and clamp between 0.1 and 10.0
    const newAffinity = Math.max(0.1, Math.min(10.0, currentAffinity + increment));
    
    // Update the affinity map
    const updatedAffinities = { ...affinities };
    updatedAffinities[targetId] = newAffinity;
    
    // Optional: Enforce max 200 entries (LRU eviction if needed)
    if (Object.keys(updatedAffinities).length > 200) {
      // Remove lowest affinity entry
      const sorted = Object.entries(updatedAffinities)
        .sort((a, b) => a[1] - b[1]);
      delete updatedAffinities[sorted[0][0]];
      console.log(`LRU eviction: Removed lowest affinity entry for user ${userId}`);
    }
    
    transaction.update(userRef, {
      userAffinities: updatedAffinities,
    });
  });
}
```

**Key Differences from Fan-Out Approach:**
- ✅ No fan-out logic
- ✅ No personalized feed creation
- ✅ No time decay recalculation
- ✅ Only updates affinity scores (simple atomic transaction)

---

## Phase 3: Feed Logic Refactor (The "Ranking Engine")

### 3.1 `PostRepository` (`lib/repositories/post_repository.dart`)

**Objective:** Create a new method to fetch all candidate posts for ranking.

**New Method: `getFeedCandidates`**

```dart
/// Fetch all candidate posts for ranking (friends, followed pages, trending)
/// Returns a combined, deduplicated list of posts
Future<List<PostModel>> getFeedCandidates(String userId) async {
  try {
    // Step 1: Get user's friends and followed pages
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      debugPrint('PostRepository: User not found: $userId');
      return [];
    }

    final userData = userDoc.data()!;
    final friends = List<String>.from(userData['friends'] ?? []);
    final followedPages = List<String>.from(userData['followedPages'] ?? []);

    // Step 2: Run multiple queries in parallel
    final queries = <Future<QuerySnapshot>>[];

    // Query 1: Posts from friends (limit 100)
    if (friends.isNotEmpty) {
      // Firestore 'whereIn' limit is 10, so batch if needed
      for (int i = 0; i < friends.length; i += 10) {
        final batch = friends.sublist(
          i,
          i + 10 > friends.length ? friends.length : i + 10,
        );
        queries.add(
          _db
              .collection('posts')
              .where('deleted', isEqualTo: false)
              .where('authorId', whereIn: batch)
              .orderBy('timestamp', descending: true)
              .limit(100)
              .get(),
        );
      }
    }

    // Query 2: Posts from followed pages (limit 100)
    if (followedPages.isNotEmpty) {
      for (int i = 0; i < followedPages.length; i += 10) {
        final batch = followedPages.sublist(
          i,
          i + 10 > followedPages.length ? followedPages.length : i + 10,
        );
        queries.add(
          _db
              .collection('posts')
              .where('deleted', isEqualTo: false)
              .where('pageId', whereIn: batch)
              .orderBy('timestamp', descending: true)
              .limit(100)
              .get(),
        );
      }
    }

    // Query 3: Trending posts (limit 50)
    queries.add(
      _db
          .collection('posts')
          .where('deleted', isEqualTo: false)
          .where('visibility', isEqualTo: 'public')
          .orderBy('trendingScore', descending: true)
          .limit(50)
          .get(),
    );

    // Step 3: Execute all queries in parallel
    final results = await Future.wait(queries);

    // Step 4: Combine and deduplicate
    final allPosts = <PostModel>[];
    final seenIds = <String>{};

    for (final snapshot in results) {
      for (final doc in snapshot.docs) {
        final post = PostModel.fromDoc(doc);
        if (!seenIds.contains(post.id)) {
          allPosts.add(post);
          seenIds.add(post.id);
        }
      }
    }

    debugPrint(
      'PostRepository: Fetched ${allPosts.length} candidate posts '
      '(${friends.length} friends, ${followedPages.length} pages)',
    );

    return allPosts;
  } catch (e) {
    debugPrint('PostRepository: Error getting feed candidates: $e');
    rethrow;
  }
}
```

**Key Features:**
- ✅ Parallel queries using `Future.wait`
- ✅ Handles Firestore `whereIn` limit (10 items per query)
- ✅ Deduplicates posts using `Set<String>`
- ✅ Returns combined list ready for ranking

---

### 3.2 `ForYouFeedBloc` (`lib/blocs/for_you_feed_bloc.dart`)

**Objective:** Transform the BLoC into a "Ranking Engine" that calculates scores on the client.

**Refactored `_onLoadForYouFeed` Handler:**

```dart
Future<void> _onLoadForYouFeed(
  LoadForYouFeedEvent event,
  Emitter<ForYouFeedState> emit,
) async {
  try {
    emit(ForYouFeedLoading());

    // Step 1: Get current user (contains userAffinities map)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      emit(ForYouFeedError('User not authenticated'));
      return;
    }

    final userDoc = await _userRepository.getUser(currentUser.uid);
    if (userDoc == null) {
      emit(ForYouFeedError('User not found'));
      return;
    }

    // Step 2: Fetch candidate posts
    final List<PostModel> candidates =
        await _postRepository.getFeedCandidates(currentUser.uid);

    if (candidates.isEmpty) {
      emit(ForYouFeedLoaded(posts: []));
      return;
    }

    // Step 3: Ranking Loop - Calculate score for each post
    final rankedPosts = candidates.map((post) {
      // Calculate Affinity (u)
      final targetId = post.pageId ?? post.authorId;
      final double affinity = userDoc.getAffinityFor(targetId);

      // Calculate Content Weight (w)
      final double contentWeight = _calculateContentWeight(post);

      // Calculate Time Decay (d)
      final double timeDecay = _calculateTimeDecay(post.timestamp);

      // Calculate final score
      final double score = affinity * contentWeight * timeDecay;

      return RankedPost(post: post, score: score);
    }).toList();

    // Step 4: Sort by score (descending)
    rankedPosts.sort((a, b) => b.score.compareTo(a.score));

    // Step 5: Content Injection (Algorithm 3)
    final List<FeedItem> finalFeed = [];
    int postCount = 0;

    for (final rankedPost in rankedPosts) {
      // Add the post
      finalFeed.add(PostFeedItem(post: rankedPost.post));
      postCount++;

      // Insert ad every 8 posts
      if (postCount % 8 == 0) {
        try {
          final ad = await _adService?.loadNativeAd();
          if (ad != null) {
            finalFeed.add(AdFeedItem(ad: ad));
          }
        } catch (e) {
          debugPrint('Error loading ad: $e');
        }
      }
    }

    // Insert boosted posts at the top (if any)
    final boostedPosts = rankedPosts
        .where((rp) => rp.post.isBoosted &&
            rp.post.boostEndTime != null &&
            rp.post.boostEndTime!.toDate().isAfter(DateTime.now()))
        .map((rp) => PostFeedItem(post: rp.post))
        .toList();

    finalFeed.insertAll(0, boostedPosts);

    // Step 6: Emit final feed
    emit(ForYouFeedLoaded(posts: finalFeed));
  } catch (e) {
    debugPrint('ForYouFeedBloc: Error loading feed: $e');
    emit(ForYouFeedError(e.toString()));
  }
}
```

**Helper Methods in BLoC:**

```dart
/// Calculate content weight based on post type
double _calculateContentWeight(PostModel post) {
  // Use contentType enum if available
  if (post.contentType != null) {
    switch (post.contentType) {
      case PostContentType.text:
        return 1.0;
      case PostContentType.image:
        return 1.2;
      case PostContentType.video:
        return 1.5;
      case PostContentType.link:
        return 1.3;
      case PostContentType.poll:
        return 1.1;
      case PostContentType.mixed:
        return 1.4;
    }
  }

  // Fallback: Infer from media types
  final hasVideo = post.mediaItems.any((item) => item.type == 'video');
  final hasImage = post.mediaItems.any((item) => item.type == 'image');
  final hasLink = post.linkPreview != null;

  if (hasLink) return 1.3;
  if (hasVideo && hasImage) return 1.4;
  if (hasVideo) return 1.5;
  if (hasImage) return 1.2;
  return 1.0; // Text
}

/// Calculate time decay using exponential decay formula
double _calculateTimeDecay(DateTime postTimestamp) {
  final now = DateTime.now();
  final hoursSinceCreation = now.difference(postTimestamp).inHours.toDouble();
  
  // Exponential decay: e^(-0.1 * hours)
  // After 24 hours: ~0.08
  // After 48 hours: ~0.006
  // After 72 hours: ~0.0005
  return math.exp(-0.1 * hoursSinceCreation);
}
```

**New Wrapper Class (Optional):**

```dart
// lib/models/ranked_post.dart
class RankedPost {
  final PostModel post;
  final double score;

  RankedPost({required this.post, required this.score});
}
```

**Key Features:**
- ✅ Client-side ranking calculation
- ✅ Uses `userAffinities` from current user
- ✅ Calculates all three components: Affinity, Weight, Time Decay
- ✅ Sorts by score
- ✅ Handles content injection (Ads, Boosted Posts)

---

## Phase 4: High-Priority Bug Fix (The "New Post Problem")

### 4.1 `create_post_screen.dart`

**Objective:** Notify `FollowingFeedBloc` when a new post is created.

**Changes Required:**

```dart
// After successful post creation
final result = await _postRepository.createPost(...);

if (result != null && context.mounted) {
  // Notify FollowingFeedBloc to refresh
  context.read<FollowingFeedBloc>().add(
    LoadFeedEvent(refresh: true),
  );
  
  // Navigate back or show success
  Navigator.pop(context, true);
}
```

### 4.2 `following_feed_bloc.dart`

**Objective:** Ensure `LoadFeedEvent` correctly refreshes the feed.

**Changes Required:**

```dart
Future<void> _onLoadFeed(
  LoadFeedEvent event,
  Emitter<FollowingFeedState> emit,
) async {
  try {
    // If refresh is requested, reset pagination
    if (event.refresh) {
      _lastDocument = null;
      emit(FollowingFeedLoading());
    }

    // Fetch from network (not cache) if refreshing
    final (posts, lastDoc) = await _postRepository.getFeedForUserWithPagination(
      userId: FirebaseAuth.instance.currentUser!.uid,
      lastDocument: _lastDocument,
      limit: 20,
    );

    _lastDocument = lastDoc;

    if (event.refresh) {
      emit(FollowingFeedLoaded(posts: posts));
    } else {
      final currentState = state;
      if (currentState is FollowingFeedLoaded) {
        emit(FollowingFeedLoaded(
          posts: [...currentState.posts, ...posts],
        ));
      } else {
        emit(FollowingFeedLoaded(posts: posts));
      }
    }
  } catch (e) {
    emit(FollowingFeedError(e.toString()));
  }
}
```

---

## Implementation Checklist

### Phase 1: Data Model ✅ (Already Complete)
- [x] Add `userAffinities` to `UserModel`
- [x] Update `fromMap`, `toMap`, `props`
- [x] Add `getAffinityFor()` helper method

### Phase 2: Backend
- [ ] Implement `onUserInteraction` Cloud Function
- [ ] Implement `updateAffinity()` helper function
- [ ] Deploy functions

### Phase 3: Feed Logic Refactor
- [ ] Create `RankedPost` wrapper class (optional)
- [ ] Implement `getFeedCandidates()` in `PostRepository`
- [ ] Refactor `ForYouFeedBloc._onLoadForYouFeed()`
- [ ] Add `_calculateContentWeight()` helper
- [ ] Add `_calculateTimeDecay()` helper
- [ ] Implement content injection (Ads, Boosted Posts)

### Phase 4: Bug Fix
- [ ] Update `create_post_screen.dart` to notify `FollowingFeedBloc`
- [ ] Update `FollowingFeedBloc` to handle refresh correctly

---

## Performance Considerations

### Advantages:
- ✅ Lower backend costs (no fan-out writes)
- ✅ Simpler Cloud Functions
- ✅ Easier to debug (all logic in Flutter)
- ✅ Can iterate on ranking algorithm without backend changes

### Considerations:
- ⚠️ Client device does more computation (typically fine for modern devices)
- ⚠️ Fetches more posts initially (but still efficient with parallel queries)
- ⚠️ Ranking happens on every feed load (but cached state can help)

---

## Migration Strategy

If you've already implemented the fan-out approach:

1. **Keep both systems running temporarily:**
   - Old: `personalizedFeed` queries (if implemented)
   - New: `getFeedCandidates()` + client-side ranking

2. **Feature flag:**
   ```dart
   final useClientSideRanking = true; // Feature flag
   
   if (useClientSideRanking) {
     // Use new approach
   } else {
     // Use old approach
   }
   ```

3. **Gradual rollout:**
   - Test with beta users first
   - Monitor performance
   - Switch all users when stable

---

## Summary

This client-side ranking approach is **much simpler** to implement than the fan-out pattern:

- ✅ **Backend:** Only 1-2 simple Cloud Functions (affinity updates)
- ✅ **Frontend:** Ranking logic in Flutter BLoC
- ✅ **Database:** Only stores affinity scores (already in `UserModel`)
- ✅ **No fan-out:** No pre-calculated feeds
- ✅ **Easy to iterate:** Change ranking algorithm in Flutter code

The ranking formula `Score = Affinity × Weight × Time Decay` is calculated on the device, making it easier to test and adjust without backend deployments.

