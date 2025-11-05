# Feed Ranking Algorithm Refactoring Plan
## Transition from Simple Fetch-Mix to Personalized Ranking System

**Document Version:** 1.0  
**Date:** 2024  
**Architect:** Principal Software Architect  
**Project:** Sonar Pulse Social App (Flutter + Firebase)

---

## Executive Summary

This document outlines a comprehensive 4-phase refactoring plan to transform our current feed system from a simple chronological/trending fetch-and-mix approach to a sophisticated, personalized ranking algorithm based on the formula:

```
Score = Affinity (u) × Content Weight (w) × Time Decay (d)
```

**Current State:**
- Simple chronological merging of posts from friends, public, and followed pages
- Basic scoring for boosted/trending posts
- No personalized ranking per user
- No affinity tracking between users

**Target State:**
- Personalized feed scores calculated per user
- Affinity tracking between users and pages
- Content-weighted scoring based on post type
- Time-decay for recency
- Scalable fan-out architecture for real-time feed updates

---

## Phase 1: Data Model & Schema Refactor

### 1.1 PostModel Enhancements

**File:** `lib/models/post_model.dart`

**New Fields to Add:**

```dart
class PostModel {
  // ... existing fields ...
  
  // NEW: Ranking Algorithm Fields
  /// Base content weight based on post type (calculated once on creation)
  /// Video = 1.5, Image = 1.2, Text = 1.0, Link = 1.3
  final double contentWeight;
  
  /// Shared post support - if this post is a share, reference original
  final String? sharedFromPostId;
  
  /// Link preview data for link posts
  final Map<String, dynamic>? linkPreview;
  
  /// Post type classification (for content weight calculation)
  final PostContentType contentType; // NEW ENUM
  
  // ... existing fields ...
}
```

**New Enum:**

```dart
enum PostContentType {
  text,      // contentWeight = 1.0
  image,     // contentWeight = 1.2
  video,     // contentWeight = 1.5
  link,      // contentWeight = 1.3
  poll,      // contentWeight = 1.1
  mixed,     // contentWeight = 1.4 (image + video)
}
```

**Implementation Details:**
- `contentWeight` is calculated **once** when the post is created (immutable)
- Calculation logic: Based on `mediaUrls` array and presence of `linkPreview`
- Default: `1.0` if no media detected
- `sharedFromPostId`: If present, this post inherits contentWeight from original
- `linkPreview`: Contains `url`, `title`, `description`, `imageUrl`, `domain`

**Migration Strategy:**
- Add fields with default values for existing posts
- Run a one-time Cloud Function to backfill `contentWeight` for existing posts
- Use `PostModel.fromDoc()` to handle missing fields gracefully

---

### 1.2 UserModel Affinity Storage

**File:** `lib/models/user_model.dart`

**Analysis: Option A vs Option B**

#### Option A: Embedded Map (Recommended for MVP)

```dart
class UserModel {
  // ... existing fields ...
  
  /// Affinity scores for users and pages this user interacts with
  /// Key: userId or pageId, Value: affinity score (0.0 to 10.0)
  /// Example: {'user_123': 5.2, 'page_456': 1.5, 'user_789': 3.8}
  final Map<String, double> userAffinities;
  
  // ... existing fields ...
}
```

**Pros:**
- ✅ Simple to query (no subcollection reads)
- ✅ Fast reads (single document fetch)
- ✅ Easy to update atomically
- ✅ Good for MVP (up to ~100-200 affinities per user)

**Cons:**
- ❌ Document size limit (1MB) - could be hit with heavy users
- ❌ Not scalable beyond ~500-1000 affinities
- ❌ All affinities loaded even if not needed

#### Option B: Subcollection (Recommended for Scale)

```dart
// New collection structure:
// users/{userId}/affinity/{targetId}
// Document fields: { score: 5.2, lastUpdated: Timestamp, interactionCount: 42 }
```

