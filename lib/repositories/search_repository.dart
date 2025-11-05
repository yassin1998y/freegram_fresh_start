// lib/repositories/search_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/models/page_model.dart';

class SearchRepository {
  final FirebaseFirestore _db;

  SearchRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Search posts by hashtag
  /// Note: Firestore doesn't support full-text search, so we search by hashtags
  /// For full-text search, consider using Algolia, Typesense, or Elasticsearch
  Future<List<PostModel>> searchPosts(String query, {int limit = 20}) async {
    try {
      if (query.isEmpty) return [];

      // Normalize query (remove # if present, lowercase)
      final normalizedQuery = query.replaceFirst('#', '').toLowerCase().trim();

      if (normalizedQuery.isEmpty) return [];

      // Search posts that contain this hashtag
      final snapshot = await _db
          .collection('posts')
          .where('hashtags', arrayContains: normalizedQuery)
          .where('deleted', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => PostModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('SearchRepository: Error searching posts: $e');
      return [];
    }
  }

  /// Search users by username prefix
  /// Uses Firestore range queries for prefix matching
  Future<List<UserModel>> searchUsers(String query, {int limit = 20}) async {
    try {
      if (query.isEmpty) return [];

      final normalizedQuery = query.toLowerCase().trim();
      if (normalizedQuery.isEmpty) return [];

      // Firestore prefix search: use two where clauses for range query
      // Note: This requires a composite index on username
      // To create index: run Firebase CLI command or add to firestore.indexes.json
      final snapshot = await _db
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: normalizedQuery)
          .where('username', isLessThan: '$normalizedQuery\uf8ff')
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => UserModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('SearchRepository: Error searching users: $e');
      // Fallback: If index doesn't exist, try simple equality search as fallback
      // This is less efficient but works without indexes
      final fallbackQuery = query.toLowerCase().trim();
      try {
        final snapshot = await _db
            .collection('users')
            .where('username', isEqualTo: fallbackQuery)
            .limit(limit)
            .get();
        return snapshot.docs.map((doc) => UserModel.fromDoc(doc)).toList();
      } catch (fallbackError) {
        debugPrint(
            'SearchRepository: Fallback search also failed: $fallbackError');
        return [];
      }
    }
  }

  /// Search pages by pageName prefix
  /// Similar to user search, uses prefix matching
  Future<List<PageModel>> searchPages(String query, {int limit = 20}) async {
    try {
      if (query.isEmpty) return [];

      final normalizedQuery = query.toLowerCase().trim();
      if (normalizedQuery.isEmpty) return [];

      // Search by pageName using prefix matching
      // Note: Requires composite index on pageName
      final snapshot = await _db
          .collection('pages')
          .where('pageName', isGreaterThanOrEqualTo: normalizedQuery)
          .where('pageName', isLessThan: '$normalizedQuery\uf8ff')
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => PageModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('SearchRepository: Error searching pages: $e');
      // Fallback: Try exact match
      final fallbackQuery = query.toLowerCase().trim();
      try {
        final snapshot = await _db
            .collection('pages')
            .where('pageName', isEqualTo: fallbackQuery)
            .limit(limit)
            .get();
        return snapshot.docs.map((doc) => PageModel.fromDoc(doc)).toList();
      } catch (fallbackError) {
        debugPrint(
            'SearchRepository: Fallback page search also failed: $fallbackError');
        return [];
      }
    }
  }

  /// Search hashtags
  /// Returns posts that contain the hashtag (similar to searchPosts)
  Future<List<PostModel>> searchHashtags(String query, {int limit = 20}) async {
    // Hashtag search is essentially the same as post search by hashtag
    return searchPosts(query, limit: limit);
  }

  /// Get recent searches for a user
  /// Reads from users/{userId}/recentSearches subcollection
  Future<List<String>> getRecentSearches(String userId,
      {int limit = 10}) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('recentSearches')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['query'] as String? ?? '')
          .where((query) => query.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('SearchRepository: Error getting recent searches: $e');
      return [];
    }
  }

  /// Save a search query to user's search history
  /// Writes to users/{userId}/recentSearches subcollection
  Future<void> saveSearch(String userId, String query) async {
    try {
      if (query.trim().isEmpty) return;

      final normalizedQuery = query.trim().toLowerCase();

      // Check if this search already exists (to avoid duplicates)
      final existingSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('recentSearches')
          .where('query', isEqualTo: normalizedQuery)
          .limit(1)
          .get();

      // If exists, update timestamp; otherwise, create new
      if (existingSnapshot.docs.isNotEmpty) {
        await existingSnapshot.docs.first.reference.update({
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new search history entry
        await _db
            .collection('users')
            .doc(userId)
            .collection('recentSearches')
            .add({
          'query': normalizedQuery,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // Limit history to last 20 searches (optional cleanup)
      final allSearchesSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('recentSearches')
          .orderBy('timestamp', descending: true)
          .get();

      if (allSearchesSnapshot.docs.length > 20) {
        // Delete oldest searches beyond limit
        final toDelete = allSearchesSnapshot.docs.skip(20);
        final batch = _db.batch();
        for (final doc in toDelete) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('SearchRepository: Error saving search: $e');
      // Don't throw - search history is optional
    }
  }

  /// Clear search history for a user
  Future<void> clearSearchHistory(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('recentSearches')
          .get();

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('SearchRepository: Error clearing search history: $e');
      rethrow;
    }
  }
}
