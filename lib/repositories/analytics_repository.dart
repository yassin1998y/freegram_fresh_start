import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/gift_model.dart';

class AnalyticsRepository {
  final FirebaseFirestore _db;

  AnalyticsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Get gifting statistics for a user
  Future<Map<String, dynamic>> getUserGiftingStats(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) return {};

    final data = userDoc.data()!;
    return {
      'totalSent': data['totalGiftsSent'] ?? 0,
      'totalReceived': data['totalGiftsReceived'] ?? 0,
      'uniqueCollected': data['uniqueGiftsCollected'] ?? 0,
      'coinsSpent': data['lifetimeCoinsSpent'] ?? 0,
      'currentCoins': data['coins'] ?? 0,
    };
  }

  /// Get most popular gifts globally
  Future<List<GiftModel>> getPopularGifts({int limit = 5}) async {
    final snapshot = await _db
        .collection('gifts')
        .orderBy('soldCount', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => GiftModel.fromDoc(doc)).toList();
  }

  /// Get recent activity for a user (sent and received)
  Future<List<Map<String, dynamic>>> getRecentActivity(String userId,
      {int limit = 10}) async {
    // This is a simplified version. Ideally, we'd query a separate 'activities' collection
    // or combine queries from 'sentGifts' and 'receivedGifts' subcollections if they existed as logs.
    // For now, we'll just fetch the user's gift history if available, or return empty.
    // Assuming we don't have a centralized activity feed yet.

    // Alternative: Query 'gifts' collection where senderId or receiverId is userId
    // But 'gifts' collection stores definitions, not transactions.
    // Transactions are in 'users/{uid}/ownedGifts' (received) and maybe we need a 'sentGifts' log.

    // Let's use the 'notifications' collection as a proxy for recent activity if possible,
    // or just return a placeholder for now until we implement a proper activity logger.

    return [];
  }

  /// Track badge interaction
  Future<void> trackBadgeClick(String badgeId) async {
    await _db.collection('analytics').doc('badges').collection('clicks').add({
      'badgeId': badgeId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Global Error Logger
  Future<void> logError({
    required String message,
    String? stackTrace,
    String? context,
  }) async {
    try {
      await _db.collection('analytics').doc('errors').collection('logs').add({
        'message': message,
        'stackTrace': stackTrace,
        'context': context,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Fail silently for analytics
    }
  }

  /// Get live reach data for the user's active boosts
  /// Returns a list of data points (timestamp, reach count) for the graph
  Future<List<Map<String, dynamic>>> getLiveBoostReach(String userId) async {
    try {
      // 1. Get active boosted posts for the user
      final now = Timestamp.now();
      final postsSnapshot = await _db
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .where('isBoosted', isEqualTo: true)
          .where('boostEndTime', isGreaterThan: now)
          .orderBy('boostEndTime', descending: true)
          .limit(1) // Focus on the most recent active boost for the graph
          .get();

      if (postsSnapshot.docs.isEmpty) {
        return [];
      }

      final post = postsSnapshot.docs.first;
      final postId = post.id;

      // 2. Get reach history from subcollection
      // Limiting to last 50 data points for performance/graph readability
      final reachSnapshot = await _db
          .collection('posts')
          .doc(postId)
          .collection('boostReach')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      // 3. Transform to graph data points
      // We want cumulative reach over time, or just the events
      // Let's return raw events, the UI can aggregate or plot them
      return reachSnapshot.docs.map((doc) {
        return {
          'timestamp': (doc['timestamp'] as Timestamp).toDate(),
          'userId': doc['userId'], // Optional, maybe for uniqueness check
        };
      }).toList();
    } catch (e) {
      // Fail silently or return empty
      return [];
    }
  }

  /// Track reach for a boosted post
  Future<void> trackBoostReach(String postId, String viewerId) async {
    try {
      final postRef = _db.collection('posts').doc(postId);

      // 1. Log the reach event
      await postRef.collection('boostReach').add({
        'userId': viewerId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Increment stats on the post doc
      // Ideally this would be done in a Cloud Function to avoid write conflicts
      // but for "Live Reach" zero-latency we do it here or via batch.
      await postRef.update({
        'boostStats.reach': FieldValue.increment(1),
        'boostStats.impressions': FieldValue.increment(1),
      });
    } catch (e) {
      // Fail silently
    }
  }
}