**Pros:**
- ✅ Unlimited scalability
- ✅ Only load needed affinities
- ✅ Can add metadata (interactionCount, lastUpdated)
- ✅ Better for analytics

**Cons:**
- ❌ More complex queries (need subcollection reads)
- ❌ Multiple reads for feed calculation
- ❌ More Firestore operations = higher cost

**Recommendation: Hybrid Approach**

**Phase 1.1 (MVP):** Use Option A (embedded map) with a size limit check
- Add `userAffinities` map to `UserModel`
- Set maximum size: 200 entries per user
- When limit reached, implement LRU eviction (remove oldest/lowest affinities)

**Phase 1.2 (Scale):** Migrate to Option B (subcollection) when needed
- Add migration Cloud Function
- Move affinities to subcollection
- Update all queries to use new structure

**Initial Implementation (Option A):**

```dart
class UserModel {
  // ... existing fields ...
  
  /// Affinity scores for users and pages
  /// Max 200 entries (enforced in Cloud Functions)
  final Map<String, double> userAffinities;
  
  // ... existing fields ...
  
  /// Get affinity score for a target (user or page)
  /// Returns 1.0 (neutral) if not found
  double getAffinityFor(String targetId) {
    return userAffinities[targetId] ?? 1.0;
  }
}
```

**Migration Script (Future):**
```javascript
// Cloud Function: migrateAffinitiesToSubcollection
// Runs one-time to move from Option A to Option B
```

---

### 1.3 New Collection: Personalized Feed

**Structure:**
```
users/{userId}/personalizedFeed/{postId}
```

**Document Schema:**
```json
{
  "postId": "post_123",
  "authorId": "user_456",
  "pageId": null,
  "score": 8.5,
  "calculatedAt": Timestamp,
  "expiresAt": Timestamp,  // Used for cleanup (posts older than 30 days)
  "postRef": DocumentReference,  // Reference to actual post document
  "contentWeight": 1.5,
  "affinityScore": 5.7,
  "timeDecayMultiplier": 0.85
}
```

**Purpose:**
- Pre-calculated feed entries per user
- Populated by Cloud Functions (Phase 2)
- Enables single-query feed fetching
- Supports efficient pagination

**Index Required:**
```json
{
  "collectionGroup": "personalizedFeed",
  "queryScope": "COLLECTION_GROUP",
  "fields": [
    { "fieldPath": "score", "order": "DESCENDING" },
    { "fieldPath": "calculatedAt", "order": "DESCENDING" }
  ]
}
```

---

## Phase 2: Backend (Cloud Function) Architecture

### 2.1 Fan-Out Strategy Overview

**Problem:** When User A creates a post, we need to:
1. Calculate personalized score for each of User A's followers
2. Insert this post into each follower's `personalizedFeed` collection
3. Do this efficiently and atomically

**Solution: Fan-Out Pattern**

```
onPostCreated (Trigger)
    ↓
Calculate contentWeight (w)
    ↓
Get all followers (friends + page followers)
    ↓
For each follower (batch of 500):
    ↓
    Calculate affinity (u) for this follower
    ↓
    Calculate timeDecay (d) [always 1.0 at creation]
    ↓
    Calculate score = u × w × d
    ↓
    Batch write to follower's personalizedFeed
```

### 2.2 Cloud Function: `onPostCreated`

**File:** `functions/index.js`

**Trigger:** `onDocumentCreated('posts/{postId}')`

**Implementation Plan:**

```javascript
exports.onPostCreated = onDocumentCreated(
  'posts/{postId}',
  async (event) => {
    const postId = event.params.postId;
    const postData = event.data.data();
    
    // Step 1: Calculate contentWeight (w)
    const contentWeight = calculateContentWeight(postData);
    
    // Step 2: Update post with contentWeight
    await admin.firestore()
      .collection('posts')
      .doc(postId)
      .update({ contentWeight });
    
    // Step 3: Get author's followers (friends + page followers)
    const authorId = postData.authorId;
    const followers = await getFollowers(authorId, postData.pageId);
    
    if (followers.length === 0) {
      return null; // No followers, nothing to fan-out
    }
    
    // Step 4: Fan-out in batches (500 at a time)
    const batchSize = 500;
    for (let i = 0; i < followers.length; i += batchSize) {
      const batch = followers.slice(i, i + batchSize);
      await fanOutToFollowers(
        postId,
        authorId,
        postData.pageId,
        contentWeight,
        batch
      );
    }
  }
);
```

