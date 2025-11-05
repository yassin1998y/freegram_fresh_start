# Social Feed Ecosystem - Comprehensive Implementation Plan
## Freegram Social Media Feed Development Blueprint

**Tech Stack:**
- Flutter (SDK >= 3.2.6 < 4.0.0)
- Firebase (Firestore, Auth, Messaging, Cloud Functions, Realtime Database)
- BLoC Pattern (State Management)
- GetIt (Dependency Injection)
- Hive (Local Storage)
- Cloudinary (Media Hosting)

---

## Phase 1: Research & Engagement Strategy

### Core Components of Modern Social Feed Engagement (2025)

#### 1. Content Ranking Algorithms

**A. Chronological Feed**
- Pros: Simple, predictable, shows all content in order
- Cons: Can miss important content, no personalization
- Use Case: Best for "Following" tab where users want to see friends' posts

**B. Algorithmic Feed (ML-Powered)**
- Pros: Personalized, maximizes engagement, surfaces relevant content
- Cons: Complex, requires ML models, can feel "manipulative"
- Use Case: "For You" tab, discovery feed

**C. Hybrid Approach** (Recommended)
- Combine chronological for followed users + algorithmic for discovery
- Allows users to switch between "Following" and "For You" tabs
- Best of both worlds

#### 2. Discovery Mechanics

**A. "For You" Page**
- Algorithm-driven feed showing content from users you don't follow
- Based on: engagement history, interests, location, mutual connections
- Continuously learns from user behavior

**B. Hashtag-Based Discovery**
- Trending hashtags
- Hashtag search and explore
- Hashtag following
- Location-based hashtags

**C. Content-Based Recommendations**
- Similar content to what you've engaged with
- Based on post type (image/video/text), topics, interests
- Cross-promote related content

#### 3. User Interaction Patterns

**A. Reactions**
- Simple "Love" (like)
- Full emoji reaction set (❤️, 😂, 😮, 😢, 😡)
- Quick tap = like, long-press = reaction menu

**B. Ephemeral Content (Stories)**
- 24-hour disappearing content
- Story reactions/comments (private DMs)
- Story highlights (save to profile)
- Story views tracking

**C. Short-Form Video (Reels)**
- Vertical video feed (15s-60s)
- Autoplay with sound
- Swipe up/down navigation
- Reel-specific effects/filters
- Video editing tools

#### 4. Community Building

**A. Pages**
- Brand/community profiles
- Page followers (separate from personal followers)
- Page posts appear in feed with verification badge
- Page analytics

**B. Groups**
- Private/public groups
- Group posts appear in member feeds
- Group chats integrated
- Admin/moderator roles

**C. Public Threads**
- Long-form discussions
- Nested comments (threading)
- Quote/repost functionality

---

### Proposed Engagement-Boosting Features

Based on research and analysis of successful social platforms, here are **5 additional features** to boost engagement:

#### 1. **"Nearby Feed"** (Location-Based Discovery)
- **Concept**: Show posts from users in your geographical area (using existing Bluetooth/location infrastructure)
- **Engagement Impact**: High - Leverages your unique Bluetooth discovery tech
- **Justification**: Differentiates from competitors, creates local community connections
- **Technical Feasibility**: Medium - You already have location/nearby infrastructure

#### 2. **"Trending" Section**
- **Concept**: Aggregated trending posts, hashtags, and topics based on real-time engagement metrics
- **Engagement Impact**: High - Drives discovery and viral content
- **Justification**: Increases time on app, surfaces best content
- **Technical Feasibility**: Medium - Requires aggregation queries and ranking logic

#### 3. **Advanced Comment Threading**
- **Concept**: Nested comments (reply to comments), comment reactions, pinned comments
- **Engagement Impact**: High - Increases discussion depth and engagement
- **Justification**: Critical for community building and content discussions
- **Technical Feasibility**: Medium - Firestore subcollections for nested structure

#### 4. **Content-Based Recommendation Engine**
- **Concept**: ML-powered recommendations based on post content, user interests, engagement patterns
- **Engagement Impact**: Very High - Personalization drives retention
- **Justification**: Keeps users engaged with relevant content
- **Technical Feasibility**: High (simple) to Medium (advanced ML) - Start with rule-based, evolve to ML

#### 5. **Live Reactions & Read Receipts**
- **Concept**: Real-time reaction counts, "X people are viewing this post", read receipts for stories
- **Engagement Impact**: Medium-High - Creates FOMO and social proof
- **Justification**: Increases engagement through real-time feedback
- **Technical Feasibility**: Medium - Requires Firebase Realtime Database or Firestore listeners

---

## Phase 2: Feature Analysis & Prioritization

### Feature Prioritization Table

| Feature | Engagement Impact | Dev. Complexity | Justification & Recommendation |
|:---|:---|:---|:---|
| **Core Feed** | High | Medium | **Build Now.** Foundation of the entire ecosystem. Without this, nothing else matters. Requires infinite scroll, pagination, real-time updates. |
| **Reactions** | High | Low-Medium | **Build Now.** Essential for engagement. Simple implementation (firestore map/array field), optimistic UI updates. Critical user expectation. |
| **Comments** | High | Medium | **Build Now.** Drives discussion and community. Requires subcollection structure, pagination, real-time updates. Start with flat comments, add threading in V2. |
| **Stories** | High | High | **Defer to V2.** Complex (24-hour expiry, media upload, viewer tracking). High engagement but requires significant infrastructure. Build core feed first. |
| **Reels** | Very High | Very High | **Defer to V3.** Most complex feature (video processing, compression, editing, autoplay). Highest engagement potential but requires video infrastructure. |
| **Pages** | Medium | Medium | **Defer to V2.** Important for brands/communities but not core to MVP. Requires separate user type, permissions, verification system. |
| **Nearby Feed** | High | Medium | **Build Now.** Unique differentiator, leverages existing Bluetooth/location tech. High engagement potential for local discovery. |
| **Trending Section** | High | Medium | **Build Now (Simplified).** Start with simple engagement metrics (likes, comments per time window). Add ML ranking later. |
| **Advanced Comment Threading** | Medium | Medium | **Defer to V2.** Start with flat comments in Phase 1, add threading/nesting in V2. Reduces initial complexity. |
| **Content-Based Recommendations** | Very High | High | **Defer to V2.** Start with simple "For You" feed based on followed users + trending. Add ML recommendations in V2. |
| **Live Reactions & Read Receipts** | Medium | Medium | **Defer to V2.** Nice-to-have feature. Can add after core feed is stable. Requires real-time infrastructure. |

### Build Priority Summary

**Phase 1 (MVP - Build Now):**
1. Core Feed (infinite scroll)
2. Reactions
3. Comments (flat, no threading)
4. Nearby Feed
5. Trending Section (simplified)

**Phase 2 (Next Iteration):**
- Stories (ephemeral content)
- Pages (brand/community profiles)
- Advanced Comment Threading
- Content-Based Recommendations (ML-powered)

**Phase 3 (Future):**
- Reels (short-form video)
- Live Reactions & Read Receipts (enhanced real-time features)

---

## Phase 3: Detailed Implementation Blueprint

---

### Feature 1: Core Feed (Infinite Scroll)

#### 1. Database Schema (Firestore)

**Collection: `posts`**
```javascript
{
  postId: string (auto-generated),
  authorId: string, // User ID
  authorUsername: string, // Denormalized for fast queries
  authorPhotoUrl: string, // Denormalized
  content: string, // Post text content
  mediaUrls: string[], // Array of image/video URLs (Cloudinary)
  mediaTypes: string[], // ['image', 'video', 'image'] - matches mediaUrls index
  postType: string, // 'text' | 'image' | 'video' | 'mixed'
  timestamp: Timestamp, // Server timestamp
  location: {
    latitude: number,
    longitude: number,
    address: string // Optional human-readable
  }, // Optional - for nearby feed
  hashtags: string[], // Extracted from content (e.g., ['#flutter', '#firebase'])
  mentions: string[], // User IDs mentioned (@username)
  visibility: string, // 'public' | 'friends' | 'nearby'
  
  // Engagement metrics (denormalized for fast queries)
  reactionCount: number, // Total reactions
  commentCount: number, // Total comments
  viewCount: number, // Total views (if tracking)
  
  // Cached data for trending algorithm
  trendingScore: number, // Calculated score for trending
  lastEngagementTimestamp: Timestamp, // Last time someone engaged
  
  // Soft delete
  deleted: boolean,
  deletedAt: Timestamp | null,
  
  // Timestamps
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

**Subcollection: `posts/{postId}/reactions`**
```javascript
{
  userId: string, // Document ID is the userId (simple presence check)
  timestamp: Timestamp // When user liked the post
}
// Note: Document existence = liked, deletion = unliked (no reactionType needed)
```

**Subcollection: `posts/{postId}/comments`**
```javascript
{
  commentId: string (auto-generated),
  userId: string,
  username: string, // Denormalized
  photoUrl: string, // Denormalized
  text: string,
  timestamp: Timestamp,
  edited: boolean,
  editedAt: Timestamp | null,
  reactions: Map<string, string>, // userId -> reactionType
  deleted: boolean
}
```

**Firestore Indexes Required:**
```json
{
  "indexes": [
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "visibility", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" },
        { "fieldPath": "deleted", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "authorId", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" },
        { "fieldPath": "deleted", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "hashtags", "arrayConfig": "CONTAINS" },
        { "fieldPath": "timestamp", "order": "DESCENDING" },
        { "fieldPath": "deleted", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "trendingScore", "order": "DESCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" },
        { "fieldPath": "deleted", "order": "ASCENDING" }
      ]
    }
  ]
}
```

#### 2. API / Backend Logic

**Cloud Functions (functions/index.js):**

```javascript
// Calculate trending score when post is created/updated
exports.onPostCreated = onDocumentCreated(
  'posts/{postId}',
  async (event) => {
    const post = event.data.data();
    // Initial trending score based on timestamp (newer = higher)
    const ageInHours = (Date.now() - post.timestamp.toMillis()) / (1000 * 60 * 60);
    const initialScore = Math.max(0, 100 - ageInHours);
    
    await admin.firestore()
      .collection('posts')
      .doc(event.params.postId)
      .update({
        trendingScore: initialScore,
        lastEngagementTimestamp: post.timestamp
      });
  }
);

