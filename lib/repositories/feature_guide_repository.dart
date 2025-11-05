// lib/repositories/feature_guide_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/feature_guide_model.dart';

class FeatureGuideRepository {
  final FirebaseFirestore _db;

  FeatureGuideRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Get all feature guides
  Future<List<FeatureGuideModel>> getFeatureGuides({int limit = 100}) async {
    try {
      final snapshot = await _db
          .collection('featureGuides')
          .orderBy('featureName')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => FeatureGuideModel.fromDoc(doc))
          .toList();
    } catch (e) {
      debugPrint('FeatureGuideRepository: Error getting guides: $e');
      return [];
    }
  }

  /// Get feature guide by ID
  Future<FeatureGuideModel?> getFeatureGuideById(String featureId) async {
    try {
      final doc = await _db.collection('featureGuides').doc(featureId).get();
      if (!doc.exists) {
        return null;
      }
      return FeatureGuideModel.fromDoc(doc);
    } catch (e) {
      debugPrint('FeatureGuideRepository: Error getting guide: $e');
      return null;
    }
  }

  /// Get guides by category
  Future<List<FeatureGuideModel>> getGuidesByCategory(String category) async {
    try {
      final snapshot = await _db
          .collection('featureGuides')
          .where('category', isEqualTo: category)
          .orderBy('featureName')
          .get();

      return snapshot.docs
          .map((doc) => FeatureGuideModel.fromDoc(doc))
          .toList();
    } catch (e) {
      debugPrint(
          'FeatureGuideRepository: Error getting guides by category: $e');
      return [];
    }
  }

  /// Mark guide as completed for a user
  Future<void> markGuideCompleted(String userId, String featureId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('completedGuides')
          .doc(featureId)
          .set({
        'featureId': featureId,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FeatureGuideRepository: Error marking guide completed: $e');
      rethrow;
    }
  }

  /// Get user's progress (completed guides)
  Future<List<String>> getUserProgress(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('completedGuides')
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('FeatureGuideRepository: Error getting user progress: $e');
      return [];
    }
  }

  /// Check if a guide is completed
  Future<bool> isGuideCompleted(String userId, String featureId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('completedGuides')
          .doc(featureId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('FeatureGuideRepository: Error checking completion: $e');
      return false;
    }
  }

  /// Get user's progress percentage
  Future<Map<String, dynamic>> getUserProgressStats(String userId) async {
    try {
      final allGuides = await getFeatureGuides();
      final completedGuides = await getUserProgress(userId);

      final totalCount = allGuides.length;
      final completedCount = completedGuides.length;
      final percentage =
          totalCount > 0 ? (completedCount / totalCount * 100).round() : 0;

      // Count by category
      final categoryCounts = <String, int>{};
      for (final guide in allGuides) {
        categoryCounts[guide.category] =
            (categoryCounts[guide.category] ?? 0) + 1;
      }

      return {
        'total': totalCount,
        'completed': completedCount,
        'percentage': percentage,
        'byCategory': categoryCounts,
      };
    } catch (e) {
      debugPrint('FeatureGuideRepository: Error getting progress stats: $e');
      return {
        'total': 0,
        'completed': 0,
        'percentage': 0,
        'byCategory': <String, int>{},
      };
    }
  }
}