**Helper Functions:**

```javascript
/**
 * Calculate contentWeight based on post type
 */
function calculateContentWeight(postData) {
  const hasVideo = postData.mediaUrls?.some(url => 
    url.includes('.mp4') || url.includes('.mov')
  );
  const hasImage = postData.mediaUrls?.some(url => 
    url.includes('.jpg') || url.includes('.png')
  );
  const hasLink = postData.linkPreview != null;
  
  if (hasVideo && hasImage) return 1.4; // Mixed
  if (hasVideo) return 1.5; // Video
  if (hasLink) return 1.3; // Link
  if (hasImage) return 1.2; // Image
  return 1.0; // Text
}

/**
 * Get all followers (friends + page followers)
 */
async function getFollowers(authorId, pageId) {
  const followers = new Set();
  
  // Get friends (if user post)
  if (!pageId) {
    const authorDoc = await admin.firestore()
      .collection('users')
      .doc(authorId)
      .get();
    const friends = authorDoc.data()?.friends || [];
    friends.forEach(friendId => followers.add(friendId));
  }
  
  // Get page followers (if page post)
  if (pageId) {
    const pageDoc = await admin.firestore()
      .collection('pages')
      .doc(pageId)
      .get();
    const followerCount = pageDoc.data()?.followerCount || 0;
    
    // Get followers from followedPages array in users
    // Note: This requires a compound query or collection group query
    const followersSnapshot = await admin.firestore()
      .collectionGroup('followers')
      .where('pageId', '==', pageId)
      .limit(1000) // Adjust based on your needs
      .get();
    
    followersSnapshot.docs.forEach(doc => {
      const userId = doc.data().userId;
      if (userId) followers.add(userId);
    });
  }
  
  return Array.from(followers);
}

/**
 * Fan-out post to a batch of followers
 */
async function fanOutToFollowers(
  postId,
  authorId,
  pageId,
  contentWeight,
  followerIds
) {
  const batch = admin.firestore().batch();
  const now = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days
  );
  
  // Get affinities for all followers in parallel
  const affinityPromises = followerIds.map(async (followerId) => {
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(followerId)
      .get();
    const affinities = userDoc.data()?.userAffinities || {};
    const targetId = pageId || authorId;
    const affinity = affinities[targetId] ?? 1.0;
    return { followerId, affinity };
  });
  
  const affinities = await Promise.all(affinityPromises);
  
  // Create personalized feed entries
  affinities.forEach(({ followerId, affinity }) => {
    const timeDecay = 1.0; // Always 1.0 at creation
    const score = affinity * contentWeight * timeDecay;
    
    const feedRef = admin.firestore()
      .collection('users')
      .doc(followerId)
      .collection('personalizedFeed')
      .doc(postId);
    
    batch.set(feedRef, {
      postId,
      authorId,
      pageId: pageId || null,
      score,
      calculatedAt: now,
      expiresAt,
      postRef: admin.firestore().collection('posts').doc(postId),
      contentWeight,
      affinityScore: affinity,
      timeDecayMultiplier: timeDecay,
    });
  });
  
  await batch.commit();
}
```

**Performance Optimizations:**
- Use `Promise.all()` for parallel affinity reads
- Batch writes in groups of 500 (Firestore limit)
- Use `set()` instead of `update()` for feed entries (idempotent)
- Add `expiresAt` for automatic cleanup via scheduled function

---

### 2.3 Cloud Function: `onUserInteraction`

**File:** `functions/index.js`