// Update trending score on engagement
exports.onPostEngagement = onDocumentWritten(
  ['posts/{postId}/reactions/{reactionId}', 'posts/{postId}/comments/{commentId}'],
  async (event) => {
    const postRef = admin.firestore().collection('posts').doc(event.params.postId);
    const postDoc = await postRef.get();
    
    if (!postDoc.exists) return;
    
    // Get current engagement metrics
    const reactionsSnapshot = await postRef.collection('reactions').get();
    const commentsSnapshot = await postRef.collection('comments').where('deleted', '==', false).get();
    
    const reactionCount = reactionsSnapshot.size;
    const commentCount = commentsSnapshot.size;
    
    // Calculate trending score
    // Formula: (reactions * 1) + (comments * 2) + (recency bonus)
    const ageInHours = (Date.now() - postDoc.data().timestamp.toMillis()) / (1000 * 60 * 60);
    const recencyBonus = Math.max(0, 50 - ageInHours * 2);
    const trendingScore = (reactionCount * 1) + (commentCount * 2) + recencyBonus;
    
    await postRef.update({
      reactionCount,
      commentCount,
      trendingScore,
      lastEngagementTimestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  }
);
```

**Repository Methods (lib/repositories/post_repository.dart):**

```dart
// Get feed for current user (following + public posts)
Future<List<PostModel>> getFeedForUser({
  required String userId,
  DocumentSnapshot? lastDocument,
  int limit = 10,
}) async {
  // Get user's friends list
  final userDoc = await _db.collection('users').doc(userId).get();
  final userData = userDoc.data()!;
  final friends = List<String>.from(userData['friends'] ?? []);
  
  // Query: Posts from friends OR public posts, ordered by timestamp
  final query = _db
      .collection('posts')
      .where('deleted', isEqualTo: false)
      .where(
        Filter.or([
          Filter('authorId', whereIn: friends.length > 0 ? friends : ['__no_friends__']),
          Filter('visibility', isEqualTo: 'public'),
        ]),
      )
      .orderBy('timestamp', descending: true)
      .limit(limit);
  
  // Pagination
  if (lastDocument != null) {
    query = query.startAfterDocument(lastDocument);
  }
  
  final snapshot = await query.get();
  return snapshot.docs.map((doc) => PostModel.fromDoc(doc)).toList();
}

// Get trending posts
Future<List<PostModel>> getTrendingPosts({
  DocumentSnapshot? lastDocument,
  int limit = 10,
}) async {
  var query = _db
      .collection('posts')
      .where('deleted', isEqualTo: false)
      .where('visibility', isEqualTo: 'public')
      .orderBy('trendingScore', descending: true)
      .orderBy('timestamp', descending: true)
      .limit(limit);
  
  if (lastDocument != null) {
    query = query.startAfterDocument(lastDocument);
  }
  
  final snapshot = await query.get();
  return snapshot.docs.map((doc) => PostModel.fromDoc(doc)).toList();
}

// Create post
Future<String> createPost({
  required String userId,
  required String content,
  List<String>? mediaUrls,
  List<String>? mediaTypes,
  GeoPoint? location,
  String visibility = 'public',
}) async {
  // Extract hashtags from content
  final hashtags = _extractHashtags(content);
  // Extract mentions from content
  final mentions = _extractMentions(content);
  
  final postRef = _db.collection('posts').doc();
  
  await postRef.set({
    'postId': postRef.id,
    'authorId': userId,
    'authorUsername': await _getUsername(userId), // Fetch from users collection
    'authorPhotoUrl': await _getPhotoUrl(userId),
    'content': content,
    'mediaUrls': mediaUrls ?? [],
    'mediaTypes': mediaTypes ?? [],
    'postType': _determinePostType(mediaTypes),
    'timestamp': FieldValue.serverTimestamp(),
    'location': location != null ? {
      'latitude': location.latitude,
      'longitude': location.longitude,
    } : null,
    'hashtags': hashtags,
    'mentions': mentions,
    'visibility': visibility,
    'reactionCount': 0,
    'commentCount': 0,
    'viewCount': 0,
    'trendingScore': 0,
    'lastEngagementTimestamp': FieldValue.serverTimestamp(),
    'deleted': false,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  
  return postRef.id;
}
```

#### 3. Frontend (UI/UX)

**BLoC Structure (lib/blocs/feed_bloc.dart):**

```dart
// Events
abstract class FeedEvent extends Equatable {}
class LoadFeedEvent extends FeedEvent {
  final bool refresh;
  LoadFeedEvent({this.refresh = false});
}
class LoadMoreFeedEvent extends FeedEvent {}

// States
abstract class FeedState extends Equatable {}
class FeedInitial extends FeedState {}
class FeedLoading extends FeedState {}
class FeedLoaded extends FeedState {
  final List<PostModel> posts;
  final bool hasMore;
  final bool isLoadingMore;
  FeedLoaded({
    required this.posts,
    this.hasMore = true,
    this.isLoadingMore = false,
  });
}
class FeedError extends FeedState {
  final String message;
  FeedError(this.message);
}

// BLoC
class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final PostRepository _postRepository;
  final String _userId;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  
  FeedBloc({
    required PostRepository postRepository,
    required String userId,
  }) : _postRepository = postRepository, _userId = userId, super(FeedInitial()) {
    on<LoadFeedEvent>(_onLoadFeed);
    on<LoadMoreFeedEvent>(_onLoadMoreFeed);
  }
  
  Future<void> _onLoadFeed(LoadFeedEvent event, Emitter<FeedState> emit) async {
    if (event.refresh) {
      _lastDocument = null;
      _hasMore = true;
    }
    
    emit(FeedLoading());
    
    try {
      final posts = await _postRepository.getFeedForUser(
        userId: _userId,
        lastDocument: _lastDocument,
      );
      
      _hasMore = posts.length == 10; // Assuming limit is 10
      if (posts.isNotEmpty) {
        _lastDocument = await _getLastDocument(posts.last.id);
      }
      
      emit(FeedLoaded(posts: posts, hasMore: _hasMore));
    } catch (e) {
      emit(FeedError(e.toString()));
    }
  }
  
  Future<void> _onLoadMoreFeed(LoadMoreFeedEvent event, Emitter<FeedState> emit) async {
    if (state is FeedLoaded) {
      final currentState = state as FeedLoaded;
      if (!currentState.hasMore || currentState.isLoadingMore) return;
      
      emit(currentState.copyWith(isLoadingMore: true));
      
      try {
        final morePosts = await _postRepository.getFeedForUser(
          userId: _userId,
          lastDocument: _lastDocument,
        );
        
        _hasMore = morePosts.length == 10;
        if (morePosts.isNotEmpty) {
          _lastDocument = await _getLastDocument(morePosts.last.id);
        }
        
        final updatedPosts = [...currentState.posts, ...morePosts];
        emit(FeedLoaded(
          posts: updatedPosts,
          hasMore: _hasMore,
          isLoadingMore: false,
        ));
      } catch (e) {
        emit(FeedError(e.toString()));
      }
    }
  }
}
```

**UI Widgets (lib/screens/feed_screen.dart):**

```dart
class FeedScreen extends StatefulWidget {
  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    // Load initial feed
    context.read<FeedBloc>().add(LoadFeedEvent(refresh: true));
    
    // Infinite scroll detection
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent * 0.8) {
        context.read<FeedBloc>().add(LoadMoreFeedEvent());
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Feed'),
        actions: [
          IconButton(
            icon: Icon(Icons.create),
            onPressed: () => _showCreatePostModal(context),
          ),
        ],
      ),
      body: BlocBuilder<FeedBloc, FeedState>(
        builder: (context, state) {
          if (state is FeedLoading) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (state is FeedError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${state.message}'),
                  ElevatedButton(
                    onPressed: () => context.read<FeedBloc>().add(LoadFeedEvent(refresh: true)),
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          if (state is FeedLoaded) {
            if (state.posts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.feed, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No posts yet'),
                    TextButton(
                      onPressed: () => _showCreatePostModal(context),
                      child: Text('Create your first post!'),
                    ),
                  ],
                ),
              );
            }
            
            return RefreshIndicator(
              onRefresh: () async {
                context.read<FeedBloc>().add(LoadFeedEvent(refresh: true));
              },
              child: ListView.builder(
                controller: _scrollController,
                itemCount: state.posts.length + (state.isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.posts.length) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  
                  return PostCard(post: state.posts[index]);
                },
              ),
            );
          }
          
          return SizedBox.shrink();
        },
      ),
    );
  }
}
```

**Post Card Widget (lib/widgets/feed_widgets/post_card.dart):**

```dart
class PostCard extends StatelessWidget {
  final PostModel post;
  
