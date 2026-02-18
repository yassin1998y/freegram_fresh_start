// lib/repositories/reel_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/models/comment_model.dart';
import 'package:freegram/models/reel_interaction_model.dart';

class ReelRepository {
  final FirebaseFirestore _db;

  ReelRepository({
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  /// Get reels feed (paginated)
  Future<List<ReelModel>> getReelsFeed({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _db
          .collection('reels')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) => ReelModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('ReelRepository: Error getting reels feed: $e');
      return [];
    }
  }

  /// Get a single reel by ID
  Future<ReelModel?> getReel(String reelId) async {
    try {
      final doc = await _db.collection('reels').doc(reelId).get();
      if (!doc.exists) return null;
      return ReelModel.fromDoc(doc);
    } catch (e) {
      debugPrint('ReelRepository: Error getting reel: $e');
      return null;
    }
  }

  /// Like a reel
  Future<void> likeReel(String reelId, String userId) async {
    try {
      final batch = _db.batch();

      // Check if already liked
      final likeDoc = await _db
          .collection('reels')
          .doc(reelId)
          .collection('likes')
          .doc(userId)
          .get();

      if (likeDoc.exists) {
        return; // Already liked
      }

      // Add like document
      final likeRef =
          _db.collection('reels').doc(reelId).collection('likes').doc(userId);

      batch.set(likeRef, {
        'userId': userId,
        'likedAt': FieldValue.serverTimestamp(),
      });

      // Increment like count
      final reelRef = _db.collection('reels').doc(reelId);
      batch.update(reelRef, {
        'likeCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('ReelRepository: Error liking reel: $e');
      rethrow;
    }
  }

  /// Unlike a reel
  Future<void> unlikeReel(String reelId, String userId) async {
    try {
      final batch = _db.batch();

      // Remove like document
      final likeRef =
          _db.collection('reels').doc(reelId).collection('likes').doc(userId);

      batch.delete(likeRef);

      // Decrement like count
      final reelRef = _db.collection('reels').doc(reelId);
      batch.update(reelRef, {
        'likeCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('ReelRepository: Error unliking reel: $e');
      rethrow;
    }
  }

  /// Check if reel is liked by user
  Future<bool> isReelLiked(String reelId, String userId) async {
    try {
      final likeDoc = await _db
          .collection('reels')
          .doc(reelId)
          .collection('likes')
          .doc(userId)
          .get();

      return likeDoc.exists;
    } catch (e) {
      debugPrint('ReelRepository: Error checking like status: $e');
      return false;
    }
  }

  /// Increment view count
  Future<void> incrementViewCount(String reelId) async {
    try {
      await _db.collection('reels').doc(reelId).update({
        'viewCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ReelRepository: Error incrementing view count: $e');
    }
  }

  /// Increment share count
  Future<void> incrementShareCount(String reelId) async {
    try {
      await _db.collection('reels').doc(reelId).update({
        'shareCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ReelRepository: Error incrementing share count: $e');
    }
  }

  /// Delete a reel (soft delete)
  Future<void> deleteReel(String reelId, String userId) async {
    try {
      final reelDoc = await _db.collection('reels').doc(reelId).get();
      if (!reelDoc.exists) {
        throw Exception('Reel not found');
      }

      final reel = ReelModel.fromDoc(reelDoc);
      if (reel.uploaderId != userId) {
        throw Exception('Not authorized to delete this reel');
      }

      await _db.collection('reels').doc(reelId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ReelRepository: Error deleting reel: $e');
      rethrow;
    }
  }

  /// Get user's reels
  Future<List<ReelModel>> getUserReels(String userId, {int limit = 20}) async {
    try {
      final snapshot = await _db
          .collection('reels')
          .where('uploaderId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => ReelModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('ReelRepository: Error getting user reels: $e');
      return [];
    }
  }

  /// Get trending reels based on engagement (views, likes, comments)
  /// Orders by engagement score calculated from viewCount, likeCount, commentCount
  Future<List<ReelModel>> getTrendingReels({int limit = 10}) async {
    try {
      // Get recent reels (client-side filter for last 7 days to avoid index requirement)
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));

      final snapshot = await _db
          .collection('reels')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit * 5) // Get more to filter and sort by engagement
          .get();

      final allReels =
          snapshot.docs.map((doc) => ReelModel.fromDoc(doc)).toList();

      // Filter to last 7 days
      List<ReelModel> trendingReels =
          allReels.where((reel) => reel.createdAt.isAfter(weekAgo)).toList();

      // LOGIC FIX: If no fresh reels (last 7 days), fallback to any available reels
      // indexed by engagement to ensure discovery trail is never empty.
      if (trendingReels.isEmpty) {
        trendingReels = allReels;
      }

      // Calculate engagement score: views * 1 + likes * 5 + comments * 10
      trendingReels.sort((a, b) {
        final scoreA = a.viewCount * 1 + a.likeCount * 5 + a.commentCount * 10;
        final scoreB = b.viewCount * 1 + b.likeCount * 5 + b.commentCount * 10;
        return scoreB.compareTo(scoreA);
      });

      return trendingReels.take(limit).toList();
    } catch (e) {
      debugPrint('ReelRepository: Error getting trending reels: $e');
      // Fallback: just get recent reels if engagement sorting fails
      try {
        final snapshot = await _db
            .collection('reels')
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
        return snapshot.docs.map((doc) => ReelModel.fromDoc(doc)).toList();
      } catch (fallbackError) {
        debugPrint('ReelRepository: Fallback also failed: $fallbackError');
        return [];
      }
    }
  }

  /// Get personalized reels feed for a user
  /// Fetches a larger batch for client-side scoring and filtering
  Future<List<ReelModel>> getPersonalizedReelsFeed({
    required String userId,
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _db
          .collection('reels')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => ReelModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('ReelRepository: Error getting personalized feed: $e');
      return [];
    }
  }

  /// Get reels by hashtags (for interest matching)
  Future<List<ReelModel>> getReelsByHashtags({
    required List<String> hashtags,
    int limit = 20,
  }) async {
    if (hashtags.isEmpty) return [];

    try {
      final snapshot = await _db
          .collection('reels')
          .where('isActive', isEqualTo: true)
          .where('hashtags', arrayContainsAny: hashtags.take(10).toList())
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => ReelModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('ReelRepository: Error getting reels by hashtags: $e');
      return [];
    }
  }

  /// Get reels from users that the current user follows
  Future<List<ReelModel>> getReelsFromFollowing({
    required List<String> followingIds,
    int limit = 20,
  }) async {
    if (followingIds.isEmpty) return [];

    try {
      // Firestore 'in' query limit is 10, so batch if needed
      const batchSize = 10;
      final batches = <Future<QuerySnapshot>>[];

      for (int i = 0; i < followingIds.length; i += batchSize) {
        final batch = followingIds.skip(i).take(batchSize).toList();
        batches.add(
          _db
              .collection('reels')
              .where('isActive', isEqualTo: true)
              .where('uploaderId', whereIn: batch)
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get(),
        );
      }

      final results = await Future.wait(batches);
      final allReels = <ReelModel>[];

      for (final snapshot in results) {
        allReels.addAll(
          snapshot.docs.map((doc) => ReelModel.fromDoc(doc)),
        );
      }

      // Sort by creation date and limit
      allReels.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return allReels.take(limit).toList();
    } catch (e) {
      debugPrint('ReelRepository: Error getting reels from following: $e');
      return [];
    }
  }

  /// Record user interaction with a reel
  Future<void> recordReelInteraction(ReelInteractionModel interaction) async {
    try {
      await _db
          .collection('users')
          .doc(interaction.userId)
          .collection('reelInteractions')
          .doc(interaction.reelId)
          .set(
            interaction.toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('ReelRepository: Error recording interaction: $e');
    }
  }

  /// Get user's interaction with a specific reel
  Future<ReelInteractionModel?> getReelInteraction(
    String userId,
    String reelId,
  ) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('reelInteractions')
          .doc(reelId)
          .get();

      if (!doc.exists) return null;
      return ReelInteractionModel.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('ReelRepository: Error getting interaction: $e');
      return null;
    }
  }

  /// Get user's not interested creators
  Future<Set<String>> getNotInterestedCreators(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('reelInteractions')
          .where('notInterested', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['creatorId'] as String)
          .toSet();
    } catch (e) {
      debugPrint('ReelRepository: Error getting not interested creators: $e');
      return {};
    }
  }

  /// Add a comment to a reel - Uses batch for atomic operations
  Future<String> addComment(
    String reelId,
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
          _db.collection('reels').doc(reelId).collection('comments').doc();

      batch.set(commentRef, {
        'commentId': commentRef.id,
        'reelId': reelId,
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

      // Update reel comment count (atomic increment)
      final reelRef = _db.collection('reels').doc(reelId);
      batch.update(reelRef, {
        'commentCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return commentRef.id;
    } catch (e) {
      debugPrint('ReelRepository: Error adding comment: $e');
      rethrow;
    }
  }

  /// Get comments for a reel with pagination
  Future<List<CommentModel>> getComments(
    String reelId, {
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    try {
      var query = _db
          .collection('reels')
          .doc(reelId)
          .collection('comments')
          .where('deleted', isEqualTo: false)
          .orderBy('timestamp', descending: false) // Oldest first for comments
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Convert reelId to postId for CommentModel compatibility
        return CommentModel.fromMap(doc.id, {
          ...data,
          'postId': reelId, // CommentModel uses postId, but we store reelId
        });
      }).toList();
    } catch (e) {
      debugPrint('ReelRepository: Error getting comments: $e');
      rethrow;
    }
  }

  /// Stream comments for a reel (real-time updates)
  Stream<List<CommentModel>> getCommentsStream(String reelId) {
    try {
      return _db
          .collection('reels')
          .doc(reelId)
          .collection('comments')
          .where('deleted', isEqualTo: false)
          .orderBy('timestamp', descending: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return CommentModel.fromMap(doc.id, {
            ...data,
            'postId': reelId, // CommentModel uses postId for compatibility
          });
        }).toList();
      });
    } catch (e) {
      debugPrint('ReelRepository: Error getting comments stream: $e');
      return Stream.value([]);
    }
  }

  /// Edit comment
  Future<void> editComment(
    String reelId,
    String commentId,
    String newText,
  ) async {
    try {
      await _db
          .collection('reels')
          .doc(reelId)
          .collection('comments')
          .doc(commentId)
          .update({
        'text': newText,
        'edited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ReelRepository: Error editing comment: $e');
      rethrow;
    }
  }

  /// Delete comment (soft delete) - Uses batch for atomic operations
  Future<void> deleteComment(String reelId, String commentId) async {
    try {
      final batch = _db.batch();

      // Soft delete comment
      final commentRef = _db
          .collection('reels')
          .doc(reelId)
          .collection('comments')
          .doc(commentId);

      batch.update(commentRef, {
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      // Decrement count
      final reelRef = _db.collection('reels').doc(reelId);
      batch.update(reelRef, {
        'commentCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('ReelRepository: Error deleting comment: $e');
      rethrow;
    }
  }

  /// Like comment - Updates reactions map
  Future<void> likeComment(
    String reelId,
    String commentId,
    String userId,
  ) async {
    try {
      final commentRef = _db
          .collection('reels')
          .doc(reelId)
          .collection('comments')
          .doc(commentId);

      // Get current reactions map
      final commentDoc = await commentRef.get();
      final reactions =
          Map<String, String>.from(commentDoc.data()?['reactions'] ?? {});

      // Add reaction
      reactions[userId] = 'like';

      await commentRef.update({'reactions': reactions});
    } catch (e) {
      debugPrint('ReelRepository: Error liking comment: $e');
      rethrow;
    }
  }

  /// Unlike comment - Removes from reactions map
  Future<void> unlikeComment(
    String reelId,
    String commentId,
    String userId,
  ) async {
    try {
      final commentRef = _db
          .collection('reels')
          .doc(reelId)
          .collection('comments')
          .doc(commentId);

      // Get current reactions map
      final commentDoc = await commentRef.get();
      final reactions =
          Map<String, String>.from(commentDoc.data()?['reactions'] ?? {});

      // Remove reaction
      reactions.remove(userId);

      await commentRef.update({'reactions': reactions});
    } catch (e) {
      debugPrint('ReelRepository: Error unliking comment: $e');
      rethrow;
    }
  }
}