**Triggers:**
- `onDocumentCreated('posts/{postId}/reactions/{userId}')` - Like
- `onDocumentCreated('posts/{postId}/comments/{commentId}')` - Comment
- `onDocumentCreated('posts/{postId}/shares/{shareId}')` - Share

**Implementation Plan:**

```javascript
/**
 * Update affinity when user likes a post
 */
exports.onPostLiked = onDocumentCreated(
  'posts/{postId}/reactions/{userId}',
  async (event) => {
    const postId = event.params.postId;
    const userId = event.params.userId; // User who liked
    
    // Get post to find author
    const postDoc = await admin.firestore()
      .collection('posts')
      .doc(postId)
      .get();
    
    if (!postDoc.exists) return null;
    
    const postData = postDoc.data();
    const authorId = postData.authorId;
    const pageId = postData.pageId;
    const targetId = pageId || authorId;
    
    // Update affinity (increment by 0.1, max 10.0)
    await updateAffinity(userId, targetId, 0.1);
    
    // Recalculate feed scores for this user
    await recalculateFeedScores(userId, targetId);
  }
);

/**
 * Update affinity when user comments on a post
 */
exports.onPostCommented = onDocumentCreated(
  'posts/{postId}/comments/{commentId}',
  async (event) => {
    const commentData = event.data.data();
    const userId = commentData.authorId; // User who commented
    const postId = event.params.postId;
    
    // Get post to find author
    const postDoc = await admin.firestore()
      .collection('posts')
      .doc(postId)
      .get();
    
    if (!postDoc.exists) return null;
    
    const postData = postDoc.data();
    const authorId = postData.authorId;
    const pageId = postData.pageId;
    const targetId = pageId || authorId;
    
    // Update affinity (increment by 0.2, max 10.0)
    await updateAffinity(userId, targetId, 0.2);
    
    // Recalculate feed scores for this user
    await recalculateFeedScores(userId, targetId);
  }
);

/**
 * Update affinity score atomically
 */
async function updateAffinity(userId, targetId, increment) {
  const userRef = admin.firestore().collection('users').doc(userId);
  
  return admin.firestore().runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    if (!userDoc.exists) return;
    
    const affinities = userDoc.data().userAffinities || {};
    const currentAffinity = affinities[targetId] ?? 1.0;
    const newAffinity = Math.min(10.0, currentAffinity + increment);
    
    // Enforce max 200 entries (LRU eviction if needed)
    const updatedAffinities = { ...affinities };
    updatedAffinities[targetId] = newAffinity;
    
    if (Object.keys(updatedAffinities).length > 200) {
      // Remove lowest affinity entry
      const sorted = Object.entries(updatedAffinities)
        .sort((a, b) => a[1] - b[1]);
      delete updatedAffinities[sorted[0][0]];
    }
    
    transaction.update(userRef, {
      userAffinities: updatedAffinities,
    });
  });
}

/**
 * Recalculate feed scores for posts from a specific author/page
 */
async function recalculateFeedScores(userId, targetId) {
  // Get all posts from this target in user's personalized feed
  const feedSnapshot = await admin.firestore()
    .collection('users')
    .doc(userId)
    .collection('personalizedFeed')
    .where('authorId', '==', targetId)
    .get();
  
  // Get user's current affinity for this target
  const userDoc = await admin.firestore()
    .collection('users')
    .doc(userId)
    .get();
  const affinities = userDoc.data()?.userAffinities || {};
  const affinity = affinities[targetId] ?? 1.0;
  
  // Recalculate scores for all posts
  const batch = admin.firestore().batch();
  const now = Date.now();
  
  feedSnapshot.docs.forEach((feedDoc) => {
    const feedData = feedDoc.data();
    const postId = feedData.postId;
    
    // Get post to get contentWeight
    // Note: Could cache this or store in feed entry
    const contentWeight = feedData.contentWeight;
    
    // Calculate time decay
    const postRef = admin.firestore().collection('posts').doc(postId);
    // For now, we'll need to fetch post or store timestamp in feed entry
    const timeDecay = calculateTimeDecay(feedData.calculatedAt);
    
    const newScore = affinity * contentWeight * timeDecay;
    
    batch.update(feedDoc.ref, {
      score: newScore,
      affinityScore: affinity,
      timeDecayMultiplier: timeDecay,
      calculatedAt: admin.firestore.Timestamp.now(),
    });
  });
  
  await batch.commit();
}
```