  const PostCard({required this.post});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Author info)
          ListTile(
            leading: CircleAvatar(
              backgroundImage: post.authorPhotoUrl.isNotEmpty
                  ? NetworkImage(post.authorPhotoUrl)
                  : null,
            ),
            title: Text(post.authorUsername),
            subtitle: Text(timeago.format(post.timestamp.toDate())),
            trailing: IconButton(
              icon: Icon(Icons.more_vert),
              onPressed: () => _showPostOptions(context),
            ),
          ),
          
          // Content
          if (post.content.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(post.content),
            ),
          
          // Media
          if (post.mediaUrls.isNotEmpty)
            _buildMediaGrid(post.mediaUrls, post.mediaTypes),
          
          // Hashtags
          if (post.hashtags.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: post.hashtags.map((tag) => 
                  GestureDetector(
                    onTap: () => _navigateToHashtag(tag),
                    child: Text(
                      tag,
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ).toList(),
              ),
            ),
          
          // Actions (Like, Comment, Share)
          Row(
            children: [
              _ReactionButton(post: post),
              IconButton(
                icon: Icon(Icons.comment_outlined),
                onPressed: () => _showCommentsSheet(context, post),
              ),
              IconButton(
                icon: Icon(Icons.share_outlined),
                onPressed: () => _sharePost(post),
              ),
            ],
          ),
          
          // Engagement counts
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${post.reactionCount} likes • ${post.commentCount} comments',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 4. State Management

**Optimistic Updates:**

```dart
// In ReactionButton widget
void _handleReaction(PostModel post) async {
  final currentUserId = context.read<AuthBloc>().state.user.id;
  
  // Optimistic update
  final currentReactions = post.reactions;
  final hasReacted = currentReactions.containsKey(currentUserId);
  
  // Update UI immediately
  setState(() {
    if (hasReacted) {
      post.reactions.remove(currentUserId);
      post.reactionCount--;
    } else {
      post.reactions[currentUserId] = 'like';
      post.reactionCount++;
    }
  });
  
  try {
    if (hasReacted) {
      await _postRepository.removeReaction(post.id, currentUserId);
    } else {
      await _postRepository.addReaction(post.id, currentUserId, 'like');
    }
  } catch (e) {
    // Rollback on error
    setState(() {
      if (hasReacted) {
        post.reactions[currentUserId] = 'like';
        post.reactionCount++;
      } else {
        post.reactions.remove(currentUserId);
        post.reactionCount--;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to update reaction')),
    );
  }
}
```

**Real-time Updates (Stream):**

```dart
// In PostRepository
Stream<List<PostModel>> getFeedStream(String userId) {
  // Get friends list once
  return _db.collection('users').doc(userId).snapshots().switchMap((userDoc) {
    final friends = List<String>.from(userDoc.data()!['friends'] ?? []);
    
    return _db
        .collection('posts')
        .where('deleted', isEqualTo: false)
        .where(
          Filter.or([
            Filter('authorId', whereIn: friends.length > 0 ? friends : ['__no_friends__']),
            Filter('visibility', isEqualTo: 'public'),
          ]),
        )
        .orderBy('timestamp', descending: true)
        .limit(50) // Real-time limited to 50 for performance
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromDoc(doc))
            .toList());
  });
}
```

---

### Feature 2: Reactions

#### 1. Database Schema

**Subcollection: `posts/{postId}/reactions`**
```javascript
{
  userId: string, // Document ID is the userId (simple presence check)
  timestamp: Timestamp // When user liked the post
}
// Note: Document existence = liked, deletion = unliked (simple boolean-like behavior)
```

**Denormalized in Post Document:**
```javascript
{
  reactionCount: number, // Total likes count
  // Note: Check if user liked by checking if reaction document exists
}
```

#### 2. API / Backend Logic

**Repository Methods (lib/repositories/post_repository.dart):**

```dart
// Like post (add reaction)
Future<void> likePost(String postId, String userId) async {
  final batch = _db.batch();
  
  // Add like document (using userId as document ID for easy lookup)
  final reactionRef = _db
      .collection('posts')
      .doc(postId)
      .collection('reactions')
      .doc(userId);
  
  batch.set(reactionRef, {
    'userId': userId,
    'timestamp': FieldValue.serverTimestamp(),
  });
  
  // Update post reaction count (atomic increment)
  final postRef = _db.collection('posts').doc(postId);
  batch.update(postRef, {
    'reactionCount': FieldValue.increment(1),
    'lastEngagementTimestamp': FieldValue.serverTimestamp(),
  });
  
  await batch.commit();
}

// Unlike post (remove reaction)
Future<void> unlikePost(String postId, String userId) async {
  final batch = _db.batch();
  
  // Delete like document
  final reactionRef = _db
      .collection('posts')
      .doc(postId)
      .collection('reactions')
      .doc(userId);
  
  batch.delete(reactionRef);
  
  // Decrement count
  final postRef = _db.collection('posts').doc(postId);
  batch.update(postRef, {
    'reactionCount': FieldValue.increment(-1),
  });
  
  await batch.commit();
}

// Check if user has liked the post
Future<bool> hasUserLiked(String postId, String userId) async {
  final doc = await _db
      .collection('posts')
      .doc(postId)
      .collection('reactions')
      .doc(userId)
      .get();
  
  return doc.exists;
}

// Get users who liked the post (with pagination) - optional for showing "liked by" list
Future<List<String>> getLikedByUsers(String postId, {
  DocumentSnapshot? lastDocument,
  int limit = 20,
}) async {
  var query = _db
      .collection('posts')
      .doc(postId)
      .collection('reactions')
      .orderBy('timestamp', descending: true)
      .limit(limit);
  
  if (lastDocument != null) {
    query = query.startAfterDocument(lastDocument);
  }
  
  final snapshot = await query.get();
  return snapshot.docs.map((doc) => doc.id).toList(); // doc.id is the userId
}
```

#### 3. Frontend (UI/UX)

**Like Button Widget (lib/widgets/feed_widgets/like_button.dart):**

```dart
class LikeButton extends StatefulWidget {
  final PostModel post;
  
  const LikeButton({required this.post});
  
  @override
  _LikeButtonState createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool _isLiked = false;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }
  
  Future<void> _checkIfLiked() async {
    final userId = context.read<AuthBloc>().state.user.id;
    final liked = await locator<PostRepository>().hasUserLiked(
      widget.post.id,
      userId,
    );
    setState(() => _isLiked = liked);
  }
  
  Future<void> _toggleLike() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    final userId = context.read<AuthBloc>().state.user.id;
    final wasLiked = _isLiked;
    
    // Optimistic update
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        widget.post.reactionCount++;
      } else {
        widget.post.reactionCount--;
      }
    });
    
    try {
      if (wasLiked) {
        await locator<PostRepository>().unlikePost(
          widget.post.id,
          userId,
        );
      } else {
        await locator<PostRepository>().likePost(
          widget.post.id,
          userId,
        );
      }
    } catch (e) {
      // Rollback on error
      setState(() {
        _isLiked = wasLiked;
        if (wasLiked) {
          widget.post.reactionCount++;
        } else {
          widget.post.reactionCount--;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleLike,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: _isLiked ? Colors.red : Colors.grey,
              size: 24,
            ),
            SizedBox(width: 4),
            Text(
              widget.post.reactionCount.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isLiked ? Colors.red : Colors.grey,
              ),
            ),
            if (_isLoading)
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

#### 4. State Management

**Note:** For simple like/unlike functionality, no separate BLoC is needed. The `LikeButton` widget manages its own state with `setState()`. The optimistic updates are handled directly in the widget.

If you need to track likes across multiple posts in a BLoC for performance reasons (batching API calls), you could create a `LikeBloc`, but it's optional:

```dart
// Optional: Like BLoC (only if needed for advanced features)
class LikeBloc extends Bloc<LikeEvent, LikeState> {
  final PostRepository _postRepository;
  
  LikeBloc({required PostRepository postRepository})
      : _postRepository = postRepository,
        super(LikeInitial()) {
    on<LikePostEvent>(_onLikePost);
    on<UnlikePostEvent>(_onUnlikePost);
  }
  
  // Implement with optimistic updates if needed
}
```

**Recommendation:** Start without a BLoC. Add one later only if you need centralized like state management.

---

### Feature 3: Comments

#### 1. Database Schema

**Subcollection: `posts/{postId}/comments`**
```javascript
{
  commentId: string (auto-generated),
  userId: string,
  username: string, // Denormalized
  photoUrl: string, // Denormalized
  text: string,
  timestamp: Timestamp,
  edited: boolean,
  editedAt: Timestamp | null,
  likes: List<string>, // Array of userIds who liked this comment (or use subcollection like posts)
  deleted: boolean,
  deletedAt: Timestamp | null
}
```

**Denormalized in Post Document:**
```javascript
{
  commentCount: number // Total non-deleted comments
}
```

#### 2. API / Backend Logic

**Repository Methods (lib/repositories/post_repository.dart):**

```dart
// Add comment
Future<String> addComment(
  String postId,
  String userId,
  String text,
) async {
  final batch = _db.batch();
  
  // Get user info for denormalization
  final userDoc = await _db.collection('users').doc(userId).get();
  final userData = userDoc.data()!;
  
  // Create comment
  final commentRef = _db
      .collection('posts')
      .doc(postId)
      .collection('comments')
      .doc();
  
  batch.set(commentRef, {
    'commentId': commentRef.id,
    'userId': userId,
    'username': userData['username'],
    'photoUrl': userData['photoUrl'] ?? '',
    'text': text,
    'timestamp': FieldValue.serverTimestamp(),
    'edited': false,
    'reactions': {},
    'deleted': false,
  });
  
  // Update post comment count
  final postRef = _db.collection('posts').doc(postId);
  batch.update(postRef, {
    'commentCount': FieldValue.increment(1),
    'lastEngagementTimestamp': FieldValue.serverTimestamp(),
  });
  
  await batch.commit();
  return commentRef.id;
}

// Get comments with pagination
Future<List<CommentModel>> getComments(String postId, {
  DocumentSnapshot? lastDocument,
  int limit = 20,
}) async {
  var query = _db
      .collection('posts')
      .doc(postId)
      .collection('comments')
      .where('deleted', isEqualTo: false)
      .orderBy('timestamp', descending: false) // Oldest first for comments
      .limit(limit);
  
  if (lastDocument != null) {
    query = query.startAfterDocument(lastDocument);
  }
  
  final snapshot = await query.get();
  return snapshot.docs.map((doc) => CommentModel.fromDoc(doc)).toList();
}

// Edit comment
Future<void> editComment(
  String postId,
  String commentId,
  String newText,
) async {
  await _db
      .collection('posts')
      .doc(postId)
      .collection('comments')
      .doc(commentId)
      .update({
    'text': newText,
    'edited': true,
    'editedAt': FieldValue.serverTimestamp(),
  });
}

// Delete comment (soft delete)
Future<void> deleteComment(String postId, String commentId) async {
  final batch = _db.batch();
  
  // Soft delete comment
  final commentRef = _db
      .collection('posts')
      .doc(postId)
      .collection('comments')
      .doc(commentId);
  
  batch.update(commentRef, {
    'deleted': true,
    'deletedAt': FieldValue.serverTimestamp(),
  });
  
  // Decrement count
  final postRef = _db.collection('posts').doc(postId);
  batch.update(postRef, {
    'commentCount': FieldValue.increment(-1),
  });
  
  await batch.commit();
}

// Like comment (optional feature)
Future<void> likeComment(
  String postId,
  String commentId,
  String userId,
) async {
  await _db
      .collection('posts')
      .doc(postId)
      .collection('comments')
      .doc(commentId)
      .update({
    'likes': FieldValue.arrayUnion([userId]),
  });
}

// Unlike comment
Future<void> unlikeComment(
  String postId,
  String commentId,
  String userId,
) async {
  await _db
      .collection('posts')
      .doc(postId)
      .collection('comments')
      .doc(commentId)
      .update({
    'likes': FieldValue.arrayRemove([userId]),
  });
}
```

#### 3. Frontend (UI/UX)

**Comments Sheet (lib/widgets/feed_widgets/comments_sheet.dart):**

```dart
class CommentsSheet extends StatefulWidget {
  final PostModel post;
  
  const CommentsSheet({required this.post});
  
  @override
  _CommentsSheetState createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<CommentModel> _comments = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  
  @override
  void initState() {
    super.initState();
    _loadComments();
  }
  
  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    
    try {
      final comments = await locator<PostRepository>().getComments(
        widget.post.id,
        lastDocument: _lastDocument,
      );
      
      setState(() {
        _comments.addAll(comments);
        _hasMore = comments.length == 20;
        if (comments.isNotEmpty) {
          _lastDocument = await _getLastDocument(comments.last.id);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load comments')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    final userId = context.read<AuthBloc>().state.user.id;
    final text = _commentController.text.trim();
    
    // Optimistic update
    final tempComment = CommentModel(
      commentId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      username: context.read<AuthBloc>().state.user.username,
      photoUrl: context.read<AuthBloc>().state.user.photoUrl,
      text: text,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _comments.insert(0, tempComment); // Add to top (will be reordered on reload)
      widget.post.commentCount++;
    });
    
    _commentController.clear();
    
    try {
      final commentId = await locator<PostRepository>().addComment(
        widget.post.id,
        userId,
        text,
      );
      
      // Replace temp comment with real one
      setState(() {
        final index = _comments.indexWhere((c) => c.commentId == tempComment.commentId);
        if (index != -1) {
          _comments[index] = tempComment.copyWith(commentId: commentId);
        }
      });
      
      // Scroll to top to show new comment
      _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      // Rollback
      setState(() {
        _comments.removeWhere((c) => c.commentId == tempComment.commentId);
        widget.post.commentCount--;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post comment')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comments (${widget.post.commentCount})',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          Divider(),
          
          // Comments list
          Expanded(
            child: _isLoading && _comments.isEmpty
                ? Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child: Text('No comments yet. Be the first!'),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _comments.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _comments.length) {
                            _loadComments(); // Load more
                            return Center(child: CircularProgressIndicator());
                          }
                          
                          return CommentTile(
                            comment: _comments[index],
                            postId: widget.post.id,
                            onDelete: () {
                              setState(() {
                                _comments.removeAt(index);
                                widget.post.commentCount--;
                              });
                            },
                          );
                        },
                      ),
          ),
          
          // Input field
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _addComment,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 4. State Management

**Comments BLoC (optional):**

```dart
class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  final PostRepository _postRepository;
  final String postId;
  
  CommentsBloc({
    required PostRepository postRepository,
    required this.postId,
  }) : _postRepository = postRepository, super(CommentsInitial()) {
    on<LoadCommentsEvent>(_onLoadComments);
    on<AddCommentEvent>(_onAddComment);
    on<DeleteCommentEvent>(_onDeleteComment);
  }
  
  // Implement with optimistic updates
}
```

---

### Feature 4: Nearby Feed

#### 1. Database Schema

**Use existing location field in `posts` collection:**
```javascript
{
  location: {
    latitude: number,
    longitude: number,
    address: string // Optional
  },
  visibility: 'nearby' | 'public' | 'friends'
}
```

**New Firestore Index:**
```json
{
  "collectionGroup": "posts",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "visibility", "order": "ASCENDING" },
    { "fieldPath": "location.latitude", "order": "ASCENDING" },
    { "fieldPath": "location.longitude", "order": "ASCENDING" },
    { "fieldPath": "timestamp", "order": "DESCENDING" }
  ]
}
```

#### 2. API / Backend Logic

**Repository Method (lib/repositories/post_repository.dart):**

```dart
// Get nearby posts (within radius)
Future<List<PostModel>> getNearbyPosts({
  required double latitude,
  required double longitude,
  double radiusKm = 10.0, // 10km radius
  DocumentSnapshot? lastDocument,
  int limit = 20,
}) async {
  // Calculate bounding box for GeoHash query (simplified)
  // For production, use GeoFirestore or similar geospatial library
  // This is a simplified approach using latitude/longitude bounds
  
  final latDelta = radiusKm / 111.0; // ~111km per degree latitude
  final lonDelta = radiusKm / (111.0 * cos(latitude * pi / 180));
  
  final minLat = latitude - latDelta;
  final maxLat = latitude + latDelta;
  final minLon = longitude - lonDelta;
  final maxLon = longitude + lonDelta;
  
  var query = _db
      .collection('posts')
      .where('deleted', isEqualTo: false)
      .where('visibility', whereIn: ['nearby', 'public'])
      .where('location.latitude', isGreaterThanOrEqualTo: minLat)
      .where('location.latitude', isLessThanOrEqualTo: maxLat)
      .where('location.longitude', isGreaterThanOrEqualTo: minLon)
      .where('location.longitude', isLessThanOrEqualTo: maxLon)
      .orderBy('location.latitude')
      .orderBy('location.longitude')
      .orderBy('timestamp', descending: true)
      .limit(limit);
  
  if (lastDocument != null) {
    query = query.startAfterDocument(lastDocument);
  }
  
  final snapshot = await query.get();
  
  // Filter by actual distance (Firestore can't do circular radius queries)
  final posts = snapshot.docs
      .map((doc) => PostModel.fromDoc(doc))
      .where((post) {
        if (post.location == null) return false;
        final distance = _calculateDistance(
          latitude,
          longitude,
          post.location!.latitude,
          post.location!.longitude,
        );
        return distance <= radiusKm;
      })
      .toList();
  
  return posts;
}

double _calculateDistance(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  // Haversine formula
  const R = 6371.0; // Earth radius in km
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _toRadians(double degrees) => degrees * pi / 180;
```

**Note:** For production, consider using `geoflutterfire` or `geohash` for efficient geospatial queries.

#### 3. Frontend (UI/UX)

**Nearby Feed Tab (lib/screens/nearby_feed_tab.dart):**

```dart
class NearbyFeedTab extends StatefulWidget {
  @override
  _NearbyFeedTabState createState() => _NearbyFeedTabState();
}

class _NearbyFeedTabState extends State<NearbyFeedTab> {
  final FeedBloc _feedBloc = FeedBloc(
    postRepository: locator<PostRepository>(),
    userId: context.read<AuthBloc>().state.user.id,
    feedType: FeedType.nearby, // New enum value
  );
  
  Location? _currentLocation;
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      final location = await getCurrentPosition();
      setState(() => _currentLocation = location);
      
      if (location != null) {
        _feedBloc.add(LoadFeedEvent(refresh: true));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permission required')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_currentLocation == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Getting your location...'),
          ],
        ),
      );
    }
    
    return BlocBuilder<FeedBloc, FeedState>(
      bloc: _feedBloc,
      builder: (context, state) {
        // Similar to main FeedScreen but uses nearby feed
        // ...
      },
    );
  }
}
```

#### 4. State Management

**Extend FeedBloc to support different feed types:**

```dart
enum FeedType { following, trending, nearby }

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final PostRepository _postRepository;
  final String _userId;
  final FeedType _feedType;
  Location? _userLocation; // For nearby feed
  
  FeedBloc({
    required PostRepository postRepository,
    required String userId,
    this.feedType = FeedType.following,
    Location? userLocation,
  }) : _postRepository = postRepository,
       _userId = userId,
       _feedType = feedType,
       _userLocation = userLocation,
       super(FeedInitial()) {
    // ...
  }
  
  Future<void> _onLoadFeed(LoadFeedEvent event, Emitter<FeedState> emit) async {
    emit(FeedLoading());
    
    try {
      List<PostModel> posts;
      
      switch (_feedType) {
        case FeedType.following:
          posts = await _postRepository.getFeedForUser(
            userId: _userId,
            lastDocument: _lastDocument,
          );
          break;
        case FeedType.trending:
          posts = await _postRepository.getTrendingPosts(
            lastDocument: _lastDocument,
          );
          break;
        case FeedType.nearby:
          if (_userLocation != null) {
            posts = await _postRepository.getNearbyPosts(
              latitude: _userLocation!.latitude,
              longitude: _userLocation!.longitude,
              lastDocument: _lastDocument,
            );
          } else {
            posts = [];
          }
          break;
      }
      
      // ... rest of logic
    } catch (e) {
      emit(FeedError(e.toString()));
    }
  }
}
```

---

### Feature 5: Trending Section

#### 1. Database Schema

**Use existing `trendingScore` field in `posts` collection:**

The `trendingScore` is already calculated by Cloud Functions (see Feature 1, Section 2).

**Algorithm:**
- `trendingScore = (reactions * 1) + (comments * 2) + recencyBonus`
- `recencyBonus = max(0, 50 - ageInHours * 2)`
- Updated on every engagement

#### 2. API / Backend Logic

**Repository Method (already covered in Feature 1):**

```dart
// Already implemented in getTrendingPosts()
Future<List<PostModel>> getTrendingPosts({...}) async {
  // Query sorted by trendingScore descending
}
```

#### 3. Frontend (UI/UX)

**Trending Tab (lib/screens/trending_feed_tab.dart):**

Similar to main feed but uses `FeedType.trending`. Can add:
- Time filters (Today, This Week, All Time)
- Category filters (if you add categories)
- Trending hashtags sidebar

#### 4. State Management

**Extend FeedBloc with trending support (already covered in Feature 4).**

---

## Additional Implementation Notes

### Models to Create

**lib/models/post_model.dart:**
```dart
class PostModel extends Equatable {
  final String id;
  final String authorId;
  final String authorUsername;
  final String authorPhotoUrl;
  final String content;
  final List<String> mediaUrls;
  final List<String> mediaTypes;
  final PostType postType;
  final DateTime timestamp;
  final GeoPoint? location;
  final List<String> hashtags;
  final List<String> mentions;
  final String visibility;
  final int reactionCount;
  final int commentCount;
  final int viewCount;
  final double trendingScore;
  final DateTime lastEngagementTimestamp;
  final bool deleted;
  
  // ... fromDoc, toMap, etc.
}
```

**lib/models/comment_model.dart:**
```dart
class CommentModel extends Equatable {
  final String commentId;
  final String postId;
  final String userId;
  final String username;
  final String photoUrl;
  final String text;
  final DateTime timestamp;
  final bool edited;
  final DateTime? editedAt;
  final Map<String, String> reactions;
  final bool deleted;
  
  // ... fromDoc, toMap, etc.
}
```

**lib/models/reaction_model.dart:**
```dart
class ReactionModel extends Equatable {
  final String userId;
  final String reactionType;
  final DateTime timestamp;
  
  // ... fromDoc, toMap, etc.
}
```

### Security Rules (Firestore)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Posts collection
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null 
        && request.resource.data.authorId == request.auth.uid;
      allow update: if request.auth != null 
        && (resource.data.authorId == request.auth.uid
        || request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['reactionCount', 'commentCount', 'trendingScore']));
      allow delete: if request.auth != null 
        && resource.data.authorId == request.auth.uid;
      
      // Reactions subcollection
      match /reactions/{reactionId} {
        allow read: if request.auth != null;
        allow create: if request.auth != null 
          && request.resource.data.userId == request.auth.uid;
        allow delete: if request.auth != null 
          && resource.data.userId == request.auth.uid;
      }
      
      // Comments subcollection
      match /comments/{commentId} {
        allow read: if request.auth != null;
        allow create: if request.auth != null 
          && request.resource.data.userId == request.auth.uid;
        allow update: if request.auth != null 
          && resource.data.userId == request.auth.uid;
        allow delete: if request.auth != null 
          && resource.data.userId == request.auth.uid;
      }
    }
  }
}
```

### Dependencies to Add (pubspec.yaml)

```yaml
dependencies:
  # ... existing dependencies ...
  
  # For geolocation
  geolocator: ^10.1.0
  
  # For geospatial queries (optional, for better performance)
  # geoflutterfire: ^3.0.0
  
  # For hashtag/mention parsing
  # Already have regex support in Dart
  
  # For image/video handling (already have image_picker)
  # Add video_player back if implementing reels:
  # video_player: ^2.8.6
```

### Integration with Existing Features

1. **Bluetooth Nearby Discovery**: Link nearby feed posts to discovered users
2. **Friends System**: Show friends' posts in following feed
3. **Profile Screen**: Show user's posts on their profile
4. **Notifications**: Notify on comments, reactions, mentions
5. **Cloudinary**: Use existing service for media uploads

---

## Comprehensive Implementation To-Do List

### 📋 Phase 0: Project Setup & Foundation

#### 0.1 Dependencies & Configuration
- [ ] Add `geolocator: ^10.1.0` to `pubspec.yaml` for location services
- [ ] Run `flutter pub get` to install new dependencies
- [ ] Update `firestore.indexes.json` with all required composite indexes (see Schema section)
- [ ] Deploy Firestore indexes using Firebase CLI: `firebase deploy --only firestore:indexes`
- [ ] Verify Firebase project has Cloud Functions enabled
- [ ] Set up environment variables in `.env` if needed for new features

#### 0.2 Project Structure
- [ ] Create `lib/models/post_model.dart`
- [ ] Create `lib/models/comment_model.dart`
- [ ] Create `lib/models/reaction_model.dart`
- [ ] Create `lib/repositories/post_repository.dart`
- [ ] Create `lib/blocs/feed_bloc.dart`
- [ ] Create `lib/blocs/post_bloc.dart` (optional, for individual post state)
- [ ] Create `lib/screens/feed_screen.dart`
- [ ] Create `lib/screens/create_post_screen.dart`
- [ ] Create `lib/widgets/feed_widgets/` directory
- [ ] Create `lib/services/hashtag_service.dart` (utility for hashtag extraction)
- [ ] Create `lib/services/mention_service.dart` (utility for mention parsing)

#### 0.3 Firestore Security Rules
- [ ] Update `firestore.rules` with posts collection rules (read, create, update, delete)
- [ ] Add rules for `posts/{postId}/reactions` subcollection
- [ ] Add rules for `posts/{postId}/comments` subcollection
- [ ] Deploy security rules: `firebase deploy --only firestore:rules`
- [ ] Test security rules using Firebase Rules Playground

---

### 🏗️ Phase 1: Core Feed Foundation

#### 1.1 Data Models
- [ ] Implement `PostModel` class with all fields (id, authorId, content, mediaUrls, etc.)
- [ ] Add `fromDoc()` factory constructor for Firestore documents
- [ ] Add `toMap()` method for Firestore writes
- [ ] Add `copyWith()` method for immutable updates
- [ ] Implement `Equatable` for state comparison
- [ ] Add helper methods: `_extractHashtags()`, `_extractMentions()`, `_determinePostType()`
- [ ] Create unit tests for `PostModel` serialization

#### 1.2 Repository Layer
- [ ] Create `PostRepository` class in `lib/repositories/post_repository.dart`
- [ ] Inject `FirebaseFirestore` instance via GetIt
- [ ] Implement `createPost()` method with:
  - [ ] Hashtag extraction from content
  - [ ] Mention extraction from content
  - [ ] Post type determination (text/image/video/mixed)
  - [ ] Location capture (if permission granted)
  - [ ] Media URL upload to Cloudinary (if applicable)
- [ ] Implement `getFeedForUser()` method with:
  - [ ] Friends list retrieval
  - [ ] Composite query (friends OR public posts)
  - [ ] Pagination support with `lastDocument`
  - [ ] Deleted posts filtering
- [ ] Implement `getPostById()` method for single post retrieval
- [ ] Implement `getUserPosts()` method for profile posts
- [ ] Implement `deletePost()` method (soft delete)
- [ ] Implement `updatePost()` method for editing
- [ ] Add error handling and try-catch blocks
- [ ] Create unit tests for repository methods

#### 1.3 State Management (BLoC)
- [ ] Create `FeedEvent` abstract class with events:
  - [ ] `LoadFeedEvent` (with `refresh` parameter)
  - [ ] `LoadMoreFeedEvent`
  - [ ] `RefreshFeedEvent`
- [ ] Create `FeedState` abstract class with states:
  - [ ] `FeedInitial`
  - [ ] `FeedLoading`
  - [ ] `FeedLoaded` (with posts, hasMore, isLoadingMore)
  - [ ] `FeedError` (with error message)
- [ ] Implement `FeedBloc` class with:
  - [ ] `_onLoadFeed()` handler with pagination logic
  - [ ] `_onLoadMoreFeed()` handler for infinite scroll
  - [ ] `_lastDocument` tracking for pagination
  - [ ] `_hasMore` flag management
  - [ ] Error state emission
- [ ] Register `FeedBloc` in dependency injection (`locator.dart`)
- [ ] Create `FeedBloc` provider in `main.dart` or screen level
- [ ] Add proper dispose/dispose methods to prevent memory leaks

#### 1.4 UI Components - Core Feed
- [ ] Create `FeedScreen` widget with:
  - [ ] Scaffold with AppBar
  - [ ] Create post floating action button
  - [ ] Pull-to-refresh functionality
  - [ ] Empty state (no posts message)
  - [ ] Error state (retry button)
  - [ ] Loading indicator
- [ ] Create `PostCard` widget with:
  - [ ] Author header (avatar, username, timestamp)
  - [ ] Post content text display
  - [ ] Media grid/carousel for images/videos
  - [ ] Hashtag display (clickable links)
  - [ ] Mention display (clickable user links)
  - [ ] Action buttons row (reaction, comment, share placeholders)
  - [ ] Engagement counts display
  - [ ] Options menu (three dots)
- [ ] Implement infinite scroll with `ScrollController`:
  - [ ] Detect when user scrolls to 80% of list
  - [ ] Trigger `LoadMoreFeedEvent`
  - [ ] Show loading indicator at bottom during load
- [ ] Add shimmer loading skeleton for initial load
- [ ] Implement pull-to-refresh with `RefreshIndicator`

#### 1.5 Post Creation Flow
- [ ] Create `CreatePostScreen` widget with:
  - [ ] Text input field (multiline, character counter)
  - [ ] Image picker button (multi-image support)
  - [ ] Location toggle (include location checkbox)
  - [ ] Visibility selector (public/friends/nearby)
  - [ ] Post button (with loading state)
  - [ ] Cancel/dismiss button
- [ ] Implement image selection using `image_picker`:
  - [ ] Single or multiple image selection
  - [ ] Image preview grid
  - [ ] Remove image functionality
- [ ] Integrate `CloudinaryService` for media upload:
  - [ ] Upload images to Cloudinary before posting
  - [ ] Store media URLs in post document
  - [ ] Handle upload progress/errors
- [ ] Implement post creation flow:
  - [ ] Validate content (not empty or has media)
  - [ ] Show loading indicator during creation
  - [ ] Navigate back to feed on success
  - [ ] Show error snackbar on failure
  - [ ] Refresh feed after successful post creation

#### 1.6 Real-time Updates
- [ ] Implement `getFeedStream()` method in `PostRepository`:
  - [ ] Use Firestore snapshots for real-time updates
  - [ ] Limit to 50 posts for performance
  - [ ] Handle friends list changes
- [ ] Update `FeedBloc` to support stream-based updates:
  - [ ] Listen to feed stream
  - [ ] Emit updated states on stream changes
  - [ ] Handle stream errors
- [ ] Add stream subscription cleanup in dispose

#### 1.7 Navigation Integration
- [ ] Add "Feed" tab to `MainScreen` bottom navigation
- [ ] Create route in `app_routes.dart` for feed screen
- [ ] Add navigation helper in `NavigationService`
- [ ] Update `main_screen.dart` to include feed tab
- [ ] Add feed icon (can use `Icons.feed` or custom)

---

### ❤️ Phase 2: Reactions System

#### 2.1 Reaction Data Model
- [ ] Create `ReactionModel` class (simplified - optional, can use simple boolean check):
  - [ ] `userId` field
  - [ ] `timestamp` field
  - [ ] `fromDoc()` method (optional - mainly for listing users who liked)
  - [ ] Note: Can skip model class entirely and just use `hasUserLiked()` boolean check

#### 2.2 Repository Methods
- [ ] Add `likePost()` method to `PostRepository`:
  - [ ] Create reaction document in subcollection (using userId as doc ID)
  - [ ] Atomic increment of `reactionCount` in post document
  - [ ] Update `lastEngagementTimestamp`
  - [ ] Use Firestore batch for atomicity
- [ ] Add `unlikePost()` method:
  - [ ] Delete reaction document (userId as doc ID)
  - [ ] Atomic decrement of `reactionCount`
- [ ] Add `hasUserLiked()` method:
  - [ ] Check if reaction document exists for user
  - [ ] Return boolean (true if liked, false if not)
- [ ] Add `getLikedByUsers()` method (optional, for showing "liked by" list):
  - [ ] Query reactions subcollection
  - [ ] Order by timestamp descending
  - [ ] Return list of user IDs
  - [ ] Support pagination

#### 2.3 Like UI Components
- [ ] Create `LikeButton` widget:
  - [ ] Display heart icon (filled if liked, outlined if not)
  - [ ] Show like count
  - [ ] Handle tap (toggle like/unlike)
  - [ ] Red color when liked, grey when not liked
  - [ ] Optimistic UI updates
  - [ ] Loading state during API call (small spinner)
  - [ ] Error handling with rollback
  - [ ] Animate heart icon on tap (optional scale animation)
- [ ] Create `LikedByList` widget (optional, for showing who liked):
  - [ ] Display list of users who liked the post
  - [ ] Show user avatars and usernames
  - [ ] Tap to view user profile

#### 2.4 Optimistic Updates
- [ ] Implement optimistic like toggle:
  - [ ] Update heart icon and count immediately on tap
  - [ ] Show loading spinner
  - [ ] Call API in background (like/unlike)
  - [ ] Rollback on error (revert icon and count)
  - [ ] Show error snackbar on failure

#### 2.5 Cloud Functions Integration
- [ ] Update `functions/index.js` with like handler:
  - [ ] Create `onPostReactionCreated` function (triggered on like)
  - [ ] Create `onPostReactionDeleted` function (triggered on unlike)
  - [ ] Update `trendingScore` on like/unlike
  - [ ] Update `lastEngagementTimestamp`
  - [ ] Note: `reactionCount` is updated by client, function can verify consistency
- [ ] Deploy Cloud Functions: `firebase deploy --only functions`

#### 2.6 Integration
- [ ] Integrate `LikeButton` into `PostCard` widget
- [ ] Update post model to include `isLiked` boolean (optional, for UI state caching)
- [ ] Test like flows:
  - [ ] Like post (heart fills, count increases)
  - [ ] Unlike post (heart empties, count decreases)
  - [ ] Network error handling (rollback works)
  - [ ] Multiple rapid taps (debounce if needed)

---

### 💬 Phase 3: Comments System

#### 3.1 Comment Data Model
- [ ] Create `CommentModel` class with:
  - [ ] `commentId`, `postId`, `userId`
  - [ ] `username`, `photoUrl` (denormalized)
  - [ ] `text`, `timestamp`
  - [ ] `edited`, `editedAt`
  - [ ] `reactions` Map (for comment reactions)
  - [ ] `deleted`, `deletedAt` (soft delete)
  - [ ] `fromDoc()` and `toMap()` methods

#### 3.2 Repository Methods
- [ ] Add `addComment()` method to `PostRepository`:
  - [ ] Get user info for denormalization
  - [ ] Create comment in subcollection
  - [ ] Atomic increment of `commentCount`
  - [ ] Update `lastEngagementTimestamp`
  - [ ] Use batch for atomicity
- [ ] Add `getComments()` method with pagination:
  - [ ] Query comments subcollection
  - [ ] Filter deleted comments
  - [ ] Order by timestamp ascending (oldest first)
  - [ ] Support pagination
- [ ] Add `editComment()` method:
  - [ ] Update comment text
  - [ ] Set `edited` flag to true
  - [ ] Update `editedAt` timestamp
- [ ] Add `deleteComment()` method:
  - [ ] Soft delete (set `deleted = true`)
  - [ ] Atomic decrement of `commentCount`
- [ ] Add `likeComment()` method (optional, for comment likes):
  - [ ] Add userId to likes array or create like document in subcollection
  - [ ] Similar pattern to post likes

#### 3.3 Comment UI Components
- [ ] Create `CommentsSheet` widget (bottom sheet):
  - [ ] Draggable scrollable sheet
  - [ ] Header with comment count
  - [ ] Comments list with pagination
  - [ ] Input field at bottom
  - [ ] Send button
  - [ ] Close button
- [ ] Create `CommentTile` widget:
  - [ ] Author avatar and username
  - [ ] Comment text
  - [ ] Timestamp (with "edited" indicator if edited)
  - [ ] Like button (optional, for comment likes - simple heart icon)
  - [ ] Delete button (if user's own comment)
  - [ ] Edit button (if user's own comment)
- [ ] Create `CommentInput` widget:
  - [ ] Text field
  - [ ] Character counter
  - [ ] Send button
  - [ ] Placeholder text

#### 3.4 Optimistic Updates
- [ ] Implement optimistic comment add:
  - [ ] Add temporary comment to list immediately
  - [ ] Show loading indicator
  - [ ] Call API
  - [ ] Replace temp comment with real one on success
  - [ ] Remove temp comment on error
- [ ] Implement optimistic comment delete:
  - [ ] Remove from list immediately
  - [ ] Call API in background
  - [ ] Re-add on error

#### 3.5 Comment Editing
- [ ] Add edit comment flow:
  - [ ] Show edit dialog/modal
  - [ ] Pre-fill with current text
  - [ ] Save button updates comment
  - [ ] Cancel button dismisses
- [ ] Update `CommentTile` to show "edited" indicator

#### 3.6 Integration
- [ ] Integrate `CommentsSheet` into `PostCard`:
  - [ ] Add "View X comments" button
  - [ ] Open sheet on tap
  - [ ] Update comment count after adding comment
- [ ] Update `PostCard` to show comment count
- [ ] Test comment flows:
  - [ ] Add comment
  - [ ] Edit comment
  - [ ] Delete comment
  - [ ] Pagination
  - [ ] Network error handling

---

### 📍 Phase 4: Nearby Feed

#### 4.1 Location Services
- [ ] Add location permission request flow:
  - [ ] Check permission status
  - [ ] Request permission if not granted
  - [ ] Handle permission denied state
  - [ ] Show rationale dialog if needed
- [ ] Implement `getCurrentLocation()` method:
  - [ ] Use `geolocator` package
  - [ ] Handle errors (permission denied, service disabled)
  - [ ] Return `Location` object with lat/lng
- [ ] Create location service wrapper:
  - [ ] `LocationService` class
  - [ ] Cache location (update every 5 minutes)
  - [ ] Background location updates (optional)

#### 4.2 Geospatial Queries
- [ ] Implement `getNearbyPosts()` method in `PostRepository`:
  - [ ] Calculate bounding box from user location and radius
  - [ ] Query posts with location in bounding box
  - [ ] Filter by actual distance (Haversine formula)
  - [ ] Support pagination
  - [ ] Order by distance or timestamp
- [ ] Add distance calculation helper:
  - [ ] Implement Haversine formula
  - [ ] Return distance in kilometers
- [ ] Create Firestore index for location queries:
  - [ ] Composite index: visibility + location.latitude + location.longitude + timestamp

#### 4.3 Nearby Feed UI
- [ ] Create `NearbyFeedTab` widget:
  - [ ] Similar to main feed but uses `getNearbyPosts()`
  - [ ] Show location status indicator
  - [ ] Request location permission if needed
  - [ ] Show distance badge on posts (optional)
- [ ] Update `FeedBloc` to support `FeedType.nearby`:
  - [ ] Add `FeedType` enum
  - [ ] Modify `_onLoadFeed()` to handle nearby type
  - [ ] Pass user location to repository
- [ ] Add location picker to post creation:
  - [ ] Toggle to include location
  - [ ] Display current location address
  - [ ] Allow manual location selection (optional)

#### 4.4 Integration
- [ ] Add "Nearby" tab to feed screen (if using tabs):
  - [ ] Tab bar with "Following", "Trending", "Nearby"
  - [ ] Switch between feed types
- [ ] Or create separate screen accessed from main feed
- [ ] Update navigation to include nearby feed option
- [ ] Test nearby feed:
  - [ ] Location permission flow
  - [ ] Nearby posts display
  - [ ] Distance calculation accuracy
  - [ ] Pagination

**Note:** Final implementation structure will use two main sections:
1. **Nearby Section**: Dedicated section/tab for location-based posts
2. **Unified Feed Section**: Single section that merges all other feed types (Following, Trending, etc.) with tabs or filters to switch between them

---

### 🔥 Phase 5: Trending Section

#### 5.1 Trending Algorithm
- [ ] Implement Cloud Function `onPostCreated`:
  - [ ] Calculate initial `trendingScore` on post creation
  - [ ] Formula: `100 - ageInHours` (recency bonus)
- [ ] Implement Cloud Function `onPostEngagement`:
  - [ ] Trigger on reaction/comment creation
  - [ ] Recalculate `trendingScore`:
    - [ ] `(reactions * 1) + (comments * 2) + recencyBonus`
    - [ ] `recencyBonus = max(0, 50 - ageInHours * 2)`
  - [ ] Update `trendingScore` and `lastEngagementTimestamp`
- [ ] Deploy Cloud Functions

#### 5.2 Trending Repository
- [ ] Implement `getTrendingPosts()` method in `PostRepository`:
  - [ ] Query posts ordered by `trendingScore` descending
  - [ ] Secondary sort by `timestamp` descending
  - [ ] Filter by `visibility = 'public'`
  - [ ] Filter deleted posts
  - [ ] Support pagination

#### 5.3 Trending UI
- [ ] Create `TrendingFeedTab` widget:
  - [ ] Similar to main feed
  - [ ] Use `getTrendingPosts()` method
  - [ ] Show "Trending" badge/indicator
- [ ] Update `FeedBloc` to support `FeedType.trending`
- [ ] Add time filter options (optional):
  - [ ] "Today", "This Week", "All Time" buttons
  - [ ] Filter posts by time window
- [ ] Create trending hashtags section (optional):
  - [ ] Query posts grouped by hashtag
  - [ ] Calculate hashtag trending score
  - [ ] Display top trending hashtags

#### 5.4 Integration
- [ ] Add "Trending" tab to feed screen (or include in unified feed section with tabs/filters)
- [ ] Update navigation
- [ ] Test trending algorithm:
  - [ ] Create test posts with varying engagement
  - [ ] Verify scores update correctly
  - [ ] Verify ranking order

**Note:** Final implementation structure will use two main sections:
1. **Nearby Section**: Dedicated section/tab for location-based posts
2. **Unified Feed Section**: Single section that merges all other feed types (Following, Trending, etc.) with tabs or filters to switch between them

---

### 🔗 Phase 6: Integration & Enhancement

#### 6.1 Hashtag System
- [ ] Implement `HashtagService`:
  - [ ] Extract hashtags from text using regex
  - [ ] Store in post `hashtags` array
- [ ] Create hashtag search/explore:
  - [ ] `getPostsByHashtag()` method
  - [ ] Hashtag screen with posts
  - [ ] Clickable hashtags in posts
- [ ] Create trending hashtags (optional):
  - [ ] Aggregate hashtag engagement
  - [ ] Display top hashtags

#### 6.2 Mention System
- [ ] Implement `MentionService`:
  - [ ] Extract mentions from text (@username)
  - [ ] Validate mentioned users exist
  - [ ] Store in post `mentions` array
- [ ] Create mention notifications:
  - [ ] Cloud Function to send notification on mention
  - [ ] FCM notification with deep link
- [ ] Create mentioned posts view:
  - [ ] "Posts you're mentioned in" screen
  - [ ] Accessible from profile/menu

#### 6.3 Profile Integration
- [ ] Update `ProfileScreen` to show user's posts:
  - [ ] Add "Posts" tab to profile
  - [ ] Query `getUserPosts()` for profile user
  - [ ] Display in grid or list
- [ ] Add post count to profile
- [ ] Link from post author to profile

#### 6.4 Notification Integration
- [ ] Update Cloud Functions for feed notifications:
  - [ ] Comment notification: Send FCM when someone comments on user's post
  - [ ] Reaction notification: Send FCM when someone reacts to user's post
  - [ ] Mention notification: Send FCM when user is mentioned
- [ ] Update `NotificationRepository`:
  - [ ] Create notification documents
  - [ ] Link to posts/comments
- [ ] Update notification UI:
  - [ ] Deep link to post/comment on tap
  - [ ] Show post preview in notification

#### 6.5 Friends Integration
- [ ] Ensure feed shows friends' posts:
  - [ ] Query includes friends list
  - [ ] Update feed when friends list changes
- [ ] Add "Friend Activity" section (optional):
  - [ ] Show what friends are engaging with

#### 6.6 Post Sharing
- [ ] Implement share functionality:
  - [ ] Use `share_plus` package or `url_launcher`
  - [ ] Generate deep link to post
  - [ ] Share post content as text/image
- [ ] Add share button to `PostCard`

#### 6.7 Media Enhancements
- [ ] Image gallery viewer:
  - [ ] Tap image to view full screen
  - [ ] Swipe between multiple images
  - [ ] Zoom/pan functionality
- [ ] Video player (if adding video support):
  - [ ] Autoplay on scroll into view
  - [ ] Mute/unmute controls
  - [ ] Play/pause controls

---

### 🧪 Phase 7: Testing & Optimization

#### 7.1 Unit Tests
- [ ] Test `PostModel` serialization
- [ ] Test `CommentModel` serialization
- [ ] Test like functionality (boolean check, no model needed)
- [ ] Test `PostRepository` methods:
  - [ ] Create post
  - [ ] Get feed
  - [ ] Like/unlike posts
  - [ ] Add/edit/delete comments
  - [ ] Get nearby posts
  - [ ] Get trending posts
- [ ] Test `FeedBloc` state transitions
- [ ] Test hashtag/mention extraction

#### 7.2 Widget Tests
- [ ] Test `PostCard` widget rendering
- [ ] Test `CommentsSheet` widget
- [ ] Test `LikeButton` widget
- [ ] Test `FeedScreen` states (loading, error, loaded)

#### 7.3 Integration Tests
- [ ] Test full post creation flow
- [ ] Test feed loading and pagination
- [ ] Test reaction flow
- [ ] Test comment flow
- [ ] Test nearby feed
- [ ] Test trending feed

#### 7.4 Performance Optimization
- [ ] Implement image caching:
  - [ ] Use `cached_network_image` for post images
  - [ ] Pre-cache images on scroll
- [ ] Implement lazy loading:
  - [ ] Load images only when visible
  - [ ] Use `ListView.builder` efficiently
- [ ] Optimize Firestore queries:
  - [ ] Add missing indexes
  - [ ] Limit query results
  - [ ] Use pagination properly
- [ ] Optimize state management:
  - [ ] Avoid unnecessary rebuilds
  - [ ] Use `const` widgets where possible
  - [ ] Dispose controllers properly

#### 7.5 Error Handling
- [ ] Add error boundaries for feed screen
- [ ] Handle network errors gracefully
- [ ] Show user-friendly error messages
- [ ] Implement retry mechanisms
- [ ] Log errors for debugging

#### 7.6 Analytics (Optional)
- [ ] Track post creation events
- [ ] Track reaction events
- [ ] Track comment events
- [ ] Track feed engagement metrics
- [ ] Track trending post views

---

### 🚀 Phase 8: Deployment & Launch

#### 8.1 Pre-Launch Checklist
- [ ] All Firestore indexes deployed
- [ ] All Cloud Functions deployed
- [ ] Security rules tested and deployed
- [ ] All features tested on real devices
- [ ] Performance tested with large datasets
- [ ] Error handling verified
- [ ] Offline behavior tested

#### 8.2 Documentation
- [ ] Update `README.md` with feed features
- [ ] Document API endpoints (if any)
- [ ] Document data models
- [ ] Document state management patterns
- [ ] Add code comments where complex

#### 8.3 Monitoring
- [ ] Set up Firebase Analytics
- [ ] Set up Crashlytics
- [ ] Monitor Cloud Function execution
- [ ] Monitor Firestore read/write usage
- [ ] Set up alerts for errors

#### 8.4 Launch
- [ ] Deploy to staging environment
- [ ] Perform final QA testing
- [ ] Deploy to production
- [ ] Monitor for issues
- [ ] Collect user feedback

---

### 💰 Phase 6A: Ads Integration (Instagram-Style)

#### 6A.1 Ad Network Setup
- [ ] Set up Google AdMob account (if not already done)
- [ ] Create Native Ad units in AdMob console:
  - [ ] Feed Native Ad (medium rectangle format)
  - [ ] Banner Ad (for feed insertion)
  - [ ] Test ad unit IDs for development
- [ ] Configure ad placement frequency (e.g., every 5-10 posts)
- [ ] Set up ad targeting parameters:
  - [ ] User demographics (age, gender, location)
  - [ ] User interests (from profile)
  - [ ] Content categories

#### 6A.2 Ad Data Model
- [ ] Create `AdPlaceholder` model or use Google AdMob's `NativeAd` directly
- [ ] Ad metadata structure:
  ```javascript
  {
    adUnitId: string,
    adType: 'native' | 'banner',
    position: number, // Where in feed (e.g., after post 5)
    frequency: number, // Show every N posts
    adData: {
      headline: string,
      body: string,
      callToAction: string,
      advertiser: string,
      iconUrl: string,
      imageUrl: string,
      price: string,
      store: string,
      starRating: number
    }
  }
  ```

#### 6A.3 Ad Repository & Service
- [ ] Create `AdService` class:
  - [ ] `loadNativeAd()` method
  - [ ] `disposeAd()` method
  - [ ] Ad caching for performance
  - [ ] Ad refresh logic (every X views)
- [ ] Integrate with existing `AdHelper` class
- [ ] Add ad loading error handling
- [ ] Implement ad impression tracking

#### 6A.4 Feed Ad Integration
- [ ] Modify `FeedBloc` to insert ad placeholders:
  - [ ] Calculate ad positions based on frequency
  - [ ] Mix ads into feed list (after post N, N+frequency, etc.)
  - [ ] Handle pagination with ads (ads shouldn't break infinite scroll)
- [ ] Create `AdCard` widget:
  - [ ] Native ad format matching post card style
  - [ ] "Sponsored" or "Ad" label
  - [ ] Ad content (headline, body, image, CTA button)
  - [ ] Handle ad tap (opens advertiser page)
- [ ] Create `FeedItemType` enum:
  ```dart
  enum FeedItemType { post, ad }
  ```
- [ ] Update feed list to handle mixed content:
  - [ ] Check item type before rendering
  - [ ] Render `PostCard` or `AdCard` accordingly

#### 6A.5 Ad UI Components
- [ ] Create `NativeAdCard` widget:
  - [ ] Match post card styling for seamless integration
  - [ ] Display "Sponsored" badge
  - [ ] Show advertiser info
  - [ ] Ad image/icon
  - [ ] Ad headline and body text
  - [ ] Call-to-action button
- [ ] Implement ad loading states:
  - [ ] Skeleton loader while ad loads
  - [ ] Error state if ad fails to load
- [ ] Add ad tap tracking:
  - [ ] Track ad impressions
  - [ ] Track ad clicks
  - [ ] Send analytics events

#### 6A.6 Ad Frequency & Placement Logic
- [ ] Implement smart ad placement:
  - [ ] Insert ads after N posts (e.g., every 5 posts)
  - [ ] Avoid placing ads too close together
  - [ ] Don't show ads in first 3 posts
  - [ ] Don't show ads if feed is short (< 5 posts)
- [ ] Create `AdPlacementService`:
  - [ ] Calculate ad positions dynamically
  - [ ] Track ad views per session
  - [ ] Limit ad frequency per user
  - [ ] Randomize ad positions (slight variation)

#### 6A.7 Ad Analytics & Monetization
- [ ] Track ad metrics:
  - [ ] Ad impressions
  - [ ] Ad clicks (CTR)
  - [ ] Revenue per user
  - [ ] Ad fill rate
- [ ] Integrate with Firebase Analytics
- [ ] Create admin dashboard for ad performance (optional)
- [ ] Set up ad revenue reporting

---

### 🚀 Phase 6B: Boost/Promote Post System

#### 6B.1 Boost Data Model
- [ ] Add boost fields to `PostModel`:
  ```javascript
  {
    isBoosted: boolean,
    boostEndTime: Timestamp,
    boostTargeting: {
      location: string[], // Target locations
      ageRange: { min: number, max: number },
      gender: string[], // Target genders
      interests: string[], // Target interests
    },
    boostBudget: number, // Total budget spent
    boostStats: {
      impressions: number,
      clicks: number,
      reach: number,
      engagement: number
    }
  }
  ```
- [ ] Create `BoostPackage` model:
  ```javascript
  {
    packageId: string,
    name: string, // "Reach 1000 users", "Boost for 7 days"
    duration: number, // Days
    targetReach: number, // Estimated reach
    price: number, // In coins or real money
    targeting: boolean // Whether targeting is available
  }
  ```

#### 6B.2 Payment Integration
- [ ] Integrate with existing `StoreRepository` for coin purchases
- [ ] Add boost purchase flow:
  - [ ] User selects boost package
  - [ ] Check user has enough coins
  - [ ] Process payment (deduct coins)
  - [ ] Create boost record
  - [ ] Activate boost on post
- [ ] Create boost purchase screen:
  - [ ] Display available boost packages
  - [ ] Show pricing (coins or real money)
  - [ ] Package comparison
  - [ ] Purchase button with confirmation

#### 6B.3 Boost Targeting System
- [ ] Create targeting selection UI:
  - [ ] Location picker (multiple locations)
  - [ ] Age range slider
  - [ ] Gender selection (male, female, all)
  - [ ] Interest tags selector
  - [ ] Estimated reach calculator
- [ ] Implement `BoostTargetingService`:
  - [ ] Calculate target audience size
  - [ ] Estimate reach based on budget
  - [ ] Validate targeting parameters
  - [ ] Store targeting preferences

#### 6B.4 Boost Algorithm & Feed Integration
- [ ] Modify feed query to prioritize boosted posts:
  ```dart
  // Mix boosted posts into feed based on:
  // - Boost targeting match
  // - Boost remaining time
  // - Boost budget remaining
  ```
- [ ] Create `getBoostedPosts()` method in `PostRepository`:
  - [ ] Query posts with `isBoosted = true`
  - [ ] Filter by boost targeting (location, age, gender, interests)
  - [ ] Filter by active boost (`boostEndTime > now`)
  - [ ] Order by boost priority score
- [ ] Implement boost mixing logic:
  - [ ] Insert boosted posts every N organic posts
  - [ ] Limit boosted posts per feed (e.g., max 2 per 10 posts)
  - [ ] Ensure variety (don't show same boosted post repeatedly)
- [ ] Add "Promoted" label to boosted posts:
  - [ ] Visual indicator on post card
  - [ ] "Sponsored" or "Promoted" badge

#### 6B.5 Boost Analytics Dashboard
- [ ] Create boost stats screen:
  - [ ] Accessible from post options menu
  - [ ] Show boost metrics:
    - [ ] Impressions (how many saw the post)
    - [ ] Reach (unique users)
    - [ ] Clicks/engagement
    - [ ] Cost per impression/click
  - [ ] Visual charts/graphs
  - [ ] Time-based analytics (last 7 days, etc.)
- [ ] Implement real-time boost stat updates:
  - [ ] Track impressions when post is shown
  - [ ] Track engagement (likes, comments) from boosted post
  - [ ] Update boost stats in Firestore

#### 6B.6 Boost Management UI
- [ ] Add "Boost Post" button to post options:
  - [ ] Show available boost packages
  - [ ] Quick boost (one-click with default settings)
  - [ ] Advanced boost (with targeting)
- [ ] Create `BoostPostScreen`:
  - [ ] Package selection
  - [ ] Targeting options
  - [ ] Budget selection
  - [ ] Estimated reach display
  - [ ] Purchase confirmation
- [ ] Add boost status indicator:
  - [ ] "Boosted" badge on post
  - [ ] Remaining boost time
  - [ ] Boost performance summary

#### 6B.7 Cloud Functions for Boost
- [ ] Create `onBoostPurchased` function:
  - [ ] Activate boost on post
  - [ ] Set boost end time
  - [ ] Initialize boost stats
  - [ ] Send confirmation notification
- [ ] Create `onBoostExpired` function:
  - [ ] Deactivate boost (set `isBoosted = false`)
  - [ ] Archive boost stats
  - [ ] Send notification to user
- [ ] Implement boost budget tracking:
  - [ ] Deduct budget on each impression
  - [ ] Pause boost when budget exhausted
  - [ ] Send low budget warning

#### 6B.8 Boost Packages & Pricing
- [ ] Define default boost packages:
  - [ ] Basic: 1 day, 500 coins, basic reach
  - [ ] Standard: 3 days, 1200 coins, targeted reach
  - [ ] Premium: 7 days, 2500 coins, advanced targeting
- [ ] Make packages configurable in admin panel
- [ ] Add boost package management:
  - [ ] Create/edit packages
  - [ ] Set pricing
  - [ ] Enable/disable packages

---

### 👥 Phase 6C: Pages & Admin System

#### 6C.1 Page Data Model
- [ ] Create `PageModel` class:
  ```javascript
  {
    pageId: string,
    pageName: string,
    pageHandle: string, // @pagehandle (unique)
    pageType: 'business' | 'community' | 'creator',
    description: string,
    profileImageUrl: string,
    coverImageUrl: string,
    category: string, // Business category
    website: string,
    contactEmail: string,
    location: string,
    
    // Ownership & Admin
    ownerId: string, // Creator user ID
    admins: string[], // Array of admin user IDs
    moderators: string[], // Array of moderator user IDs
    
    // Stats
    followerCount: number,
    postCount: number,
    verificationStatus: 'none' | 'pending' | 'verified',
    verifiedAt: Timestamp,
    
    // Settings
    isPublic: boolean,
    allowFollowers: boolean,
    allowMessages: boolean,
    
    // Timestamps
    createdAt: Timestamp,
    updatedAt: Timestamp
  }
  ```
- [ ] Create page-post relationship:
  - [ ] Add `pageId` field to `PostModel`
  - [ ] If `pageId` exists, post belongs to page
  - [ ] Display page name/icon on page posts
- [ ] Create `PageFollow` model (subcollection):
  ```javascript
  pages/{pageId}/followers/{userId}
  {
    userId: string,
    followedAt: Timestamp
  }
  ```

#### 6C.2 Page Repository
- [ ] Create `PageRepository` class:
  - [ ] `createPage()` - Create new page
  - [ ] `updatePage()` - Update page info
  - [ ] `getPage()` - Get page by ID
  - [ ] `getPageByHandle()` - Get page by handle (@handle)
  - [ ] `followPage()` - User follows page
  - [ ] `unfollowPage()` - User unfollows page
  - [ ] `isFollowingPage()` - Check if user follows
  - [ ] `getUserPages()` - Get pages owned/admin by user
  - [ ] `getPageFollowers()` - Get page followers list
  - [ ] `searchPages()` - Search pages by name/category
- [ ] Add page post methods:
  - [ ] `createPagePost()` - Create post as page
  - [ ] `getPagePosts()` - Get posts by page
  - [ ] `getPageFeed()` - Get feed for page followers

#### 6C.3 Page Creation Flow
- [ ] Create `CreatePageScreen`:
  - [ ] Page name input
  - [ ] Page handle generator (@handle)
  - [ ] Handle availability check
  - [ ] Category selection
  - [ ] Page type selection (business/community/creator)
  - [ ] Description textarea
  - [ ] Profile image picker
  - [ ] Cover image picker (optional)
  - [ ] Website/contact info (optional)
  - [ ] Create button
- [ ] Add page creation validation:
  - [ ] Name must be unique
  - [ ] Handle must be unique and valid format
  - [ ] Required fields validation
- [ ] Handle creation success:
  - [ ] Navigate to new page
  - [ ] Show success message
  - [ ] Auto-follow page for creator

#### 6C.4 Page Profile Screen
- [ ] Create `PageProfileScreen`:
  - [ ] Cover image header
  - [ ] Profile image (overlapping cover)
  - [ ] Page name and handle
  - [ ] Verification badge (if verified)
  - [ ] Follow/Unfollow button
  - [ ] Page stats (followers, posts)
  - [ ] Description and category
  - [ ] Website/contact links
  - [ ] Page posts tab (grid/list view)
  - [ ] About tab (page info)
  - [ ] Settings button (if admin/owner)
- [ ] Add page actions menu:
  - [ ] Follow/Unfollow
  - [ ] Message (if allowed)
  - [ ] Share page
  - [ ] Report page

#### 6C.5 Admin & Moderation System
- [ ] Create admin roles enum:
  ```dart
  enum PageRole { owner, admin, moderator }
  ```
- [ ] Create `PageAdminService`:
  - [ ] `addAdmin()` - Add admin to page
  - [ ] `removeAdmin()` - Remove admin
  - [ ] `addModerator()` - Add moderator
  - [ ] `removeModerator()` - Remove moderator
  - [ ] `checkAdminPermission()` - Check user permissions
- [ ] Create admin dashboard:
  - [ ] Accessible from page profile (if user is admin)
  - [ ] Page settings management
  - [ ] Post management (edit/delete page posts)
  - [ ] Follower management
  - [ ] Analytics dashboard (page stats)
  - [ ] Admin/Moderator management
- [ ] Create `PageSettingsScreen`:
  - [ ] Edit page info
  - [ ] Change profile/cover images
  - [ ] Manage admins/moderators
  - [ ] Page privacy settings
  - [ ] Delete page option (owner only)

#### 6C.6 Page Post Creation
- [ ] Modify `CreatePostScreen` to support pages:
  - [ ] Add "Post as" selector (personal account or page)
  - [ ] If page selected, show page picker
  - [ ] Display selected page name/icon
- [ ] Update `PostRepository.createPost()`:
  - [ ] Accept `pageId` parameter
  - [ ] Validate user has permission to post as page
  - [ ] Set post `authorId` to page ID (or keep user ID with page reference)
  - [ ] Denormalize page name/icon in post
- [ ] Update post display:
  - [ ] Show page name instead of username
  - [ ] Show page icon instead of user avatar
  - [ ] Add "Promoted by [Page Name]" label
  - [ ] Link to page profile on tap

#### 6C.7 Page Feed Integration
- [ ] Update feed query to include page posts:
  - [ ] Show posts from followed pages
  - [ ] Show posts from pages user is admin of
  - [ ] Mix page posts with regular posts
- [ ] Create page-specific feed:
  - [ ] Page's own posts feed
  - [ ] Accessible from page profile
  - [ ] Grid/list view toggle
- [ ] Add page follower feed:
  - [ ] Feed showing posts from all followed pages
  - [ ] New tab in main feed (optional)

#### 6C.8 Page Verification System
- [ ] Create verification request flow:
  - [ ] "Request Verification" button on page
  - [ ] Verification form:
    - [ ] Business documentation
    - [ ] Identity proof
    - [ ] Additional info
  - [ ] Submit for review
- [ ] Create admin verification panel (Cloud Functions):
  - [ ] Review verification requests
  - [ ] Approve/reject requests
  - [ ] Grant verification badge
- [ ] Add verified badge display:
  - [ ] Blue checkmark icon
  - [ ] Display on page profile
  - [ ] Display on page posts

#### 6C.9 Page Analytics
- [ ] Create `PageAnalyticsService`:
  - [ ] Track page follower growth
  - [ ] Track post engagement (likes, comments, shares)
  - [ ] Track post reach
  - [ ] Track page profile views
  - [ ] Track best performing posts
- [ ] Create analytics dashboard UI:
  - [ ] Follower growth chart
  - [ ] Engagement metrics
  - [ ] Top posts list
  - [ ] Audience demographics (if available)
- [ ] Integrate with Firebase Analytics

#### 6C.10 Page Search & Discovery
- [ ] Add page search functionality:
  - [ ] Search by page name
  - [ ] Search by category
  - [ ] Filter by verification status
  - [ ] Sort by followers/engagement
- [ ] Create "Discover Pages" section:
  - [ ] Trending pages
  - [ ] Recommended pages (based on interests)
  - [ ] New pages
  - [ ] Verified pages directory

---

### 📋 Phase 6D: Integration & Enhancement (Updated)

*Note: Original Phase 6 tasks, now renamed to 6D to accommodate new phases*

#### 6D.1 Hashtag System
- [ ] Implement `HashtagService`
- [ ] Create hashtag search/explore
- [ ] Create trending hashtags

#### 6D.2 Mention System
- [ ] Implement `MentionService`
- [ ] Create mention notifications
- [ ] Create mentioned posts view

#### 6D.3 Profile Integration
- [ ] Update `ProfileScreen` to show user's posts
- [ ] Add post count to profile
- [ ] Link from post author to profile

#### 6D.4 Notification Integration
- [ ] Update Cloud Functions for feed notifications
- [ ] Update `NotificationRepository`
- [ ] Update notification UI

#### 6D.5 Friends Integration
- [ ] Ensure feed shows friends' posts
- [ ] Add "Friend Activity" section (optional)

#### 6D.6 Post Sharing
- [ ] Implement share functionality
- [ ] Add share button to `PostCard`

#### 6D.7 Media Enhancements
- [ ] Image gallery viewer
- [ ] Video player (if adding video support)

---

### 🔍 Phase 6E: Search & Discovery System

#### 6E.1 Search Infrastructure
- [ ] Create `SearchRepository` class:
  - [ ] `searchPosts()` - Search posts by content
  - [ ] `searchUsers()` - Search users by username/name
  - [ ] `searchPages()` - Search pages
  - [ ] `searchHashtags()` - Search hashtags
  - [ ] `getTrendingHashtags()` - Get trending hashtags
  - [ ] `getRecentSearches()` - Get user's recent searches
  - [ ] `saveSearch()` - Save search to history
  - [ ] `clearSearchHistory()` - Clear search history
- [ ] Create Firestore indexes for search:
  - [ ] Composite index for post content search
  - [ ] Index for username search
  - [ ] Index for hashtag search

#### 6E.2 Search UI Components
- [ ] Create `SearchScreen` widget:
  - [ ] Search bar with autocomplete
  - [ ] Recent searches section
  - [ ] Trending hashtags section
  - [ ] Search results tabs (All, Posts, Users, Pages, Hashtags)
  - [ ] Search filters (date, location, media type)
  - [ ] Empty state for no results
- [ ] Create `SearchBar` widget:
  - [ ] Autocomplete suggestions
  - [ ] Search history dropdown
  - [ ] Voice search button (optional)
  - [ ] Clear button
- [ ] Create `SearchResultItem` widgets:
  - [ ] Post result card
  - [ ] User result card
  - [ ] Page result card
  - [ ] Hashtag result chip

#### 6E.3 Search BLoC
- [ ] Create `SearchEvent` class:
  - [ ] `SearchQueryEvent` - User types query
  - [ ] `SearchFilterEvent` - Apply filters
  - [ ] `ClearSearchEvent` - Clear search
- [ ] Create `SearchState` class:
  - [ ] `SearchInitial`
  - [ ] `SearchLoading`
  - [ ] `SearchResultsLoaded` - With results
  - [ ] `SearchError`
- [ ] Implement `SearchBloc`:
  - [ ] Debounce search queries (300ms)
  - [ ] Handle multiple search types
  - [ ] Cache search results
  - [ ] Handle search history

---

### ✏️ Phase 6F: Post Management Features

#### 6F.1 Post Editing
- [ ] Add edit functionality to `PostModel`:
  - [ ] `edited` boolean field
  - [ ] `editedAt` timestamp
  - [ ] `editHistory` array (optional, for version tracking)
- [ ] Update `PostRepository`:
  - [ ] Add `editPost()` method:
    - [ ] Validate user is post author
    - [ ] Update post content/media
    - [ ] Set `edited = true`
    - [ ] Update `editedAt` timestamp
    - [ ] Add to edit history (if tracking)
- [ ] Update post UI:
  - [ ] Add "Edit" button to own posts
  - [ ] Show "Edited" indicator on edited posts
  - [ ] Edit post screen (reuse CreatePostScreen)
  - [ ] Time limit for editing (e.g., 24 hours - optional)

#### 6F.2 Post Pinning
- [ ] Add pin fields to `PostModel`:
  - [ ] `isPinned` boolean
  - [ ] `pinnedAt` timestamp
  - [ ] `pinnedOrder` number (for ordering multiple pins)
- [ ] Add pin methods to `PostRepository`:
  - [ ] `pinPost()` - Pin post to profile
  - [ ] `unpinPost()` - Unpin post
  - [ ] `getPinnedPosts()` - Get user's pinned posts
  - [ ] `reorderPinnedPosts()` - Change pin order
- [ ] Add pin UI:
  - [ ] Pin button on posts (own posts only)
  - [ ] Pinned posts appear first on profile
  - [ ] Pin indicator on post card
  - [ ] Limit: Max 3-5 pinned posts

#### 6F.3 Multi-Image Carousel with Individual Captions
- [ ] Update `PostModel`:
  - [ ] Change `mediaUrls` to support captions:
    ```dart
    List<MediaItem> mediaItems; // Instead of List<String>
    class MediaItem {
      String url;
      String? caption; // Individual caption per image
      String type; // 'image' | 'video'
      int order; // Display order
    }
    ```
- [ ] Update post creation UI:
  - [ ] Multi-image picker
  - [ ] Image preview with caption field per image
  - [ ] Reorder images (drag & drop)
  - [ ] Remove individual images
  - [ ] Caption per image editor
- [ ] Update `PostCard` widget:
  - [ ] Display carousel with indicators
  - [ ] Show caption for current image
  - [ ] Swipe between images
  - [ ] Dot indicators showing which image is active

#### 6F.4 Location Check-ins
- [ ] Add location fields to `PostModel`:
  - [ ] `location` object (already exists, extend):
    ```javascript
    {
      latitude: number,
      longitude: number,
      address: string,
      placeName: string, // e.g., "Starbucks Downtown"
      placeId: string, // Google Places ID
      city: string,
      country: string
    }
    ```
- [ ] Create `LocationService`:
  - [ ] `searchPlaces()` - Search nearby places
  - [ ] `getPlaceDetails()` - Get place info
  - [ ] `getCurrentLocation()` - Get user location
  - [ ] `formatLocation()` - Format address string
- [ ] Add location UI:
  - [ ] Location toggle in post creation
  - [ ] Location search/picker
  - [ ] Nearby places list
  - [ ] Location tag on post display
  - [ ] Map view of check-ins (optional)
- [ ] Location-based features:
  - [ ] Feed filter by location
  - [ ] "Posts from this location" view
  - [ ] Location trending posts

#### 6F.5 Post Templates
- [ ] Create `PostTemplateModel`:
  ```javascript
  {
    templateId: string,
    name: string,
    description: string,
    content: string, // Template content with variables
    mediaUrls: string[], // Template media
    hashtags: string[],
    visibility: string,
    createdBy: string, // userId or pageId
    isPublic: boolean, // Share with others
    usedCount: number,
    createdAt: Timestamp
  }
  ```
- [ ] Create `PostTemplateRepository`:
  - [ ] `createTemplate()` - Save post as template
  - [ ] `getTemplates()` - Get user's templates
  - [ ] `applyTemplate()` - Use template for new post
  - [ ] `deleteTemplate()` - Delete template
  - [ ] `getPublicTemplates()` - Browse shared templates
- [ ] Add template UI:
  - [ ] "Save as Template" button in post creation
  - [ ] Template library screen
  - [ ] Apply template flow
  - [ ] Template editor
  - [ ] Share template option

---

### 🛡️ Phase 6G: Reporting & Moderation System

#### 6G.1 Post Reporting System
- [ ] Create `ReportModel`:
  ```javascript
  {
    reportId: string,
    reportedContentType: 'post' | 'comment' | 'page' | 'user',
    reportedContentId: string,
    reportedBy: string, // userId
    reportCategory: string, // 'spam', 'harassment', 'false_info', etc.
    reportReason: string, // User's explanation
    status: 'pending' | 'reviewed' | 'resolved' | 'dismissed',
    reviewedBy: string, // Admin userId
    reviewedAt: Timestamp,
    actionTaken: string, // 'deleted', 'warned', 'no_action'
    createdAt: Timestamp
  }
  ```
- [ ] Create `ReportRepository`:
  - [ ] `reportContent()` - Submit report
  - [ ] `getReports()` - Get reports (admin only)
  - [ ] `updateReportStatus()` - Update report status
  - [ ] `getUserReports()` - Get reports by user
- [ ] Add report UI:
  - [ ] Report button on posts/comments
  - [ ] Report screen with categories:
    - [ ] Spam
    - [ ] Harassment or bullying
    - [ ] False information
    - [ ] Inappropriate content
    - [ ] Violence
    - [ ] Intellectual property violation
    - [ ] Other
  - [ ] Report reason text input
  - [ ] Submit confirmation
  - [ ] Report status tracking

#### 6G.2 Content Moderation Dashboard
- [ ] Create admin-only `ModerationDashboard`:
  - [ ] Reported content queue
  - [ ] Filter reports by status/category
  - [ ] View reported content
  - [ ] Review reports (approve/reject)
  - [ ] Take actions:
    - [ ] Delete content
    - [ ] Warn user
    - [ ] Ban user temporarily
    - [ ] Ban user permanently
    - [ ] Dismiss report (no action)
  - [ ] Moderation history
  - [ ] Statistics dashboard
- [ ] Create `ModerationService`:
  - [ ] `reviewReport()` - Review and act on report
  - [ ] `deleteContent()` - Delete reported content
  - [ ] `warnUser()` - Send warning to user
  - [ ] `banUser()` - Ban user (temporary/permanent)
  - [ ] `notifyUser()` - Notify user of action taken
- [ ] Add moderation permissions:
  - [ ] Check admin role in backend
  - [ ] Restrict access to dashboard
  - [ ] Log all moderation actions
- [ ] Cloud Functions for moderation:
  - [ ] Auto-flag suspicious content (optional AI)
  - [ ] Escalate high-priority reports
  - [ ] Send notifications to admins

---

### 🎓 Phase 6H: Feature Discovery & Onboarding System

#### 6H.1 Feature Discovery Infrastructure
- [ ] Create `FeatureGuideModel`:
  ```javascript
  {
    featureId: string, // 'create_post', 'boost_post', 'search', etc.
    featureName: string,
    category: string, // 'posting', 'discovery', 'engagement', 'monetization'
    description: string,
    icon: string,
    videoUrl: string, // Optional tutorial video
    screenshotUrls: string[],
    steps: [
      {
        title: string,
        description: string,
        action: string, // 'tap_button', 'swipe', 'long_press'
        target: string // Button/feature identifier
      }
    ],
    relatedFeatures: string[], // Other feature IDs
    difficulty: 'easy' | 'medium' | 'advanced',
    estimatedTime: number // Minutes
  }
  ```
- [ ] Create `FeatureGuideRepository`:
  - [ ] `getFeatureGuides()` - Get all guides
  - [ ] `getFeatureGuideById()` - Get specific guide
  - [ ] `getGuidesByCategory()` - Get guides by category
  - [ ] `markGuideCompleted()` - Mark guide as done
  - [ ] `getUserProgress()` - Get user's progress

#### 6H.2 Feature Discovery UI - Hub
- [ ] Create `FeatureDiscoveryScreen` (Main Hub):
  - [ ] Accessible from menu/settings
  - [ ] Categories tabs:
    - [ ] 📝 Posting (Create, Edit, Templates, Location)
    - [ ] 🔍 Discovery (Search, Explore, Hashtags)
    - [ ] ❤️ Engagement (Likes, Comments, Share)
    - [ ] 🚀 Growth (Boost, Analytics, Pages)
    - [ ] ⚙️ Management (Pin, Archive, Drafts)
  - [ ] Feature cards grid:
    - [ ] Feature icon
    - [ ] Feature name
    - [ ] Brief description
    - [ ] Difficulty badge
    - [ ] Time estimate
    - [ ] Completion indicator
  - [ ] Search feature guides
  - [ ] Filter by completion status

#### 6H.3 Feature Guide Detail View
- [ ] Create `FeatureGuideDetailScreen`:
  - [ ] Feature header (icon, name)
  - [ ] Description section
  - [ ] Step-by-step guide:
    - [ ] Numbered steps
    - [ ] Visual indicators
    - [ ] Screenshots/images per step
    - [ ] Action buttons (if interactive)
  - [ ] Video tutorial (if available)
  - [ ] "Try It Now" button (deep link to feature)
  - [ ] "Mark as Completed" button
  - [ ] Related features section
  - [ ] Progress indicator

#### 6H.4 Interactive Tutorial System
- [ ] Create `FeatureTutorialOverlay`:
  - [ ] Highlight target element
  - [ ] Tooltip with instructions
  - [ ] Animated pointer/arrow
  - [ ] Next/Previous buttons
  - [ ] Skip button
  - [ ] Progress indicator
- [ ] Integrate with existing `GuidedOverlay` (if available)
- [ ] Support multiple overlay types:
  - [ ] Point to button/element
  - [ ] Highlight area
  - [ ] Show gesture (swipe, long-press)
  - [ ] Animated sequence

#### 6H.5 Contextual Help & Tooltips
- [ ] Create `ContextualHelpService`:
  - [ ] Show help icon on new features
  - [ ] Tooltip on first use
  - [ ] "What's this?" button on complex features
  - [ ] Quick help cards
- [ ] Add help indicators:
  - [ ] Badge on new features
  - [ ] "New" label for recent features
  - [ ] Pulsing animation to draw attention
- [ ] Context-aware help:
  - [ ] Show relevant guide based on screen
  - [ ] Suggest guides for unused features
  - [ ] Adaptive help based on user behavior

#### 6H.6 Quick Access Methods
- [ ] Feature discovery entry points:
  - [ ] Menu item: "How to use features"
  - [ ] Settings → "Feature Guides"
  - [ ] Help button in app bar (question mark icon)
  - [ ] Long-press on feature → "Learn how to use"
  - [ ] "?" icon on complex screens
  - [ ] Onboarding flow integration
- [ ] Create `HelpCenter`:
  - [ ] FAQ section
  - [ ] Video tutorials library
  - [ ] Feature categories
  - [ ] Search help content
  - [ ] Contact support link

#### 6H.7 Feature Usage Tracking
- [ ] Track feature usage:
  - [ ] Mark features as "discovered" when used
  - [ ] Track feature usage frequency
  - [ ] Identify unused features
  - [ ] Suggest features based on behavior
- [ ] Analytics:
  - [ ] Most viewed guides
  - [ ] Most completed features
  - [ ] Drop-off points in tutorials
  - [ ] Feature adoption rates

#### 6H.8 Sample Feature Guides (Content)
- [ ] Create guides for all major features:
  - [ ] "How to Create Your First Post"
  - [ ] "How to Use Multi-Image Carousel"
  - [ ] "How to Add Location to Posts"
  - [ ] "How to Search for Content"
  - [ ] "How to Pin a Post"
  - [ ] "How to Edit a Post"
  - [ ] "How to Use Post Templates"
  - [ ] "How to Boost Your Post"
  - [ ] "How to Create a Page"
  - [ ] "How to Report Inappropriate Content"
  - [ ] And more...

#### 6H.9 Integration with Onboarding
- [ ] Add feature discovery to onboarding:
  - [ ] Show key features during onboarding
  - [ ] Interactive tutorials for essentials
  - [ ] "Explore More Features" at end
- [ ] Progressive disclosure:
  - [ ] Show basic features first
  - [ ] Unlock advanced features gradually
  - [ ] Celebrate feature discovery

---

### 📋 Phase 6D: Integration & Enhancement (Updated)

*Note: Original Phase 6 tasks, now renamed to 6D to accommodate new phases*

#### 6D.1 Hashtag System
- [ ] Implement `HashtagService`
- [ ] Create hashtag search/explore
- [ ] Create trending hashtags

#### 6D.2 Mention System
- [ ] Implement `MentionService`
- [ ] Create mention notifications
- [ ] Create mentioned posts view

#### 6D.3 Profile Integration
- [ ] Update `ProfileScreen` to show user's posts
- [ ] Add post count to profile
- [ ] Link from post author to profile
- [ ] Note: Adapt for friends system (not followers)

#### 6D.4 Notification Integration
- [ ] Update Cloud Functions for feed notifications
- [ ] Update `NotificationRepository`
- [ ] Update notification UI
- [ ] Note: Use "friend" terminology instead of "follower"

#### 6D.5 Friends Integration
- [ ] Ensure feed shows friends' posts
- [ ] Add "Friend Activity" section (optional)
- [ ] Friend suggestions based on feed engagement

#### 6D.6 Post Sharing
- [ ] Implement share functionality
- [ ] Add share button to `PostCard`
- [ ] Share to external platforms

#### 6D.7 Media Enhancements
- [ ] Image gallery viewer
- [ ] Video player (if adding video support)

---

### 📝 Additional Future Enhancements (Post-MVP)

#### V2 Features (Deferred - Some Now in Phase 6)
- [ ] Stories (ephemeral 24-hour content)
- [ ] Advanced comment threading (nested replies)
- [ ] Content-based ML recommendations
- [ ] Live reaction counts (real-time)
- [ ] Story reactions/comments
- [ ] Page analytics advanced features
- [ ] Boost campaign scheduling

#### V3 Features (Future)
- [ ] Reels (short-form video)
- [ ] Video editing tools
- [ ] Advanced filters and effects
- [ ] Group posts
- [ ] Polls in posts
- [ ] Scheduled posts

---

## Progress Tracking

**Total Tasks:** ~450+ individual tasks (includes all phases: ads, boost, pages, search, post management, moderation, and feature discovery)

**Estimated Completion Timeline:**
- Phase 0 (Setup): 2-3 days
- Phase 1 (Core Feed): 2-3 weeks
- Phase 2 (Reactions): 1 week
- Phase 3 (Comments): 1-2 weeks
- Phase 4 (Nearby Feed): 1 week
- Phase 5 (Trending): 1 week
- Phase 6A (Ads Integration): 1-2 weeks
- Phase 6B (Boost/Promote): 2-3 weeks
- Phase 6C (Pages & Admin): 2-3 weeks
- Phase 6D (Integration): 1-2 weeks
- Phase 6E (Search & Discovery): 1-2 weeks
- Phase 6F (Post Management): 1-2 weeks
- Phase 6G (Reporting & Moderation): 1-2 weeks
- Phase 6H (Feature Discovery): 1 week
- Phase 7 (Testing): 1-2 weeks
- Phase 8 (Deployment): 3-5 days

**Total Full Timeline: 18-22 weeks** (with buffer for unexpected issues)

**MVP Timeline (without ads/boost/pages): 8-10 weeks**
**Full Feature Timeline: 18-22 weeks** (includes all phases: search, post management, moderation, feature discovery)

---

## Conclusion

This comprehensive plan provides a complete blueprint for implementing a modern social feed ecosystem in your Flutter app. The architecture is designed to:

1. **Scale**: Uses Firestore subcollections, pagination, and efficient queries
2. **Perform**: Optimistic UI updates, real-time streams, local caching
3. **Engage**: Reactions, comments, trending, nearby discovery
4. **Monetize**: Native ads integration and boost/promote post system
5. **Expand**: Pages system with admin roles and verification
6. **Discover**: Comprehensive search system and feature discovery hub
7. **Manage**: Post editing, pinning, templates, multi-image carousel, location check-ins
8. **Moderate**: Reporting system and admin moderation dashboard
9. **Guide**: Feature discovery system with interactive tutorials and contextual help
10. **Extend**: Modular design allows easy addition of Stories, Reels in future phases

Start with Phase 1 (Core Feed) and iterate through each feature systematically. Each feature builds on the previous one, ensuring a stable foundation.

**Estimated Timeline:**
- Phase 1 (Core Feed): 2-3 weeks
- Phase 2 (Reactions): 1 week
- Phase 3 (Comments): 1-2 weeks
- Phase 4 (Nearby Feed): 1 week
- Phase 5 (Trending): 1 week

**Total MVP Timeline: 6-8 weeks** (depending on team size and existing infrastructure familiarity)

Good luck with your implementation!

