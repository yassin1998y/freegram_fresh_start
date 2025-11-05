// lib/services/analytics_service.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Analytics Service for tracking user interactions using Firebase Analytics
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Track tab switch event
  Future<void> trackTabSwitch(String tabName) async {
    try {
      await _analytics.logEvent(
        name: 'feed_tab_switch',
        parameters: {
          'tab_name': tabName,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      if (kDebugMode) {
        debugPrint('📊 Analytics: Tab switched to $tabName');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📊 Analytics Error (tab switch): $e');
      }
    }
  }

  /// Track ad impression
  Future<void> trackAdImpression(String adId, String adType) async {
    try {
      await _analytics.logEvent(
        name: 'ad_impression',
        parameters: {
          'ad_id': adId,
          'ad_type': adType,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      if (kDebugMode) {
        debugPrint('📊 Analytics: Ad impression - ID: $adId, Type: $adType');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📊 Analytics Error (ad impression): $e');
      }
    }
  }

  /// Track suggestion carousel interaction
  Future<void> trackSuggestionCarouselInteraction(
      String action, String suggestionType) async {
    try {
      await _analytics.logEvent(
        name: 'suggestion_interaction',
        parameters: {
          'action': action,
          'suggestion_type': suggestionType,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      if (kDebugMode) {
        debugPrint(
            '📊 Analytics: Suggestion carousel - Action: $action, Type: $suggestionType');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📊 Analytics Error (suggestion interaction): $e');
      }
    }
  }

  /// Track suggestion follow action
  Future<void> trackSuggestionFollow(
      String suggestionId, String suggestionType) async {
    try {
      await _analytics.logEvent(
        name: 'suggestion_follow',
        parameters: {
          'suggestion_id': suggestionId,
          'suggestion_type': suggestionType,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      if (kDebugMode) {
        debugPrint(
            '📊 Analytics: Suggestion followed - ID: $suggestionId, Type: $suggestionType');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📊 Analytics Error (suggestion follow): $e');
      }
    }
  }

  /// Track suggestion carousel dismiss
  Future<void> trackSuggestionCarouselDismiss(String suggestionType) async {
    try {
      await _analytics.logEvent(
        name: 'suggestion_dismiss',
        parameters: {
          'suggestion_type': suggestionType,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      if (kDebugMode) {
        debugPrint(
            '📊 Analytics: Suggestion carousel dismissed - Type: $suggestionType');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📊 Analytics Error (suggestion dismiss): $e');
      }
    }
  }
}