---

### 2.4 Cloud Function: `calculateTimeDecay` (Scheduled)

**File:** `functions/index.js`

**Trigger:** `onSchedule('every 1 hours')` (runs hourly)

**Purpose:** Recalculate time decay for all posts in all personalized feeds

**Implementation:**

```javascript
exports.recalculateTimeDecay = onSchedule(
  { schedule: 'every 1 hours', timeZone: 'UTC' },
  async (event) => {
    // Get all users (or sample if too many)
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .limit(1000) // Process in batches
      .get();
    
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      
      // Get all feed entries for this user
      const feedSnapshot = await admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('personalizedFeed')
        .get();
      
      const batch = admin.firestore().batch();
      let batchCount = 0;
      
      feedSnapshot.docs.forEach((feedDoc) => {
        const feedData = feedDoc.data();
        const timeDecay = calculateTimeDecay(feedData.calculatedAt);
        
        const newScore = feedData.affinityScore * 
                        feedData.contentWeight * 
                        timeDecay;
        
        batch.update(feedDoc.ref, {
          score: newScore,
          timeDecayMultiplier: timeDecay,
        });
        
        batchCount++;
        if (batchCount >= 500) {
          batch.commit();
          batchCount = 0;
        }
      });
      
      if (batchCount > 0) {
        await batch.commit();
      }
    }
  }
);
```

**Time Decay Formula:**

```javascript
function calculateTimeDecay(calculatedAtTimestamp) {
  const now = Date.now();
  const calculatedAt = calculatedAtTimestamp.toMillis();
  const hoursSinceCreation = (now - calculatedAt) / (1000 * 60 * 60);
  
  // Exponential decay: e^(-0.1 * hours)
  // After 24 hours: ~0.08
  // After 48 hours: ~0.006
  // After 72 hours: ~0.0005
  return Math.exp(-0.1 * hoursSinceCreation);
}
```

---

### 2.5 Cloud Function: `cleanupExpiredFeedEntries` (Scheduled)

**File:** `functions/index.js`

**Trigger:** `onSchedule('every 24 hours')`

**Purpose:** Remove feed entries older than 30 days

```javascript
exports.cleanupExpiredFeedEntries = onSchedule(
  { schedule: 'every 24 hours', timeZone: 'UTC' },
  async (event) => {
    const now = admin.firestore.Timestamp.now();
    
    // Get all users (or process in batches)
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .limit(1000)
      .get();
    
    for (const userDoc of usersSnapshot.docs) {
      const expiredEntries = await admin.firestore()
        .collection('users')
        .doc(userDoc.id)
        .collection('personalizedFeed')
        .where('expiresAt', '<=', now)
        .get();
      
      const batch = admin.firestore().batch();
      expiredEntries.docs.forEach(doc => batch.delete(doc.ref));
      
      if (expiredEntries.docs.length > 0) {
        await batch.commit();
      }
    }
  }
);
```

---

## Phase 3: Feed Logic Refactor (Repository & BLoC)

### 3.1 PostRepository Changes

**File:** `lib/repositories/post_repository.dart`

**Old Method (to remove):**
```dart
// REMOVE: getUnifiedFeed() - complex multi-query logic
// REMOVE: getTrendingPosts() - no longer needed
// REMOVE: getBoostedPosts() - no longer needed
```

**New Method:**

