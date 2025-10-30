// lib/services/friend_request_rate_limiter.dart
// Rate limiting service for friend requests (max 50 per day)

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:freegram/models/friend_request_limit.dart';

class FriendRequestRateLimiter {
  static const String _boxName = 'friendRequestLimits';
  static const int maxRequestsPerDay = 50;

  Box<Map<dynamic, dynamic>>? _limitsBox;

  /// Initialize the rate limiter
  Future<void> init() async {
    if (_limitsBox != null && _limitsBox!.isOpen) return;

    try {
      _limitsBox = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
      debugPrint('[FriendRequestRateLimiter] Initialized successfully');
    } catch (e) {
      debugPrint('[FriendRequestRateLimiter] Error initializing: $e');
    }
  }

  /// Check if user can send a friend request
  Future<bool> canSendRequest(String userId) async {
    await init();
    if (_limitsBox == null) return true; // Fail open

    try {
      final limitData = _limitsBox!.get(userId);

      if (limitData == null) {
        debugPrint(
            '[FriendRequestRateLimiter] No limit data for user $userId, allowing request');
        return true;
      }

      final limit = FriendRequestLimit.fromMap(
        Map<String, dynamic>.from(limitData),
      );

      final canSend = limit.canSendRequest(maxPerDay: maxRequestsPerDay);

      if (!canSend) {
        debugPrint(
            '[FriendRequestRateLimiter] User $userId has reached daily limit (${limit.count}/$maxRequestsPerDay)');
      } else {
        debugPrint(
            '[FriendRequestRateLimiter] User $userId can send request (${limit.count}/$maxRequestsPerDay used)');
      }

      return canSend;
    } catch (e) {
      debugPrint('[FriendRequestRateLimiter] Error checking limit: $e');
      return true; // Fail open
    }
  }

  /// Get remaining requests for today
  Future<int> getRemainingRequests(String userId) async {
    await init();
    if (_limitsBox == null) return maxRequestsPerDay;

    try {
      final limitData = _limitsBox!.get(userId);

      if (limitData == null) {
        return maxRequestsPerDay;
      }

      final limit = FriendRequestLimit.fromMap(
        Map<String, dynamic>.from(limitData),
      );

      return limit.remainingRequests(maxPerDay: maxRequestsPerDay);
    } catch (e) {
      debugPrint('[FriendRequestRateLimiter] Error getting remaining: $e');
      return maxRequestsPerDay;
    }
  }

  /// Record a friend request
  Future<void> recordRequest(String userId) async {
    await init();
    if (_limitsBox == null) return;

    try {
      final limitData = _limitsBox!.get(userId);

      FriendRequestLimit limit;
      if (limitData == null) {
        limit = FriendRequestLimit.initial();
      } else {
        limit = FriendRequestLimit.fromMap(
          Map<String, dynamic>.from(limitData),
        );

        // Check if it's a new day - reset if so
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final limitDate =
            DateTime(limit.date.year, limit.date.month, limit.date.day);

        if (today.isAfter(limitDate)) {
          limit = limit.reset();
        }
      }

      // Increment counter
      final newLimit = limit.increment();
      await _limitsBox!.put(userId, newLimit.toMap());

      debugPrint(
          '[FriendRequestRateLimiter] Recorded request for $userId (${newLimit.count}/$maxRequestsPerDay)');
    } catch (e) {
      debugPrint('[FriendRequestRateLimiter] Error recording request: $e');
    }
  }

  /// Reset limit for user (admin function)
  Future<void> resetLimit(String userId) async {
    await init();
    if (_limitsBox == null) return;

    try {
      final limit = FriendRequestLimit.initial();
      await _limitsBox!.put(userId, limit.toMap());
      debugPrint('[FriendRequestRateLimiter] Reset limit for user: $userId');
    } catch (e) {
      debugPrint('[FriendRequestRateLimiter] Error resetting limit: $e');
    }
  }

  /// Get limit info for user
  Future<FriendRequestLimit?> getLimitInfo(String userId) async {
    await init();
    if (_limitsBox == null) return null;

    try {
      final limitData = _limitsBox!.get(userId);

      if (limitData == null) {
        return FriendRequestLimit.initial();
      }

      return FriendRequestLimit.fromMap(
        Map<String, dynamic>.from(limitData),
      );
    } catch (e) {
      debugPrint('[FriendRequestRateLimiter] Error getting limit info: $e');
      return null;
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    try {
      await _limitsBox?.close();
      _limitsBox = null;
      debugPrint('[FriendRequestRateLimiter] Disposed');
    } catch (e) {
      debugPrint('[FriendRequestRateLimiter] Error disposing: $e');
    }
  }
}
