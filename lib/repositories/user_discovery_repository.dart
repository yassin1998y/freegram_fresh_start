import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/user_model.dart';

class UserDiscoveryRepository {
  final FirebaseFirestore _db;

  UserDiscoveryRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // --- User Discovery Methods ---

  Future<QuerySnapshot> getPaginatedUsers(
      {required int limit, DocumentSnapshot? lastDocument}) {
    debugPrint(
        "UserDiscoveryRepository: Fetching paginated users (limit: $limit).");
    Query query = _db.collection('users').orderBy('username').limit(limit);
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    return query.get();
  }

  Future<List<DocumentSnapshot>> getRecommendedUsers(
      List<String> interests, String currentUserId) async {
    debugPrint(
        "UserDiscoveryRepository: Fetching recommended users for $currentUserId.");
    if (interests.isEmpty) return [];
    try {
      // Query based on interests
      final querySnapshot = await _db
          .collection('users')
          .where('interests', arrayContainsAny: interests)
          .limit(50) // Fetch a larger pool initially
          .get();

      // Filter out current user and map to UserModel for sorting
      final candidates = querySnapshot.docs
          .where((doc) => doc.id != currentUserId)
          .map((doc) => UserModel.fromDoc(doc))
          .toList();

      // Sort primarily by number of shared interests (descending)
      candidates.sort((a, b) {
        final aSharedInterests =
            a.interests.where((i) => interests.contains(i)).length;
        final bSharedInterests =
            b.interests.where((i) => interests.contains(i)).length;
        // Primary sort: shared interests (descending)
        int interestComparison = bSharedInterests.compareTo(aSharedInterests);
        if (interestComparison != 0) return interestComparison;
        // Secondary sort: maybe last seen (more recent first)? Optional.
        // return b.lastSeen.compareTo(a.lastSeen);
        return 0; // Or no secondary sort
      });

      // Get the sorted IDs
      final sortedIds = candidates.map((u) => u.id).toList();

      // Re-sort the original DocumentSnapshots based on the sorted IDs
      final originalDocs =
          querySnapshot.docs.where((doc) => doc.id != currentUserId).toList();
      originalDocs.sort(
          (a, b) => sortedIds.indexOf(a.id).compareTo(sortedIds.indexOf(b.id)));

      // Return the top N recommendations
      return originalDocs.take(30).toList();
    } catch (e) {
      debugPrint(
          "UserDiscoveryRepository Error: Failed to get recommended users: $e");
      return [];
    }
  }

  Stream<QuerySnapshot> searchUsers(String query) {
    if (kDebugMode) {
      debugPrint("[UserDiscoveryRepository] Searching users with query '$query'");
    }
    if (query.isEmpty) return const Stream.empty();

    // Bug #16 fix: Sanitize search query to prevent injection and handle special chars
    final sanitizedQuery = query.trim().replaceAll(RegExp(r'[^\w\s]'), '');
    if (sanitizedQuery.isEmpty) return const Stream.empty();

    return _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: sanitizedQuery)
        .where('username', isLessThanOrEqualTo: '$sanitizedQuery\uf8ff')
        .limit(20)
        .snapshots();
  }
}
