// lib/services/widget_cache_service.dart
// LRU Cache for feed widgets to optimize memory usage

import 'package:flutter/foundation.dart';
import 'dart:collection';

/// Simple LRU cache for widgets with TTL and memory pressure handling
class WidgetCacheService {
  final int maxSize;
  final Duration? ttl; // Optional TTL for cache entries
  final LinkedHashMap<String, DateTime> _accessOrder = LinkedHashMap();
  final Map<String, int> _accessCounts = {};
  final Map<String, DateTime> _creationTimes = {};

  WidgetCacheService({
    this.maxSize = 20,
    this.ttl, // If null, no TTL enforcement
  });

  /// Mark widget as accessed
  void markAccessed(String widgetId) {
    final now = DateTime.now();

    // Check TTL if enabled
    if (ttl != null && _creationTimes.containsKey(widgetId)) {
      final age = now.difference(_creationTimes[widgetId]!);
      if (age > ttl!) {
        // Entry expired, remove it
        _accessOrder.remove(widgetId);
        _accessCounts.remove(widgetId);
        _creationTimes.remove(widgetId);
        debugPrint('🧹 WidgetCacheService: Removed expired widget: $widgetId');
        return;
      }
    }

    // Update access order
    _accessOrder.remove(widgetId);
    _accessOrder[widgetId] = now;
    _accessCounts[widgetId] = (_accessCounts[widgetId] ?? 0) + 1;

    // Set creation time if not exists
    if (!_creationTimes.containsKey(widgetId)) {
      _creationTimes[widgetId] = now;
    }

    // Evict least recently used items if cache is full
    if (_accessOrder.length > maxSize) {
      final lruKey = _accessOrder.keys.first;
      _accessOrder.remove(lruKey);
      _accessCounts.remove(lruKey);
      _creationTimes.remove(lruKey);
      debugPrint('🧹 WidgetCacheService: Evicted LRU widget: $lruKey');
    }
  }

  /// Clean up expired entries (call periodically)
  void cleanupExpired() {
    if (ttl == null) return;

    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _creationTimes.entries) {
      final age = now.difference(entry.value);
      if (age > ttl!) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _accessOrder.remove(key);
      _accessCounts.remove(key);
      _creationTimes.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      debugPrint(
          '🧹 WidgetCacheService: Cleaned up ${expiredKeys.length} expired entries');
    }
  }

  /// Handle memory pressure by clearing old entries
  void handleMemoryPressure() {
    // Clear 50% of cache when under memory pressure
    final toEvict = (_accessOrder.length / 2).ceil();
    final keysToEvict = _accessOrder.keys.take(toEvict).toList();

    for (final key in keysToEvict) {
      _accessOrder.remove(key);
      _accessCounts.remove(key);
      _creationTimes.remove(key);
    }

    debugPrint(
        '🧹 WidgetCacheService: Handled memory pressure: evicted $toEvict entries');
  }

  /// Check if widget should be kept in memory
  bool shouldKeepInMemory(String widgetId) {
    return _accessOrder.containsKey(widgetId);
  }

  /// Clear cache
  void clear() {
    _accessOrder.clear();
    _accessCounts.clear();
    _creationTimes.clear();
  }

  /// Get cache stats
  Map<String, dynamic> getStats() {
    return {
      'size': _accessOrder.length,
      'maxSize': maxSize,
      'accessCounts': Map<String, int>.from(_accessCounts),
    };
  }
}