```dart
/// Get personalized "For You" feed for a user
/// Uses pre-calculated scores from personalizedFeed collection
Future<(List<PostModel>, DocumentSnapshot?)> getForYouFeed({
  required String userId,
  DocumentSnapshot? lastDocument,
  int limit = 20,
}) async {
  try {
    // Single query against personalized feed
    Query query = _db
        .collection('users')
        .doc(userId)
        .collection('personalizedFeed')
        .orderBy('score', descending: true)
        .limit(limit);
    
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    
    final snapshot = await query.get();
    
    // Extract post references
    final postRefs = snapshot.docs
        .map((doc) => doc.data()['postRef'] as DocumentReference)
        .whereType<DocumentReference>()
        .toList();
    
    // Batch fetch actual post documents
    final posts = <PostModel>[];
    for (final ref in postRefs) {
      try {
        final postDoc = await ref.get();
        if (postDoc.exists) {
          posts.add(PostModel.fromDoc(postDoc));
        }
      } catch (e) {
        debugPrint('PostRepository: Error fetching post ${ref.id}: $e');
      }
    }
    
    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    
    return (posts, lastDoc);
  } catch (e) {
    debugPrint('PostRepository: Error getting For You feed: $e');
    rethrow;
  }
}
```

**Keep Existing Method (for Following Feed):**

```dart
/// Get chronological "Following" feed
/// This remains simple - no scoring algorithm
Future<(List<PostModel>, DocumentSnapshot?)> getFeedForUserWithPagination({
  required String userId,
  DocumentSnapshot? lastDocument,
  int limit = 10,
}) async {
  // ... existing implementation unchanged ...
  // This is Algorithm 2: Simple chronological feed
}
```

---

### 3.2 ForYouFeedBloc Refactor

**File:** `lib/blocs/for_you_feed_bloc.dart`

**Changes:**

1. **Remove complex scoring logic** - Cloud Functions handle this now
2. **Simplify to single repository call**
3. **Add content injection for ads and boosted posts**

**New Implementation:**

```dart
class ForYouFeedBloc extends Bloc<ForYouFeedEvent, ForYouFeedState> {
  final PostRepository _postRepository;
  final AdService? _adService;
  
  ForYouFeedBloc({
    required PostRepository postRepository,
    AdService? adService,
  })  : _postRepository = postRepository,
        _adService = adService,
        super(ForYouFeedInitial()) {
    on<LoadForYouFeedEvent>(_onLoadForYouFeed);
    on<LoadMoreForYouFeedEvent>(_onLoadMoreForYouFeed);
  }
  
  Future<void> _onLoadForYouFeed(
    LoadForYouFeedEvent event,
    Emitter<ForYouFeedState> emit,
  ) async {
    emit(ForYouFeedLoading());
    
    try {
      // Step 1: Get personalized feed posts
      final result = await _postRepository.getForYouFeed(
        userId: event.userId,
        limit: 20,
      );
      
      var posts = result.$1;
      final lastDoc = result.$2;
      
      // Step 2: Inject ads (every 8 posts)
      posts = await _injectAds(posts, startIndex: 0);
      
      // Step 3: Inject boosted posts at fixed positions (3 and 10)
      posts = await _injectBoostedPosts(posts, userId: event.userId);
      
      // Step 4: Map to PostFeedItem
      final feedItems = posts.map((post) {
        return PostFeedItem(
          post: post,
          displayType: _determineDisplayType(post),
        );
      }).toList();
      
      emit(ForYouFeedLoaded(
        posts: feedItems,
        hasMore: posts.length == 20,
        lastDocument: lastDoc,
      ));
    } catch (e) {
      emit(ForYouFeedError(e.toString()));
    }
  }
  
  /// Inject ads every 8 posts
  Future<List<PostModel>> _injectAds(
    List<PostModel> posts, {
    required int startIndex,
  }) async {
    if (_adService == null) return posts;
    
    final postsWithAds = <PostModel>[];
    int postCount = 0;
    
    for (final post in posts) {
      postsWithAds.add(post);
      postCount++;
      
      // Insert ad every 8 posts
      if ((startIndex + postCount) % 8 == 0) {
        try {
          final ad = await _adService!
              .loadNativeAd()
              .timeout(Duration(seconds: 5));
          
          if (ad != null) {
            // Create AdFeedItem (not PostModel, but handled in mapping)
            // For now, we'll skip actual ad injection here
            // and handle it in the UI layer
          }
        } catch (e) {
          debugPrint('ForYouFeedBloc: Error loading ad: $e');
        }
      }
    }
    
    return postsWithAds;
  }
  
  /// Inject boosted posts at fixed positions (3 and 10)
  Future<List<PostModel>> _injectBoostedPosts(
    List<PostModel> posts, {
    required String userId,
  }) async {
    // Fetch boosted posts separately
    final boostedPosts = await _postRepository.getBoostedPosts(
      userTargeting: {/* user targeting data */},
      limit: 5,
    );
    
    if (boostedPosts.isEmpty) return posts;
    
    final injectedPosts = List<PostModel>.from(posts);
    int boostedIndex = 0;
    
    // Insert at position 3 (index 2)
    if (injectedPosts.length >= 2 && boostedIndex < boostedPosts.length) {
      injectedPosts.insert(2, boostedPosts[boostedIndex]);
      boostedIndex++;
    }
    
    // Insert at position 10 (index 9)
    if (injectedPosts.length >= 9 && boostedIndex < boostedPosts.length) {
      injectedPosts.insert(9, boostedPosts[boostedIndex]);
      boostedIndex++;
    }
    
    return injectedPosts;
  }
  
  PostDisplayType _determineDisplayType(PostModel post) {
    if (post.isBoosted) return PostDisplayType.boosted;
    if (post.trendingScore > 100) return PostDisplayType.trending;
    if (post.pageId != null) return PostDisplayType.page;
    return PostDisplayType.organic;
  }
}
```

