import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/services/global_cache_coordinator.dart';

class LeaderboardRepository {
  final FirebaseFirestore _db;
  final GlobalCacheCoordinator _cache;

  LeaderboardRepository({
    FirebaseFirestore? firestore,
    GlobalCacheCoordinator? cache,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _cache = cache ?? locator<GlobalCacheCoordinator>();

  Future<List<UserModel>> getTopUsersBySocialPoints(
      {int limit = 100, bool forceRefresh = false}) async {
    // 1. Try Cache
    if (!forceRefresh) {
      final cachedUsers = await _cache.getCachedItems<UserModel>();
      if (cachedUsers.isNotEmpty) {
        // Sort by socialPoints primarily, then totalGiftsSent, then totalMessagesSent
        cachedUsers.sort((a, b) {
          int cmp = b.socialPoints.compareTo(a.socialPoints);
          if (cmp != 0) return cmp;
          cmp = b.totalGiftsSent.compareTo(a.totalGiftsSent);
          if (cmp != 0) return cmp;
          return b.totalMessagesSent.compareTo(a.totalMessagesSent);
        });
        return cachedUsers.take(limit).toList();
      }
    }

    try {
      // 2. Query Firestore
      // Order by socialPoints descending
      final querySnapshot = await _db
          .collection('users')
          .orderBy('socialPoints', descending: true)
          .limit(limit)
          .get();

      final users =
          querySnapshot.docs.map((doc) => UserModel.fromDoc(doc)).toList();

      // 3. Cache results
      if (users.isNotEmpty) {
        await _cache.cacheItems<UserModel>(users);
      }

      return users;
    } catch (e) {
      // Fallback to cache if offline/error and we skipped it initially?
      // Or just return empty list
      return [];
    }
  }

  // Helper getters for other stats if needed, or we can just use the socialPoints one for the main board
  // The original LeaderboardScreen had Senders, Receivers, Collectors tabs.
  // We should likely support those too, but populate them via specific queries or client-side sort if data is small (100).
  // But 100 users might not overlap.

  Future<List<UserModel>> getTopSenders({int limit = 100}) async {
    return _db
        .collection('users')
        .orderBy('totalGiftsSent', descending: true)
        .limit(limit)
        .get()
        .then((s) => s.docs.map((d) => UserModel.fromDoc(d)).toList());
  }

  Future<List<UserModel>> getTopReceivers({int limit = 100}) async {
    return _db
        .collection('users')
        .orderBy('totalGiftsReceived', descending: true)
        .limit(limit)
        .get()
        .then((s) => s.docs.map((d) => UserModel.fromDoc(d)).toList());
  }

  Future<List<UserModel>> getTopCollectors({int limit = 100}) async {
    return _db
        .collection('users')
        .orderBy('uniqueGiftsCollected', descending: true)
        .limit(limit)
        .get()
        .then((s) => s.docs.map((d) => UserModel.fromDoc(d)).toList());
  }

  Future<int> getUserRank(String userId, int socialPoints) async {
    try {
      final countSnapshot = await _db
          .collection('users')
          .where('socialPoints', isGreaterThan: socialPoints)
          .count()
          .get();
      return countSnapshot.count! + 1;
    } catch (e) {
      return 0; // Error or unknown rank
    }
  }
}
