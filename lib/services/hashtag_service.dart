// lib/services/hashtag_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class HashtagService {
  final FirebaseFirestore _db;

  HashtagService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Extract hashtags from text using regex
  /// Returns a list of unique hashtags (without the # symbol)
  List<String> extractHashtags(String text) {
    if (text.isEmpty) return [];

    // Regex to match hashtags: # followed by alphanumeric characters and underscores
    final regex = RegExp(r'#(\w+)', caseSensitive: false);
    final matches = regex.allMatches(text);

    // Extract unique hashtags (case-insensitive)
    final Set<String> uniqueHashtags = {};
    for (final match in matches) {
      if (match.groupCount > 0) {
        final hashtag = match.group(1)!.toLowerCase();
        if (hashtag.isNotEmpty) {
          uniqueHashtags.add(hashtag);
        }
      }
    }

    return uniqueHashtags.toList();
  }

  /// Get posts by hashtag
  Future<List<String>> getPostsByHashtag(
    String hashtag, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _db
          .collection('posts')
          .where('hashtags', arrayContains: hashtag.toLowerCase())
          .where('deleted', isEqualTo: false)
          .where('visibility', isEqualTo: 'public')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('HashtagService: Error getting posts by hashtag: $e');
      return [];
    }
  }

  /// Get trending hashtags based on recent engagement
  /// Returns top hashtags sorted by engagement (reactionCount + commentCount)
  Future<List<Map<String, dynamic>>> getTrendingHashtags({
    int limit = 10,
    Duration timeWindow = const Duration(days: 7),
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(timeWindow);
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      // Get recent posts with hashtags
      final snapshot = await _db
          .collection('posts')
          .where('deleted', isEqualTo: false)
          .where('timestamp', isGreaterThan: cutoffTimestamp)
          .where('hashtags', isNotEqualTo: <String>[])
          .limit(1000) // Get recent posts
          .get();

      // Aggregate hashtag engagement
      final Map<String, int> hashtagEngagement = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final hashtags = List<String>.from(data['hashtags'] ?? []);
        final engagement = (data['reactionCount'] as int? ?? 0) +
            (data['commentCount'] as int? ?? 0);

        for (final hashtag in hashtags) {
          hashtagEngagement[hashtag.toLowerCase()] =
              (hashtagEngagement[hashtag.toLowerCase()] ?? 0) + engagement;
        }
      }

      // Sort by engagement and return top hashtags
      final sorted = hashtagEngagement.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted.take(limit).map((entry) {
        return {
          'hashtag': entry.key,
          'engagement': entry.value,
          'postCount': snapshot.docs
              .where((doc) =>
                  (doc.data()['hashtags'] as List?)?.contains(entry.key) ??
                  false)
              .length,
        };
      }).toList();
    } catch (e) {
      debugPrint('HashtagService: Error getting trending hashtags: $e');
      return [];
    }
  }

  /// Get hashtag statistics
  Future<Map<String, dynamic>?> getHashtagStats(String hashtag) async {
    try {
      final postsSnapshot = await _db
          .collection('posts')
          .where('hashtags', arrayContains: hashtag.toLowerCase())
          .where('deleted', isEqualTo: false)
          .get();

      int totalPosts = postsSnapshot.docs.length;
      int totalReactions = 0;
      int totalComments = 0;

      for (final doc in postsSnapshot.docs) {
        final data = doc.data();
        totalReactions += data['reactionCount'] as int? ?? 0;
        totalComments += data['commentCount'] as int? ?? 0;
      }

      return {
        'hashtag': hashtag.toLowerCase(),
        'postCount': totalPosts,
        'totalReactions': totalReactions,
        'totalComments': totalComments,
        'totalEngagement': totalReactions + totalComments,
      };
    } catch (e) {
      debugPrint('HashtagService: Error getting hashtag stats: $e');
      return null;
    }
  }

  /// Update hashtag usage count (for trending algorithm)
  /// This is called when a post with hashtags is created/updated
  Future<void> updateHashtagUsage(List<String> hashtags) async {
    try {
      final batch = _db.batch();
      final now = Timestamp.now();

      for (final hashtag in hashtags) {
        final hashtagRef =
            _db.collection('hashtags').doc(hashtag.toLowerCase());
        batch.set(
          hashtagRef,
          {
            'hashtag': hashtag.toLowerCase(),
            'postCount': FieldValue.increment(1),
            'lastUsed': now,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    } catch (e) {
      debugPrint('HashtagService: Error updating hashtag usage: $e');
    }
  }
}