---

### 3.3 FollowingFeedBloc (No Changes)

**File:** `lib/blocs/following_feed_bloc.dart`

**Status:** ✅ **Keep as-is**

This BLoC should remain simple and chronological. It uses `getFeedForUserWithPagination()` which already includes followed pages.

**No algorithm changes needed** - this is Algorithm 2 (chronological feed).

---

## Phase 4: High-Priority Bug Fix (The "New Post Problem")

### 4.1 Problem Statement

When a user creates a post:
1. Post is created in Firestore
2. User navigates back to feed
3. **BUG:** New post doesn't appear immediately (must pull-to-refresh)
4. **Root Cause:** No notification to `FollowingFeedBloc` about new post

### 4.2 Solution: Optimistic Post Creation

**File:** `lib/screens/create_post_screen.dart` (or wherever post creation happens)

**Changes:**

```dart
// After successful post creation:
final newPost = await _postRepository.createPost(...);

// Get FollowingFeedBloc from context
final followingFeedBloc = context.read<FollowingFeedBloc>();

// Dispatch optimistic update event
followingFeedBloc.add(
  OptimisticPostCreatedEvent(
    post: newPost,
    userId: currentUser.uid,
  ),
);

// Navigate back
Navigator.pop(context);
```

**File:** `lib/blocs/following_feed_bloc.dart`

**New Event:**

```dart
// Add to FollowingFeedEvent class
class OptimisticPostCreatedEvent extends FollowingFeedEvent {
  final PostModel post;
  final String userId;
  
  OptimisticPostCreatedEvent({
    required this.post,
    required this.userId,
  });
}
```

**New Handler:**

