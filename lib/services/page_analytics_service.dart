// lib/services/page_analytics_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Analytics data models
class PageAnalytics {
  final int followerCount;
  final int postCount;
  final int totalReactions;
  final int totalComments;
  final int totalReach;
  final int profileViews;
  final List<PostEngagement> topPosts;
  final Map<DateTime, int> followerGrowth; // Daily follower count
  final Map<DateTime, int> engagementHistory; // Daily engagement

  PageAnalytics({
    required this.followerCount,
    required this.postCount,
    required this.totalReactions,
    required this.totalComments,
    required this.totalReach,
    required this.profileViews,
    this.topPosts = const [],
    this.followerGrowth = const {},
    this.engagementHistory = const {},
  });

  double get engagementRate {
    if (totalReach == 0) return 0.0;
    return ((totalReactions + totalComments) / totalReach) * 100;
  }

  double get averageEngagementPerPost {
    if (postCount == 0) return 0.0;
    return (totalReactions + totalComments) / postCount;
  }
}

class PostEngagement {
  final String postId;
  final String content;
  final int reactions;
  final int comments;
  final int reach;
  final DateTime timestamp;

  PostEngagement({
    required this.postId,
    required this.content,
    required this.reactions,
    required this.comments,
    required this.reach,
    required this.timestamp,
  });

  int get totalEngagement => reactions + comments;
}

class PageAnalyticsService {
  final FirebaseFirestore _db;

