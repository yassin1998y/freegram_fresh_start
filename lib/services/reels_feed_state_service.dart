// lib/services/reels_feed_state_service.dart
// Service to preserve ReelsFeedScreen scroll position and state

import 'package:flutter/foundation.dart';

/// Service to preserve ReelsFeedScreen state across navigation
class ReelsFeedStateService {
  static final ReelsFeedStateService _instance = ReelsFeedStateService._internal();
  factory ReelsFeedStateService() => _instance;
  ReelsFeedStateService._internal();

  // Store the last scroll position (current index)
  int? _lastScrollIndex;
  
  // Store timestamp of last navigation away
  DateTime? _lastNavigationAwayTime;
  
  // Time threshold: if navigating back within 5 minutes, restore position
  static const _restoreThreshold = Duration(minutes: 5);

  /// Save the current scroll position when navigating away
  void saveScrollPosition(int index) {
    _lastScrollIndex = index;
    _lastNavigationAwayTime = DateTime.now();
    debugPrint('ReelsFeedStateService: Saved scroll position: $index');
  }

  /// Get the saved scroll position if still valid
  int? getSavedScrollPosition() {
    if (_lastScrollIndex == null || _lastNavigationAwayTime == null) {
      return null;
    }

    // Check if the saved position is still valid (within threshold)
    final timeSinceAway = DateTime.now().difference(_lastNavigationAwayTime!);
    if (timeSinceAway > _restoreThreshold) {
      // Too much time has passed, don't restore
      debugPrint('ReelsFeedStateService: Saved position expired (${timeSinceAway.inMinutes} minutes)');
      _lastScrollIndex = null;
      _lastNavigationAwayTime = null;
      return null;
    }

    debugPrint('ReelsFeedStateService: Restoring scroll position: $_lastScrollIndex');
    return _lastScrollIndex;
  }

  /// Clear the saved scroll position
  void clearScrollPosition() {
    _lastScrollIndex = null;
    _lastNavigationAwayTime = null;
    debugPrint('ReelsFeedStateService: Cleared scroll position');
  }
}