```dart
void on<OptimisticPostCreatedEvent>(
  OptimisticPostCreatedEvent event,
  Emitter<FollowingFeedState> emit,
) async {
  if (state is FollowingFeedLoaded) {
    final currentState = state as FollowingFeedLoaded;
    
    // Check if post is already in feed (avoid duplicates)
    final exists = currentState.posts.any(
      (item) => item.post.id == event.post.id,
    );
    
    if (exists) return;
    
    // Create PostFeedItem for new post
    final newItem = PostFeedItem(
      post: event.post,
      displayType: event.post.pageId != null
          ? PostDisplayType.page
          : PostDisplayType.organic,
    );
    
    // Add to top of feed
    final updatedPosts = [newItem, ...currentState.posts];
    
    emit(currentState.copyWith(
      posts: updatedPosts,
    ));
    
    // Optional: Trigger a background refresh to get latest data
    // This ensures server-side data (like reaction counts) are synced
    add(LoadFollowingFeedEvent(
      userId: event.userId,
      refresh: false, // Don't show loading indicator
    ));
  }
}
```

**Alternative Approach (Simpler):**

If you prefer a simpler solution, just trigger a refresh:

```dart
// In create_post_screen.dart after post creation:
final followingFeedBloc = context.read<FollowingFeedBloc>();
followingFeedBloc.add(
  LoadFollowingFeedEvent(
    userId: currentUser.uid,
    refresh: true, // This will show loading indicator
  ),
);
Navigator.pop(context);
```

**Recommendation:** Use the optimistic approach (first option) for better UX - post appears instantly, then syncs in background.

---

## Implementation Timeline

### Week 1: Phase 1 (Data Model)
- [ ] Add new fields to `PostModel`
- [ ] Add `userAffinities` to `UserModel`
- [ ] Create migration script for existing data
- [ ] Update `fromMap()` and `toMap()` methods
- [ ] Test model serialization

### Week 2: Phase 2 (Cloud Functions)
- [ ] Implement `onPostCreated` function
- [ ] Implement `onUserInteraction` functions
- [ ] Implement `recalculateTimeDecay` scheduled function
- [ ] Implement `cleanupExpiredFeedEntries` scheduled function
- [ ] Deploy and test functions
- [ ] Monitor performance and costs

### Week 3: Phase 3 (Feed Logic)
- [ ] Refactor `PostRepository.getForYouFeed()`
- [ ] Refactor `ForYouFeedBloc`
- [ ] Implement content injection (ads, boosted posts)
- [ ] Test feed ranking accuracy
- [ ] Update UI to handle new feed structure

### Week 4: Phase 4 (Bug Fix)
- [ ] Implement optimistic post creation
- [ ] Update `FollowingFeedBloc` event handlers
- [ ] Test new post visibility
- [ ] End-to-end testing

### Week 5: Testing & Optimization
- [ ] Load testing
- [ ] Performance optimization
- [ ] Cost analysis
- [ ] User acceptance testing

---

## Risk Assessment & Mitigation

### High Risk Areas:

1. **Cloud Function Costs**
   - **Risk:** Fan-out operations can be expensive
   - **Mitigation:** Batch operations, rate limiting, monitor costs daily

2. **Data Model Migration**
   - **Risk:** Breaking existing functionality
   - **Mitigation:** Gradual rollout, feature flags, backward compatibility

3. **Feed Performance**
   - **Risk:** Personalized feed queries may be slow
   - **Mitigation:** Proper indexing, caching, pagination

4. **Scaling Issues**
   - **Risk:** User with 10,000 followers creates bottleneck
   - **Mitigation:** Queue system, async processing, rate limiting

---

## Success Metrics

- **Feed Relevance:** User engagement (likes, comments) increases by 20%
- **Load Time:** Feed loads in < 2 seconds
- **Cost:** Cloud Functions costs stay within budget
- **User Satisfaction:** Positive feedback on feed quality

---

## Appendix: Firestore Indexes Required

```json
{
  "indexes": [
    {
      "collectionGroup": "personalizedFeed",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "score", "order": "DESCENDING" },
        { "fieldPath": "calculatedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "personalizedFeed",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "authorId", "order": "ASCENDING" },
        { "fieldPath": "score", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "personalizedFeed",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "expiresAt", "order": "ASCENDING" }
      ]
    }
  ]
}
```

---

**End of Document**