  PageAnalyticsService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Get comprehensive analytics for a page
  Future<PageAnalytics> getPageAnalytics(String pageId) async {
    try {
      // Get page document
      final pageDoc = await _db.collection('pages').doc(pageId).get();
      if (!pageDoc.exists) {
        throw Exception('Page not found');
      }

      final pageData = pageDoc.data()!;
      final followerCount = (pageData['followerCount'] ?? 0) as int;
      final postCount = (pageData['postCount'] ?? 0) as int;

      // Get all page posts
      final postsSnapshot = await _db
          .collection('posts')
          .where('pageId', isEqualTo: pageId)
          .where('deleted', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .get();

      int totalReactions = 0;
      int totalComments = 0;
      final List<PostEngagement> topPostsList = [];

      for (final postDoc in postsSnapshot.docs) {
        final postData = postDoc.data();
        final reactions = (postData['reactionCount'] ?? 0) as int;
        final comments = (postData['commentCount'] ?? 0) as int;
        final reach = (postData['viewCount'] ?? 0) as int;

        totalReactions += reactions;
        totalComments += comments;

        topPostsList.add(PostEngagement(
          postId: postDoc.id,
          content: postData['content'] ?? '',
          reactions: reactions,
          comments: comments,
          reach: reach,
          timestamp: (postData['timestamp'] as Timestamp).toDate(),
        ));
      }

      // Sort by engagement and take top 10
      topPostsList
          .sort((a, b) => b.totalEngagement.compareTo(a.totalEngagement));
      final topPosts = topPostsList.take(10).toList();

      // Calculate total reach (sum of all post views)
      final totalReach = topPostsList.fold<int>(
        0,
        (sum, post) => sum + post.reach,
      );

      // Get profile views (from analytics collection if tracked)
      final profileViews = await _getProfileViews(pageId);

      // Get follower growth (last 30 days)
      final followerGrowth = await _getFollowerGrowth(pageId, days: 30);

      // Get engagement history (last 30 days)
      final engagementHistory = await _getEngagementHistory(pageId, days: 30);

      return PageAnalytics(
        followerCount: followerCount,
        postCount: postCount,
        totalReactions: totalReactions,
        totalComments: totalComments,
        totalReach: totalReach,
        profileViews: profileViews,
        topPosts: topPosts,
        followerGrowth: followerGrowth,
        engagementHistory: engagementHistory,
      );
    } catch (e) {
      debugPrint('PageAnalyticsService: Error getting analytics: $e');
      rethrow;
    }
  }

  /// Track profile view
  Future<void> trackProfileView(String pageId, String userId) async {
    try {
      final now = DateTime.now();
      final dateKey = DateTime(now.year, now.month, now.day);

      await _db
          .collection('pages')
          .doc(pageId)
          .collection('analytics')
          .doc('profileViews')
          .collection('daily')
          .doc(dateKey.toIso8601String().split('T')[0])
          .set({
        'date': Timestamp.fromDate(dateKey),
        'views': FieldValue.increment(1),
        'uniqueViewers': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('PageAnalyticsService: Error tracking profile view: $e');
      // Don't rethrow - analytics shouldn't block user experience
    }
  }

  /// Track post reach (impression)
  Future<void> trackPostReach(String postId, String userId) async {
    try {
      await _db.collection('posts').doc(postId).update({
        'viewCount': FieldValue.increment(1),
      });

      // Track unique viewers
      await _db
          .collection('posts')
          .doc(postId)
          .collection('viewers')
          .doc(userId)
          .set({
        'viewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('PageAnalyticsService: Error tracking post reach: $e');
      // Don't rethrow
    }
  }

  /// Get profile views count
  Future<int> _getProfileViews(String pageId) async {
    try {
      final snapshot = await _db
          .collection('pages')
          .doc(pageId)
          .collection('analytics')
          .doc('profileViews')
          .collection('daily')
          .get();

      int totalViews = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalViews += (data['views'] ?? 0) as int;
      }
      return totalViews;
    } catch (e) {
      debugPrint('PageAnalyticsService: Error getting profile views: $e');
      return 0;
    }
  }

  /// Get follower growth over time
  Future<Map<DateTime, int>> _getFollowerGrowth(String pageId,
      {int days = 30}) async {
    try {
      final snapshot = await _db
          .collection('pages')
          .doc(pageId)
          .collection('followers')
          .orderBy('followedAt', descending: false)
          .get();

      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final Map<DateTime, int> growth = {};

      for (final doc in snapshot.docs) {
        final followedAt = (doc.data()['followedAt'] as Timestamp).toDate();

        if (followedAt.isAfter(startDate)) {
          final dateKey =
              DateTime(followedAt.year, followedAt.month, followedAt.day);
          growth[dateKey] = (growth[dateKey] ?? 0) + 1;
        }
      }

      // Fill in dates with 0 followers for completeness
      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dateKey = DateTime(date.year, date.month, date.day);
        if (!growth.containsKey(dateKey)) {
          growth[dateKey] = 0;
        }
      }

      return growth;
    } catch (e) {
      debugPrint('PageAnalyticsService: Error getting follower growth: $e');
      return {};
    }
  }

  /// Get engagement history over time
  Future<Map<DateTime, int>> _getEngagementHistory(String pageId,
      {int days = 30}) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final postsSnapshot = await _db
          .collection('posts')
          .where('pageId', isEqualTo: pageId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startDate))
          .where('deleted', isEqualTo: false)
          .get();

      final Map<DateTime, int> engagement = {};

      for (final postDoc in postsSnapshot.docs) {
        final postData = postDoc.data();
        final timestamp = (postData['timestamp'] as Timestamp).toDate();
        final dateKey =
            DateTime(timestamp.year, timestamp.month, timestamp.day);

        final reactions = (postData['reactionCount'] ?? 0) as int;
        final comments = (postData['commentCount'] ?? 0) as int;
        final engagementCount = reactions + comments;

        engagement[dateKey] = (engagement[dateKey] ?? 0) + engagementCount;
      }

      // Fill in dates with 0 engagement
      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dateKey = DateTime(date.year, date.month, date.day);
        if (!engagement.containsKey(dateKey)) {
          engagement[dateKey] = 0;
        }
      }

      return engagement;
    } catch (e) {
      debugPrint('PageAnalyticsService: Error getting engagement history: $e');
      return {};
    }
  }
}
