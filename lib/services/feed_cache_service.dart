// lib/services/feed_cache_service.dart
// Feed Cache Service for offline support
// Caches last 50 posts for offline viewing

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/models/post_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedCacheService {
  static const String _boxName = 'feedCache';
  static const String _cacheTimestampKey = 'lastCacheTime';
  static const int _maxCachedPosts = 50;
  static const Duration _cacheExpiry = Duration(days: 7);

  Box<Map<dynamic, dynamic>>? _cacheBox;
  bool _isInitialized = false;

  /// Initialize the cache service
  Future<void> init() async {
    if (_isInitialized && _cacheBox != null && _cacheBox!.isOpen) return;

    try {
      _cacheBox = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
      _isInitialized = true;
      debugPrint('[FeedCacheService] Cache initialized successfully');
      
      // Clean up expired cache
      _cleanupExpiredCache();
    } catch (e) {
      debugPrint('[FeedCacheService] Error initializing cache: $e');
      _isInitialized = false;
    }
  }

  /// Cache feed items
  Future<void> cacheFeedItems(List<FeedItem> items) async {
    await init();
    if (_cacheBox == null) return;

    try {
      // Filter only post items (ads and suggestions don't need offline caching)
      final postItems = items.whereType<PostFeedItem>().take(_maxCachedPosts).toList();
      
      // Clear old cache
      await _cacheBox!.clear();
      
      // Store each post
      for (int i = 0; i < postItems.length; i++) {
        final postItem = postItems[i];
        final postMap = postItem.post.toMap();
        
        // Convert Timestamp objects to cacheable format
        final cacheableMap = _convertForCache(postMap);
        await _cacheBox!.put('post_$i', cacheableMap);
      }
      
      // Store metadata as maps for Hive compatibility
      await _cacheBox!.put('postCount', {'value': postItems.length});
      await _cacheBox!.put(_cacheTimestampKey, {'value': DateTime.now().toIso8601String()});
      
      debugPrint('[FeedCacheService] Cached ${postItems.length} posts');
    } catch (e) {
      debugPrint('[FeedCacheService] Error caching feed: $e');
    }
  }

  /// Get cached feed items
  Future<List<FeedItem>> getCachedFeedItems() async {
    await init();
    if (_cacheBox == null) return [];

    try {
      final postCountData = _cacheBox!.get('postCount');
      final postCount = postCountData is Map ? (postCountData['value'] as int? ?? 0) : 0;
      if (postCount == 0) return [];

      final cachedPosts = <PostFeedItem>[];
      
      for (int i = 0; i < postCount; i++) {
        final postData = _cacheBox!.get('post_$i');
        if (postData is Map) {
          try {
            // Convert Map<dynamic, dynamic> to Map<String, dynamic> and restore Timestamps
            final postMap = postData.map((key, value) => MapEntry(key.toString(), value));
            final restoredMap = _restoreFromCache(postMap);
            
            // Use postId from the map or generate from index
            final postId = restoredMap['postId'] as String? ?? 'cached_post_$i';
            final post = PostModel.fromMap(postId, restoredMap);
            cachedPosts.add(PostFeedItem(post: post));
          } catch (e) {
            debugPrint('[FeedCacheService] Error parsing cached post $i: $e');
          }
        }
      }

      debugPrint('[FeedCacheService] Retrieved ${cachedPosts.length} cached posts');
      return cachedPosts;
    } catch (e) {
      debugPrint('[FeedCacheService] Error getting cached feed: $e');
      return [];
    }
  }

  /// Get last cache timestamp
  DateTime? getLastCacheTime() {
    if (_cacheBox == null) return null;

    try {
      final timestampData = _cacheBox!.get(_cacheTimestampKey);
      final timestampStr = timestampData is Map ? timestampData['value'] as String? : null;
      if (timestampStr != null) {
        return DateTime.parse(timestampStr);
      }
    } catch (e) {
      debugPrint('[FeedCacheService] Error getting cache timestamp: $e');
    }
    return null;
  }

  /// Check if cache is valid (not expired)
  bool isCacheValid() {
    final lastCacheTime = getLastCacheTime();
    if (lastCacheTime == null) return false;

    final age = DateTime.now().difference(lastCacheTime);
    return age < _cacheExpiry;
  }

  /// Clean up expired cache
  Future<void> _cleanupExpiredCache() async {
    if (_cacheBox == null) return;

    try {
      if (!isCacheValid()) {
        await _cacheBox!.clear();
        debugPrint('[FeedCacheService] Cleaned up expired cache');
      }
    } catch (e) {
      debugPrint('[FeedCacheService] Error cleaning cache: $e');
    }
  }

  /// Clear all cache
  Future<void> clearCache() async {
    await init();
    if (_cacheBox == null) return;

    try {
      await _cacheBox!.clear();
      debugPrint('[FeedCacheService] Cache cleared');
    } catch (e) {
      debugPrint('[FeedCacheService] Error clearing cache: $e');
    }
  }

  /// Convert map with Timestamps to cacheable format
  Map<String, dynamic> _convertForCache(Map<String, dynamic> map) {
    final converted = <String, dynamic>{};
    for (final entry in map.entries) {
      if (entry.value is Timestamp) {
        final timestamp = entry.value as Timestamp;
        converted[entry.key] = {
          '_type': 'timestamp',
          'seconds': timestamp.seconds,
          'nanoseconds': timestamp.nanoseconds,
        };
      } else if (entry.value is Map) {
        converted[entry.key] = _convertForCache(Map<String, dynamic>.from(entry.value));
      } else if (entry.value is List) {
        converted[entry.key] = (entry.value as List).map((item) {
          if (item is Map) {
            return _convertForCache(Map<String, dynamic>.from(item));
          } else if (item is Timestamp) {
            return {
              '_type': 'timestamp',
              'seconds': item.seconds,
              'nanoseconds': item.nanoseconds,
            };
          }
          return item;
        }).toList();
      } else {
        converted[entry.key] = entry.value;
      }
    }
    return converted;
  }

  /// Restore map from cache format (convert timestamp strings back to Timestamps)
  Map<String, dynamic> _restoreFromCache(Map<String, dynamic> map) {
    final restored = <String, dynamic>{};
    for (final entry in map.entries) {
      if (entry.value is Map) {
        final valueMap = entry.value as Map;
        if (valueMap['_type'] == 'timestamp') {
          restored[entry.key] = Timestamp(
            valueMap['seconds'] as int,
            valueMap['nanoseconds'] as int,
          );
        } else {
          restored[entry.key] = _restoreFromCache(Map<String, dynamic>.from(entry.value));
        }
      } else if (entry.value is List) {
        restored[entry.key] = (entry.value as List).map((item) {
          if (item is Map) {
            final itemMap = Map<String, dynamic>.from(item);
            if (itemMap['_type'] == 'timestamp') {
              return Timestamp(
                itemMap['seconds'] as int,
                itemMap['nanoseconds'] as int,
              );
            }
            return _restoreFromCache(itemMap);
          }
          return item;
        }).toList();
      } else {
        restored[entry.key] = entry.value;
      }
    }
    return restored;
  }

  /// Dispose cache service
  Future<void> dispose() async {
    try {
      await _cacheBox?.close();
      _isInitialized = false;
    } catch (e) {
      debugPrint('[FeedCacheService] Error disposing cache: $e');
    }
  }
}

