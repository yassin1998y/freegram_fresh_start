// lib/repositories/post_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/comment_model.dart';
import 'package:freegram/models/boost_package_model.dart';
import 'package:freegram/models/page_model.dart';
import 'package:freegram/utils/enums.dart';
import 'package:freegram/services/hashtag_service.dart';
import 'package:freegram/services/mention_service.dart';
import 'package:freegram/models/media_item_model.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/achievement_repository.dart';

/// Cache entry for feed results
class _CachedFeedResult {
  final List<PostModel> posts;
  final DocumentSnapshot? lastDocument;
  final DateTime timestamp;

  _CachedFeedResult({
    required this.posts,
    required this.lastDocument,
    required this.timestamp,
  });
}

class PostRepository {
  final FirebaseFirestore _db;
  final HashtagService _hashtagService;
  final MentionService _mentionService;

  // Request deduplication: Track ongoing requests by cache key
  final Map<String, Future<(List<PostModel>, DocumentSnapshot?)>>
      _currentRequests = {};

  // Page cache: In-memory cache for paginated results
  final Map<String, List<PostModel>> _pageCache = {};

  // Short-term cache: Cache feed results for 5 minutes to reduce Firestore reads
  final Map<String, _CachedFeedResult> _feedCache = {};
  static const Duration _feedCacheTTL = Duration(minutes: 5);

