// lib/services/widget_cache_service.dart
// LRU Cache for feed widgets to optimize memory usage

import 'package:flutter/foundation.dart';
import 'dart:collection';

/// Simple LRU cache for widgets
class WidgetCacheService {
  final int maxSize;
  final LinkedHashMap<String, DateTime> _accessOrder = LinkedHashMap();
  final Map<String, int> _accessCounts = {};
  
  WidgetCacheService({this.maxSize = 20});

  /// Mark widget as accessed
  void markAccessed(String widgetId) {
    _accessOrder.remove(widgetId);
    _accessOrder[widgetId] = DateTime.now();
    _accessCounts[widgetId] = (_accessCounts[widgetId] ?? 0) + 1;
    
    // Evict least recently used items if cache is full
    if (_accessOrder.length > maxSize) {
      final lruKey = _accessOrder.keys.first;
      _accessOrder.remove(lruKey);
      _accessCounts.remove(lruKey);
      debugPrint('🧹 WidgetCacheService: Evicted LRU widget: $lruKey');
    }
  }

  /// Check if widget should be kept in memory
  bool shouldKeepInMemory(String widgetId) {
    return _accessOrder.containsKey(widgetId);
  }

  /// Clear cache
  void clear() {
    _accessOrder.clear();
    _accessCounts.clear();
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

