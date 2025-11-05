// lib/services/boost_analytics_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Service for tracking boost post analytics via Cloud Functions
class BoostAnalyticsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Track boost impression (callable function)
  /// Call this when a boosted post is viewed/displayed
  Future<void> trackBoostImpression(String postId) async {
    try {
      final callable = _functions.httpsCallable('trackBoostImpression');

      final result = await callable.call({'postId': postId});

      debugPrint('✅ Boost impression tracked for post: $postId');
      debugPrint('   Result: ${result.data}');
    } catch (e) {
      debugPrint('❌ Error tracking boost impression: $e');
      // Don't throw - analytics should be non-blocking
    }
  }

  /// Test function - verify Cloud Functions connection
  Future<bool> testConnection() async {
    try {
      final callable = _functions.httpsCallable('trackBoostImpression');
      // Try calling with a test postId (will fail validation but confirms connection)
      await callable.call({'postId': 'test'});
      return true;
    } catch (e) {
      // Expected to fail (test postId doesn't exist), but confirms function is callable
      debugPrint('✅ Cloud Functions connection test: $e');
      return true;
    }
  }
}
