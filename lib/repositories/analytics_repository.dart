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
}