  PostRepository({
    FirebaseFirestore? firestore,
    HashtagService? hashtagService,
    MentionService? mentionService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _hashtagService = hashtagService ?? locator<HashtagService>(),
        _mentionService = mentionService ?? locator<MentionService>();

  /// Generate a cache key for a feed request
  String _generateCacheKey({
    required String userId,
    required TimeFilter timeFilter,
    DocumentSnapshot? lastDocument,
    Map<String, dynamic>? userTargeting,
  }) {
    // Create a unique key based on request parameters
    final docId = lastDocument?.id ?? 'first';
    final targetingHash = userTargeting?.toString() ?? '';
    return 'feed_${userId}_${timeFilter.name}_$docId$targetingHash';
  }

  /// Clear the page cache (called on "Pull to Refresh")
  void clearPageCache() {
    _pageCache.clear();
    _feedCache.clear(); // Also clear feed cache on refresh
    debugPrint('PostRepository: Page cache and feed cache cleared');
  }

  /// Get feed for current user (friends + public posts + followed pages)
  /// Returns a tuple: (posts, lastDocument)
  ///
  /// CRITICAL: This method queries posts from three sources:
  /// 1. Posts from friends (authorId in friends list)
  /// 2. Public posts (visibility == 'public')
  /// 3. Posts from followed pages (pageId in followedPages list)
  ///
  /// Since Firestore doesn't support logical OR on different fields,
  /// we execute two separate queries and merge the results.
  ///
  /// OPTIMIZATION: Uses short-term caching (5 minutes) to reduce Firestore reads.
  /// Cache is bypassed on pull-to-refresh or if lastDocument is provided (pagination).
  Future<(List<PostModel>, DocumentSnapshot?)> getFeedForUserWithPagination({
    required String userId,
    DocumentSnapshot? lastDocument,
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache first (only for first page, not pagination)
      if (!forceRefresh && lastDocument == null) {
        final cacheKey = 'feed_$userId';
        final cached = _feedCache[cacheKey];
        if (cached != null &&
            DateTime.now().difference(cached.timestamp) < _feedCacheTTL) {
          debugPrint('PostRepository: Returning cached feed for $userId');
          return (cached.posts, cached.lastDocument);
        }
      }

      // Get user's friends list AND followed pages
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('PostRepository: User not found: $userId');
        return (<PostModel>[], null);
      }

      final userData = userDoc.data() ?? {};
      final friends = List<String>.from(userData['friends'] ?? []);
      final followedPages = List<String>.from(userData['followedPages'] ?? []);

      // Query 1: Posts from friends OR public posts
      Query query1;
      if (friends.isNotEmpty) {
        query1 = _db
            .collection('posts')
            .where('deleted', isEqualTo: false)
            .where(Filter.or(
              Filter('authorId', whereIn: friends),
              Filter('visibility', isEqualTo: 'public'),
            ));
      } else {
        query1 = _db
            .collection('posts')
            .where('deleted', isEqualTo: false)
            .where('visibility', isEqualTo: 'public');
      }
      query1 = query1.orderBy('timestamp', descending: true).limit(limit);

      // Pagination for query1
      if (lastDocument != null) {
        query1 = query1.startAfterDocument(lastDocument);
      }

      // Execute query1
      final snapshot1 = await query1.get();
      // CRITICAL: Filter out current user's posts to prevent duplicates with getUserPosts
      final friendPosts = snapshot1.docs
          .map((doc) => PostModel.fromDoc(doc))
          .where(
              (post) => post.authorId != userId) // Exclude current user's posts
          .toList();

      // Query 2: Posts from followed pages (if any)
      List<PostModel> pagePosts = [];
      if (followedPages.isNotEmpty) {
        // Firestore 'whereIn' limit is 10, so batch if needed
        for (int i = 0; i < followedPages.length; i += 10) {
          final batch = followedPages.sublist(
            i,
            i + 10 > followedPages.length ? followedPages.length : i + 10,
          );

          var pageQuery = _db
              .collection('posts')
              .where('deleted', isEqualTo: false)
              .where('pageId', whereIn: batch)
              .orderBy('timestamp', descending: true)
              .limit(limit);

          // Note: Pagination for pageQuery is complex with batching,
          // so we'll fetch all and sort/limit client-side for simplicity
          final pageSnapshot = await pageQuery.get();
          pagePosts.addAll(
            pageSnapshot.docs.map((doc) => PostModel.fromDoc(doc)).toList(),
          );
        }
      }

      // Merge and deduplicate results
      final allPosts = <PostModel>[];
      final seenIds = <String>{};

      // Add friend/public posts first
      for (final post in friendPosts) {
        if (!seenIds.contains(post.id)) {
          allPosts.add(post);
          seenIds.add(post.id);
        }
      }

      // Add page posts
      for (final post in pagePosts) {
        if (!seenIds.contains(post.id)) {
          allPosts.add(post);
          seenIds.add(post.id);
        }
      }

      // Sort by timestamp (newest first)
      allPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Apply pagination limit
      final limitedPosts = allPosts.take(limit).toList();

      // Get last document for pagination
      DocumentSnapshot? lastDoc;
      if (limitedPosts.isNotEmpty && snapshot1.docs.isNotEmpty) {
        // Use the last document from query1 for pagination
        lastDoc = snapshot1.docs.last;
      }

      // Cache the result (only for first page)
      if (lastDocument == null) {
        final cacheKey = 'feed_$userId';
        _feedCache[cacheKey] = _CachedFeedResult(
          posts: limitedPosts,
          lastDocument: lastDoc,
          timestamp: DateTime.now(),
        );
        debugPrint('PostRepository: Cached feed for $userId');
      }

      debugPrint(
        'PostRepository: Feed fetched ${limitedPosts.length} posts '
        '(${friendPosts.length} from friends/public, ${pagePosts.length} from pages)',
      );

      return (limitedPosts, lastDoc);
    } catch (e) {
      debugPrint('PostRepository: Error getting feed for user: $e');
      rethrow;
    }
  }

  /// Get feed for current user (friends + public posts + followed pages)
  /// Legacy method - delegates to getFeedForUserWithPagination
  Future<List<PostModel>> getFeedForUser({
    required String userId,
    DocumentSnapshot? lastDocument,
    int limit = 10,
  }) async {
    try {
      final result = await getFeedForUserWithPagination(
        userId: userId,
        lastDocument: lastDocument,
        limit: limit,
      );
      return result.$1;
    } catch (e) {
      debugPrint('PostRepository: Error getting feed for user: $e');
      rethrow;
    }
  }

  /// Get trending posts with optional time filter
  Future<List<PostModel>> getTrendingPosts({
    required TimeFilter timeFilter,
    DocumentSnapshot? lastDocument,
    int limit = 10,
  }) async {
    try {
      final now = DateTime.now();
      var query = _db
          .collection('posts')
          .where('deleted', isEqualTo: false)
          .where('visibility', isEqualTo: 'public');

      // Apply time filter based on TimeFilter enum
      switch (timeFilter) {
        case TimeFilter.today:
          final yesterday = now.subtract(const Duration(days: 1));
          query = query.where('timestamp',
              isGreaterThan: Timestamp.fromDate(yesterday));
          break;
        case TimeFilter.thisWeek:
          final weekAgo = now.subtract(const Duration(days: 7));
          query = query.where('timestamp',
              isGreaterThan: Timestamp.fromDate(weekAgo));
          break;
        case TimeFilter.allTime:
          // No time filter for allTime
          break;
      }

      query = query
          .orderBy('trendingScore', descending: true)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => PostModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('PostRepository: Error getting trending posts: $e');
      rethrow;
    }
  }

  /// Get global trending posts (for new users)
  /// Fetches high-engagement posts from the last 24 hours
  Future<List<PostModel>> getGlobalTrendingPosts({int limit = 20}) async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));

      // Query posts from last 24h, ordered by reaction count
      // Note: Requires composite index on [deleted, visibility, timestamp, reactionCount]
      final query = _db
          .collection('posts')
          .where('deleted', isEqualTo: false)
          .where('visibility', isEqualTo: 'public')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .orderBy('timestamp', descending: true)
          .orderBy('reactionCount', descending: true)
          .limit(limit);

      final snapshot = await query.get();

      // If not enough recent posts, fall back to all-time trending
      if (snapshot.docs.length < 5) {
        return getTrendingPosts(timeFilter: TimeFilter.thisWeek, limit: limit);
      }

      return snapshot.docs.map((doc) => PostModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('PostRepository: Error getting global trending posts: $e');
      // Fallback to simple trending query on error (likely index missing)
      try {
        return getTrendingPosts(timeFilter: TimeFilter.allTime, limit: limit);
      } catch (fallbackError) {
        debugPrint('PostRepository: Fallback failed: $fallbackError');
        return [];
      }
    }
  }

  /// Get trending hashtags from top trending posts
  Future<List<String>> getTrendingHashtags() async {
    try {
      // Query top 50 trending posts to extract hashtags
      final snapshot = await _db
          .collection('posts')
          .where('deleted', isEqualTo: false)
          .where('visibility', isEqualTo: 'public')
          .orderBy('trendingScore', descending: true)
          .limit(50)
          .get();

      // Aggregate hashtags from all posts
      final hashtagCount = <String, int>{};

      for (final doc in snapshot.docs) {
        final post = PostModel.fromDoc(doc);
        for (final hashtag in post.hashtags) {
          final normalizedHashtag = hashtag.toLowerCase().trim();
          if (normalizedHashtag.isNotEmpty) {
            hashtagCount[normalizedHashtag] =
                (hashtagCount[normalizedHashtag] ?? 0) + 1;
          }
        }
      }

      // Sort by count and return top 5-10 unique hashtags
      final sortedHashtags = hashtagCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Return top 10 unique hashtags (with # prefix)
      return sortedHashtags
          .take(10)
          .map((entry) =>
              entry.key.startsWith('#') ? entry.key : '#${entry.key}')
          .toList();
    } catch (e) {
      debugPrint('PostRepository: Error getting trending hashtags: $e');
      return [];
    }
  }

  /// Get a single post by ID
  Future<PostModel?> getPostById(String postId) async {
    try {
      final doc = await _db.collection('posts').doc(postId).get();
      if (!doc.exists) {
        return null;
      }
      return PostModel.fromDoc(doc);
    } catch (e) {
      debugPrint('PostRepository: Error getting post by ID: $e');
      rethrow;
    }
  }

  /// Get all posts by a specific user (for profile screen)
  Future<List<PostModel>> getUserPosts({
    required String userId,
    DocumentSnapshot? lastDocument,
    int limit = 10,
  }) async {
    try {
      var query = _db
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .where('deleted', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => PostModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('PostRepository: Error getting user posts: $e');
      rethrow;
    }
  }

  /// Create a new post
  Future<String> createPost({
    required String userId,
    required String content,
    List<MediaItem>? mediaItems,
    @Deprecated('Use mediaItems instead') List<String>? mediaUrls,
    @Deprecated('Use mediaItems instead') List<String>? mediaTypes,
    GeoPoint? location,
    String? locationAddress,
    Map<String, dynamic>? locationInfo,
    String visibility = 'public',
    String? pageId,
  }) async {
    try {
      // Get user info
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found: $userId');
      }

      final userData = userDoc.data() ?? {};
      String authorUsername = userData['username'] ?? 'Anonymous';
      String authorPhotoUrl = userData['photoUrl'] ?? '';

      // If posting as page, get page info and validate permissions
      String? pageName;
      String? pagePhotoUrl;
      bool pageIsVerified = false;

      if (pageId != null) {
        final pageDoc = await _db.collection('pages').doc(pageId).get();
        if (!pageDoc.exists) {
          throw Exception('Page not found: $pageId');
        }

        final pageData = pageDoc.data() ?? {};
        final page = PageModel.fromDoc(pageDoc);

        // Verify user has permission to post as this page
        if (!page.isAdmin(userId)) {
          throw Exception('You do not have permission to post as this page');
        }

        // Denormalize page info including verification status
        pageName = pageData['pageName'] ?? '';
        pagePhotoUrl = pageData['profileImageUrl'] ?? '';
        pageIsVerified = page.verificationStatus == VerificationStatus.verified;
      }

      // Extract and normalize hashtags (without # symbol, lowercase)
      final hashtags = _hashtagService.extractHashtags(content);

      // Extract mentions and validate users (store userIds, not usernames)
      final mentionUsernames = _mentionService.extractMentions(content);
      final validMentions =
          await _mentionService.validateMentions(mentionUsernames);
      final mentionUserIds = validMentions.values.toList();

      // Update hashtag usage counts (for trending)
      if (hashtags.isNotEmpty) {
        _hashtagService.updateHashtagUsage(hashtags).catchError((e) {
          debugPrint('PostRepository: Error updating hashtag usage: $e');
        });
      }

      // Convert mediaItems or legacy mediaUrls/mediaTypes to MediaItem list
      List<MediaItem> finalMediaItems = [];
      if (mediaItems != null && mediaItems.isNotEmpty) {
        finalMediaItems = mediaItems;
        // Debug log each MediaItem received
        for (int i = 0; i < finalMediaItems.length; i++) {
          debugPrint(
              'PostRepository: Received MediaItem[$i]: ${finalMediaItems[i].toMap()}');
        }
      } else if (mediaUrls != null && mediaUrls.isNotEmpty) {
        // Convert legacy format to MediaItem
        final types = mediaTypes ?? [];
        for (int i = 0; i < mediaUrls.length; i++) {
          finalMediaItems.add(MediaItem(
            url: mediaUrls[i],
            type: i < types.length ? types[i] : 'image',
          ));
        }
      }

      // Determine post type
      final mediaTypesList = finalMediaItems.map((item) => item.type).toList();
      final postType = PostModel.determinePostType(mediaTypesList);

      final postRef = _db.collection('posts').doc();
      final now = FieldValue.serverTimestamp();

      // Prepare mediaItems for Firestore
      final mediaItemsForFirestore =
          finalMediaItems.map((item) => item.toMap()).toList();

      // Validate that all mediaItems have non-empty URLs
      for (int i = 0; i < mediaItemsForFirestore.length; i++) {
        final itemMap = mediaItemsForFirestore[i];
        if (itemMap['url'] == null || (itemMap['url'] as String).isEmpty) {
          debugPrint(
              'PostRepository: WARNING - mediaItems[$i] has empty url! Item: $itemMap');
          // Try to use video quality URLs as fallback
          final videoUrl = itemMap['videoUrl1080p'] ??
              itemMap['videoUrl720p'] ??
              itemMap['videoUrl360p'];
          if (videoUrl != null && (videoUrl as String).isNotEmpty) {
            debugPrint(
                'PostRepository: Using video quality URL as fallback for mediaItems[$i]: $videoUrl');
            itemMap['url'] = videoUrl;
          }
        }
      }

      // Debug log what's being saved to Firestore
      debugPrint(
          'PostRepository: Saving ${finalMediaItems.length} mediaItems to Firestore');
      for (int i = 0; i < mediaItemsForFirestore.length; i++) {
        debugPrint(
            'PostRepository: mediaItems[$i] to save: ${mediaItemsForFirestore[i]}');
      }

      await postRef.set({
        'postId': postRef.id,
        'authorId': userId,
        'authorUsername': authorUsername,
        'authorPhotoUrl': authorPhotoUrl,
        'pageId': pageId,
        'pageName': pageName,
        'pagePhotoUrl': pagePhotoUrl,
        'pageIsVerified': pageIsVerified,
        'content': content,
        'mediaItems': mediaItemsForFirestore,
        // Legacy fields for backward compatibility
        'mediaUrls': finalMediaItems.map((item) => item.url).toList(),
        'mediaTypes': mediaTypesList,
        'postType': postType.toString().split('.').last,
        'timestamp': now,
        'location': location != null
            ? {
                'latitude': location.latitude,
                'longitude': location.longitude,
                'address': locationAddress,
              }
            : null,
        'locationInfo': locationInfo,
        'hashtags': hashtags,
        'mentions': mentionUserIds, // Store userIds, not usernames
        'visibility': visibility,
        'reactionCount': 0,
        'commentCount': 0,
        'viewCount': 0,
        'trendingScore': 0.0,
        'lastEngagementTimestamp': now,
        'deleted': false,
        'createdAt': now,
        'updatedAt': now,
      });

      // TRIGGER ACHIEVEMENT: First Post
      try {
        locator<AchievementRepository>()
            .updateProgress(userId, 'content_first_post', 1);
      } catch (e) {
        debugPrint('PostRepository: Error updating achievement: $e');
      }

      return postRef.id;
    } catch (e) {
      debugPrint('PostRepository: Error creating post: $e');
      rethrow;
    }
  }

  /// Update an existing post (for editing)
  Future<void> updatePost({
    required String postId,
    required String userId,
    String? content,
    List<String>? mediaUrls,
    List<String>? mediaTypes,
    GeoPoint? location,
    String? visibility,
  }) async {
    try {
      // Verify ownership
      final postDoc = await _db.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found: $postId');
      }

      final postData = postDoc.data() ?? {};
      if (postData['authorId'] != userId) {
        throw Exception('User is not the author of this post');
      }

      // Build update map
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (content != null) {
        updateData['content'] = content;
        // Re-extract and normalize hashtags and mentions if content changed
        final hashtags = _hashtagService.extractHashtags(content);
        final mentionUsernames = _mentionService.extractMentions(content);
        final validMentions =
            await _mentionService.validateMentions(mentionUsernames);
        updateData['hashtags'] = hashtags;
        updateData['mentions'] = validMentions.values.toList();

        // Update hashtag usage counts
        if (hashtags.isNotEmpty) {
          _hashtagService.updateHashtagUsage(hashtags).catchError((e) {
            debugPrint('PostRepository: Error updating hashtag usage: $e');
          });
        }
      }

      if (mediaUrls != null) {
        updateData['mediaUrls'] = mediaUrls;
      }

      if (mediaTypes != null) {
        updateData['mediaTypes'] = mediaTypes;
        updateData['postType'] =
            PostModel.determinePostType(mediaTypes).toString().split('.').last;
      }

      if (location != null) {
        updateData['location'] = {
          'latitude': location.latitude,
          'longitude': location.longitude,
        };
      }

      if (visibility != null) {
        updateData['visibility'] = visibility;
      }

      await _db.collection('posts').doc(postId).update(updateData);
    } catch (e) {
      debugPrint('PostRepository: Error updating post: $e');
      rethrow;
    }
  }

  /// Edit post content
  /// Updates the post content and sets edited flag
  Future<void> editPost(String postId, String userId, String newContent) async {
    try {
      // Verify ownership
      final postDoc = await _db.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found: $postId');
      }

      final postData = postDoc.data() ?? {};
      if (postData['authorId'] != userId) {
        throw Exception('User is not the author of this post');
      }

      // Re-extract and normalize hashtags and mentions from new content
      final hashtags = _hashtagService.extractHashtags(newContent);
      final mentionUsernames = _mentionService.extractMentions(newContent);
      final validMentions =
          await _mentionService.validateMentions(mentionUsernames);

      // Update hashtag usage counts
      if (hashtags.isNotEmpty) {
        _hashtagService.updateHashtagUsage(hashtags).catchError((e) {
          debugPrint('PostRepository: Error updating hashtag usage: $e');
        });
      }

      // Build update map
      await _db.collection('posts').doc(postId).update({
        'content': newContent,
        'hashtags': hashtags,
        'mentions': validMentions.values.toList(),
        'edited': true,
        'editedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PostRepository: Error editing post: $e');
      rethrow;
    }
  }

  /// Pin a post
  Future<void> pinPost(String postId, String userId) async {
    try {
      // Verify ownership
      final postDoc = await _db.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found: $postId');
      }

      final postData = postDoc.data() ?? {};
      if (postData['authorId'] != userId) {
        throw Exception('User is not the author of this post');
      }

      await _db.collection('posts').doc(postId).update({
        'isPinned': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PostRepository: Error pinning post: $e');
      rethrow;
    }
  }

  /// Unpin a post
  Future<void> unpinPost(String postId, String userId) async {
    try {
      // Verify ownership
      final postDoc = await _db.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found: $postId');
      }

      final postData = postDoc.data() ?? {};
      if (postData['authorId'] != userId) {
        throw Exception('User is not the author of this post');
      }

      await _db.collection('posts').doc(postId).update({
        'isPinned': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PostRepository: Error unpinning post: $e');
      rethrow;
    }
  }

  /// Get pinned posts for a user
  Future<List<PostModel>> getPinnedPosts(String userId,
      {int limit = 20}) async {
    try {
      final snapshot = await _db
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .where('isPinned', isEqualTo: true)
          .where('deleted', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => PostModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('PostRepository: Error getting pinned posts: $e');
      return [];
    }
  }

  /// Soft delete a post
  Future<void> deletePost(String postId, String userId) async {
    try {
      // Verify ownership
      final postDoc = await _db.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post not found: $postId');
      }

      final postData = postDoc.data() ?? {};
      if (postData['authorId'] != userId) {
        throw Exception('User is not the author of this post');
      }

      await _db.collection('posts').doc(postId).update({
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PostRepository: Error deleting post: $e');
      rethrow;
    }
  }

  /// Get real-time stream of feed for user (friends + public + followed pages)
  Stream<List<PostModel>> getFeedStream(String userId) {
    try {
      return _db
          .collection('posts')
          .where('deleted', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(30) // OPTIMIZED: Reduced from 50 to 30 to reduce reads
          .snapshots()
          .asyncMap((snapshot) async {
        // Get user's friends list AND followed pages
        final userDoc = await _db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
          return <PostModel>[];
        }

        final userData = userDoc.data() ?? {};
        final friends = List<String>.from(userData['friends'] ?? []);
        final followedPages =
            List<String>.from(userData['followedPages'] ?? []);

        // Filter posts: friends OR public OR from followed pages
        final posts =
            snapshot.docs.map((doc) => PostModel.fromDoc(doc)).where((post) {
          // Check if post is from a friend
          final isFromFriend =
              friends.isNotEmpty && friends.contains(post.authorId);

          // Check if post is public
          final isPublic = post.visibility == 'public';

          // Check if post is from a followed page
          final isFromFollowedPage = post.pageId != null &&
              followedPages.isNotEmpty &&
              followedPages.contains(post.pageId);

          return isPublic || isFromFriend || isFromFollowedPage;
        }).toList();

        return posts;
      });
    } catch (e) {
      debugPrint('PostRepository: Error getting feed stream: $e');
      return Stream.value([]);
    }
  }

  /// Like post (add reaction) - Uses batch for atomic operations
  Future<void> likePost(String postId, String userId) async {
    try {
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
    } catch (e) {
      debugPrint('PostRepository: Error liking post: $e');
      rethrow;
    }
  }

  /// Unlike post (remove reaction) - Uses batch for atomic operations
  Future<void> unlikePost(String postId, String userId) async {
    try {
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
    } catch (e) {
      debugPrint('PostRepository: Error unliking post: $e');
      rethrow;
    }
  }

  /// Check if user has liked the post
  Future<bool> hasUserLiked(String postId, String userId) async {
    try {
      final doc = await _db
          .collection('posts')
          .doc(postId)
          .collection('reactions')
          .doc(userId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('PostRepository: Error checking if user liked: $e');
      return false;
    }
  }

  /// Get users who liked the post (with pagination) - Optional for showing "liked by" list
  Future<List<String>> getLikedByUsers(
    String postId, {
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    try {
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
      return snapshot.docs
          .map((doc) => doc.id)
          .toList(); // doc.id is the userId
    } catch (e) {
      debugPrint('PostRepository: Error getting liked by users: $e');
      return [];
    }
  }

  /// Legacy method - kept for backward compatibility, now uses likePost/unlikePost
  @Deprecated('Use likePost/unlikePost instead')
  Future<void> toggleReaction({
    required String postId,
    required String userId,
  }) async {
    try {
      final hasLiked = await hasUserLiked(postId, userId);
      if (hasLiked) {
        await unlikePost(postId, userId);
      } else {
        await likePost(postId, userId);
      }
    } catch (e) {
      debugPrint('PostRepository: Error toggling reaction: $e');
      rethrow;
    }
  }

  /// Legacy method - kept for backward compatibility
  @Deprecated('Use hasUserLiked instead')
  Future<bool> hasUserReacted(String postId, String userId) async {
    return hasUserLiked(postId, userId);
  }

  /// Add a comment to a post - Uses batch for atomic operations
  Future<String> addComment(
    String postId,
    String userId,
    String text,
  ) async {
    try {
      final batch = _db.batch();

      // Get user info for denormalization
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found: $userId');
      }

      final userData = userDoc.data() ?? {};
      final username = userData['username'] ?? 'Anonymous';
      final photoUrl = userData['photoUrl'] ?? '';

      // Create comment
      final commentRef =
          _db.collection('posts').doc(postId).collection('comments').doc();

      batch.set(commentRef, {
        'commentId': commentRef.id,
        'postId': postId,
        'userId': userId,
        'username': username,
        'photoUrl': photoUrl,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'edited': false,
        'editedAt': null,
        'reactions': {},
        'deleted': false,
      });

      // Update post comment count (atomic increment)
      final postRef = _db.collection('posts').doc(postId);
      batch.update(postRef, {
        'commentCount': FieldValue.increment(1),
        'lastEngagementTimestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return commentRef.id;
    } catch (e) {
      debugPrint('PostRepository: Error adding comment: $e');
      rethrow;
    }
  }

  /// Get comments for a post with pagination
  Future<List<CommentModel>> getComments(
    String postId, {
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    try {
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
    } catch (e) {
      debugPrint('PostRepository: Error getting comments: $e');
      rethrow;
    }
  }

  /// Edit comment
  Future<void> editComment(
    String postId,
    String commentId,
    String newText,
  ) async {
    try {
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
    } catch (e) {
      debugPrint('PostRepository: Error editing comment: $e');
      rethrow;
    }
  }

  /// Delete comment (soft delete) - Uses batch for atomic operations
  Future<void> deleteComment(String postId, String commentId) async {
    try {
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
    } catch (e) {
      debugPrint('PostRepository: Error deleting comment: $e');
      rethrow;
    }
  }

  /// Like comment (optional feature) - Updates reactions map
  Future<void> likeComment(
    String postId,
    String commentId,
    String userId,
  ) async {
    try {
      final commentRef = _db
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      // Get current reactions map
      final commentDoc = await commentRef.get();
      final reactions = Map<String, String>.from(
          commentDoc.data()?['reactions'] ?? <String, String>{});

      // Add user reaction (using 'heart' as reaction type)
      reactions[userId] = 'heart';

      await commentRef.update({
        'reactions': reactions,
      });
    } catch (e) {
      debugPrint('PostRepository: Error liking comment: $e');
      rethrow;
    }
  }

  /// Unlike comment - Removes user from reactions map
  Future<void> unlikeComment(
    String postId,
    String commentId,
    String userId,
  ) async {
    try {
      final commentRef = _db
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      // Get current reactions map
      final commentDoc = await commentRef.get();
      final reactions = Map<String, String>.from(
          commentDoc.data()?['reactions'] ?? <String, String>{});

      // Remove user reaction
      reactions.remove(userId);

      await commentRef.update({
        'reactions': reactions,
      });
    } catch (e) {
      debugPrint('PostRepository: Error unliking comment: $e');
      rethrow;
    }
  }

  /// Get stream of comments for a post (real-time)
  Stream<List<CommentModel>> getCommentsStream(String postId) {
    try {
      return _db
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .where('deleted', isEqualTo: false)
          .orderBy('timestamp', descending: false)
          .limit(30) // OPTIMIZED: Reduced from 50 to 30 to reduce reads
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => CommentModel.fromDoc(doc)).toList());
    } catch (e) {
      debugPrint('PostRepository: Error getting comments stream: $e');
      return Stream.value([]);
    }
  }

  /// Boost a post with a boost package
  /// Atomically deducts coins and activates boost in a single transaction
  Future<void> boostPost({
    required String postId,
    required String userId,
    required BoostPackageModel boostPackage,
    required Map<String, dynamic> targetingData,
  }) async {
    final userRef = _db.collection('users').doc(userId);
    final postRef = _db.collection('posts').doc(postId);

    try {
      return await _db.runTransaction((transaction) async {
        // 1. Get user and post documents
        final userDoc = await transaction.get(userRef);
        final postDoc = await transaction.get(postRef);

        if (!userDoc.exists) {
          throw Exception('User not found: $userId');
        }
        if (!postDoc.exists) {
          throw Exception('Post not found: $postId');
        }

        final userData = userDoc.data() ?? {};
        final postData = postDoc.data() ?? {};

        // 2. Verify ownership
        if (postData['authorId'] != userId) {
          throw Exception('User is not the author of this post');
        }

        // 3. Check coin balance
        final currentCoins = (userData['coins'] ?? 0) as int;
        if (currentCoins < boostPackage.price) {
          throw Exception(
            'Insufficient coins. Required: ${boostPackage.price}, Available: $currentCoins',
          );
        }

        // 4. Calculate boost end time
        final now = DateTime.now();
        final boostEndTime = now.add(Duration(days: boostPackage.duration));

        // 5. Initialize boost stats if not exists
        final currentBoostStats =
            postData['boostStats'] as Map<String, dynamic>?;
        final boostStats = currentBoostStats ??
            {
              'impressions': 0,
              'clicks': 0,
              'reach': 0,
              'engagement': 0,
            };

        // 6. Atomic updates: Deduct coins and activate boost
        transaction.update(userRef, {
          'coins': FieldValue.increment(-boostPackage.price),
        });

        transaction.update(postRef, {
          'isBoosted': true,
          'boostEndTime': Timestamp.fromDate(boostEndTime),
          'boostTargeting': targetingData,
          'boostStats': boostStats,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('PostRepository: Error boosting post: $e');
      rethrow;
    }
  }

  /// Get boosted posts with targeting filters
  /// Returns posts that are currently boosted and match user targeting criteria
  /// P1 Improvement: Prioritizes posts with better engagement metrics
  Future<List<PostModel>> getBoostedPosts({
    required Map<String, dynamic>
        userTargeting, // user's location, age, gender, interests
    DocumentSnapshot? lastDocument,
    int limit = 10,
  }) async {
    try {
      final now = Timestamp.now();

      // Fetch more posts than needed so we can sort by engagement and pick the best
      // This allows us to prioritize posts with better engagement rates
      final fetchLimit = limit * 2; // Fetch 2x to have options for sorting

      var query = _db
          .collection('posts')
          .where('isBoosted', isEqualTo: true)
          .where('deleted', isEqualTo: false)
          .where('visibility', isEqualTo: 'public')
          .where('boostEndTime', isGreaterThan: now)
          .orderBy('boostEndTime', descending: true)
          .orderBy('timestamp', descending: true)
          .limit(fetchLimit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      var allPosts =
          snapshot.docs.map((doc) => PostModel.fromDoc(doc)).toList();

      // Client-side targeting filter
      allPosts = _filterByTargeting(allPosts, userTargeting);

      // P1 Improvement: Sort by engagement score (prioritize better performing posts)
      // Score = (trendingScore * 0.4) + (engagementRate * 0.4) + (recencyBonus * 0.2)
      allPosts.sort((a, b) {
        final scoreA = _calculateBoostScore(a);
        final scoreB = _calculateBoostScore(b);
        return scoreB.compareTo(scoreA); // Descending order
      });

      // Return top N posts after sorting
      return allPosts.take(limit).toList();
    } catch (e) {
      debugPrint('PostRepository: Error getting boosted posts: $e');
      rethrow;
    }
  }

  /// Calculate a composite score for boosted posts to prioritize better engagement
  /// Higher score = better post (should be shown first)
  double _calculateBoostScore(PostModel post) {
    // Component 1: Trending score (normalized to 0-1, assuming max trendingScore is ~200)
    final trendingScore = (post.trendingScore / 200.0).clamp(0.0, 1.0);

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
    // Posts ending in the next 24 hours get bonus
    final now = DateTime.now();
    double recencyBonus = 0.0;
    if (post.boostEndTime != null) {
      final endTime = post.boostEndTime!.toDate();
      final hoursRemaining = endTime.difference(now).inHours;
      if (hoursRemaining > 0 && hoursRemaining <= 24) {
        recencyBonus = (24 - hoursRemaining) /
            24.0; // Higher bonus for less time remaining
      }
    }

    // Weighted composite score
    // Trending: 40%, Engagement: 40%, Recency: 20%
    return (trendingScore * 0.4) +
        (engagementRate * 0.4) +
        (recencyBonus * 0.2);
  }

  /// Filter posts by targeting criteria (client-side filtering)
  List<PostModel> _filterByTargeting(
    List<PostModel> posts,
    Map<String, dynamic> userTargeting,
  ) {
    return posts.where((post) {
      final targeting = post.boostTargeting;
      if (targeting == null || targeting.isEmpty) {
        // No targeting = show to everyone
        return true;
      }

      // Location targeting
      if (targeting.containsKey('location')) {
        final targetLocation = targeting['location'] as Map<String, dynamic>?;
        if (targetLocation != null && userTargeting.containsKey('location')) {
          final userLocation =
              userTargeting['location'] as Map<String, dynamic>?;
          if (userLocation != null && targetLocation.containsKey('radiusKm')) {
            // For simplicity, we'll use post location if available
            // In production, calculate actual distance
            final radius = targetLocation['radiusKm'] as num?;
            if (radius != null && post.location == null) {
              return false; // Post requires location but doesn't have one
            }
          }
        }
      }

      // Age range targeting
      if (targeting.containsKey('ageRange')) {
        final ageRange = targeting['ageRange'] as Map<String, dynamic>?;
        if (ageRange != null && userTargeting.containsKey('age')) {
          final userAge = userTargeting['age'] as int?;
          if (userAge != null) {
            final minAge = ageRange['min'] as int?;
            final maxAge = ageRange['max'] as int?;
            if (minAge != null && userAge < minAge) return false;
            if (maxAge != null && userAge > maxAge) return false;
          }
        }
      }

      // Gender targeting
      if (targeting.containsKey('gender')) {
        final targetGender = targeting['gender'] as String?;
        if (targetGender != null && userTargeting.containsKey('gender')) {
          final userGender = userTargeting['gender'] as String?;
          if (userGender != null &&
              targetGender != 'all' &&
              targetGender != userGender) {
            return false;
          }
        }
      }

      // Interests targeting (if user has matching interests)
      if (targeting.containsKey('interests')) {
        final targetInterests = List<String>.from(targeting['interests'] ?? []);
        if (targetInterests.isNotEmpty &&
            userTargeting.containsKey('interests')) {
          final userInterests =
              List<String>.from(userTargeting['interests'] ?? []);
          final hasMatch = targetInterests
              .any((interest) => userInterests.contains(interest));
          if (!hasMatch) return false;
        }
      }

      return true;
    }).toList();
  }

  /// Track boost impression (increment impressions counter)
  Future<void> trackBoostImpression(String postId) async {
    try {
      await _db.collection('posts').doc(postId).update({
        'boostStats.impressions': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('PostRepository: Error tracking boost impression: $e');
      // Don't rethrow - impression tracking should be non-blocking
    }
  }

  /// Track boost click/interaction
  Future<void> trackBoostClick(String postId) async {
    try {
      await _db.collection('posts').doc(postId).update({
        'boostStats.clicks': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('PostRepository: Error tracking boost click: $e');
      // Don't rethrow - click tracking should be non-blocking
    }
  }

  /// Track boost reach (unique users who saw the post)
  Future<void> trackBoostReach(String postId, String userId) async {
    try {
      // Use a subcollection to track unique users
      final reachRef = _db
          .collection('posts')
          .doc(postId)
          .collection('boostReach')
          .doc(userId);

      final reachDoc = await reachRef.get();
      if (!reachDoc.exists) {
        // First time this user sees the boosted post
        await reachRef.set({
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Increment reach count
        await _db.collection('posts').doc(postId).update({
          'boostStats.reach': FieldValue.increment(1),
        });
      }
    } catch (e) {
      debugPrint('PostRepository: Error tracking boost reach: $e');
      // Don't rethrow - reach tracking should be non-blocking
    }
  }

  /// Unified Feed Method - Merges all post types into one deduplicated list
  /// This is the SINGLE SOURCE OF TRUTH for feed queries
  ///
  /// Features:
  /// - Request deduplication: Prevents fetching the same page twice
  /// - Page caching: In-memory cache to avoid redundant API calls
  /// - Cache cleared only on "Pull to Refresh"
  ///
  /// Fetches: trending, boosted, friends/public posts, user's own posts
  /// Returns: Deduplicated list of all posts (will be sorted by FeedScoringService)
  Future<(List<PostModel>, DocumentSnapshot?)> getUnifiedFeed({
    required String userId,
    GeoPoint? userLocation,
    TimeFilter timeFilter = TimeFilter.allTime,
    DocumentSnapshot? lastDocument,
    int limit = 20,
    Map<String, dynamic>? userTargeting,
    bool refresh = false, // Set to true on "Pull to Refresh"
  }) async {
    // Generate cache key for this request
    final cacheKey = _generateCacheKey(
      userId: userId,
      timeFilter: timeFilter,
      lastDocument: lastDocument,
      userTargeting: userTargeting,
    );

    // Clear cache if refreshing
    if (refresh) {
      clearPageCache();
      _currentRequests.clear();
    }

    // Check if there's an ongoing request for this exact page
    if (_currentRequests.containsKey(cacheKey)) {
      debugPrint(
          'PostRepository: Request deduplication - reusing existing request for $cacheKey');
      return _currentRequests[cacheKey]!;
    }

    // Check cache before hitting Firestore/API
    if (!refresh && _pageCache.containsKey(cacheKey)) {
      final cachedPosts = _pageCache[cacheKey]!;
      debugPrint(
          'PostRepository: Cache hit for $cacheKey (${cachedPosts.length} posts)');
      // Return cached data with a dummy lastDocument (pagination handled by caller)
      return (cachedPosts, lastDocument);
    }

    // Create the request future
    final requestFuture = _fetchUnifiedFeedInternal(
      userId: userId,
      userLocation: userLocation,
      timeFilter: timeFilter,
      lastDocument: lastDocument,
      limit: limit,
      userTargeting: userTargeting,
      cacheKey: cacheKey,
    );

    // Store the request to prevent duplicates
    _currentRequests[cacheKey] = requestFuture;

    try {
      final result = await requestFuture;
      return result;
    } finally {
      // Remove from ongoing requests once complete
      _currentRequests.remove(cacheKey);
    }
  }

  /// Internal method that performs the actual fetch
  Future<(List<PostModel>, DocumentSnapshot?)> _fetchUnifiedFeedInternal({
    required String userId,
    GeoPoint? userLocation,
    required TimeFilter timeFilter,
    DocumentSnapshot? lastDocument,
    required int limit,
    Map<String, dynamic>? userTargeting,
    required String cacheKey,
  }) async {
    try {
      // Build user targeting for boosted posts if not provided
      Map<String, dynamic> targeting = userTargeting ?? {};

      // Fetch ALL post types in parallel
      final results = await Future.wait([
        // Trending posts
        getTrendingPosts(
          timeFilter: timeFilter,
          lastDocument: lastDocument,
          limit: limit,
        ),
        // Boosted posts (with targeting)
        getBoostedPosts(
          userTargeting: targeting,
          limit: limit ~/ 2, // Fewer boosted posts
        ),
        // Friends + public posts (Following feed)
        getFeedForUserWithPagination(
          userId: userId,
          lastDocument: lastDocument,
          limit: limit,
        ),
        // User's own recent posts (to ensure they appear)
        getUserPosts(
          userId: userId,
          limit: 5, // Small limit for user's own posts
        ),
      ]);

      final trendingPosts = results[0] as List<PostModel>;
      final boostedPosts = results[1] as List<PostModel>;
      final followingResult =
          results[2] as (List<PostModel>, DocumentSnapshot?);
      final followingPosts = followingResult.$1;
      final lastDoc = followingResult.$2;
      final userOwnPosts = results[3] as List<PostModel>;

      // Merge and deduplicate by post ID
      final allPosts = <PostModel>[];
      final seenIds = <String>{};

      // Add user's own posts first (they get priority)
      for (final post in userOwnPosts) {
        if (!seenIds.contains(post.id)) {
          allPosts.add(post);
          seenIds.add(post.id);
        }
      }

      // Add boosted posts (high priority)
      for (final post in boostedPosts) {
        if (!seenIds.contains(post.id)) {
          allPosts.add(post);
          seenIds.add(post.id);
        }
      }

      // Add trending posts
      for (final post in trendingPosts) {
        if (!seenIds.contains(post.id)) {
          allPosts.add(post);
          seenIds.add(post.id);
        }
      }

      // Add following posts (friends + public)
      for (final post in followingPosts) {
        if (!seenIds.contains(post.id)) {
          allPosts.add(post);
          seenIds.add(post.id);
        }
      }

      debugPrint(
          'PostRepository: Unified feed fetched ${allPosts.length} unique posts (trending: ${trendingPosts.length}, boosted: ${boostedPosts.length}, following: ${followingPosts.length}, user: ${userOwnPosts.length})');

      // Cache the results (only for paginated requests, not initial load)
      if (lastDocument != null) {
        _pageCache[cacheKey] = allPosts;
        debugPrint('PostRepository: Cached page $cacheKey');
      }

      return (allPosts, lastDoc);
    } catch (e) {
      debugPrint('PostRepository: Error getting unified feed: $e');
      rethrow;
    }
  }

  /// Client-Side Ranking Plan: Fetch all candidate posts for ranking
  /// Returns a combined, deduplicated list of posts from friends, followed pages, and trending
  ///
  /// This method runs multiple queries in parallel and combines the results.
  /// Used for client-side ranking calculation.
  Future<List<PostModel>> getFeedCandidates(String userId) async {
    try {
      // Step 1: Get user's friends and followed pages
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('PostRepository: User not found: $userId');
        return [];
      }

      final userData = userDoc.data() ?? {};
      final friends = List<String>.from(userData['friends'] ?? []);
      final followedPages = List<String>.from(userData['followedPages'] ?? []);

      // Step 2: Create list of futures for parallel queries
      final queries = <Future<QuerySnapshot>>[];

      // Query 1: Posts from friends (limit 50 per batch to reduce reads)
      // Firestore 'whereIn' limit is 10, so batch if needed
      if (friends.isNotEmpty) {
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
                .limit(50) // OPTIMIZED: Reduced from 100 to 50
                .get(),
          );
        }
      }

      // Query 2: Posts from followed pages (limit 50 per batch to reduce reads)
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
                .limit(50) // OPTIMIZED: Reduced from 100 to 50
                .get(),
          );
        }
      }

      // Query 3: Trending posts (limit 30 to reduce reads)
      queries.add(
        _db
            .collection('posts')
            .where('deleted', isEqualTo: false)
            .where('visibility', isEqualTo: 'public')
            .orderBy('trendingScore', descending: true)
            .limit(30) // OPTIMIZED: Reduced from 50 to 30
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
}
