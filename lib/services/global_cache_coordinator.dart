import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/models/story_media_model.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/models/hive/nearby_user.dart';
import 'package:freegram/models/user_model.dart'; // Added for Leaderboard
// Note: StoryMediaModel is likely the file name, but class is StoryMedia based on inspection.
// If StoryMediaModel class exists elsewhere, I should check, but based on inspection it is StoryMedia.

class GlobalCacheCoordinator {
  static const String _feedBoxName = 'feedCache';
  static const String _reelsBoxName = 'reelsCache';
  static const String _storiesBoxName = 'storiesCache';
  static const String _storeBoxName = 'storeCache';
  static const String _userBoxName = 'userCache'; // Added for Leaderboard

  static const int _maxCachedItems = 50; // Strict 50-item limit
  static const int _maxLeaderboardItems = 100; // Special limit for leaderboard
  static const Duration _cacheExpiry = Duration(days: 7);

  Box<Map<dynamic, dynamic>>? _feedBox;
  Box<Map<dynamic, dynamic>>? _reelsBox;
  Box<Map<dynamic, dynamic>>? _storiesBox;
  Box<Map<dynamic, dynamic>>? _storeBox;
  Box<Map<dynamic, dynamic>>? _userBox; // Added for Leaderboard
  Box<NearbyUser>? _nearbyBox;
  static const String _nearbyBoxName = 'nearbyUsers';

  bool _isInitialized = false;

  // Singleton instance
  static final GlobalCacheCoordinator _instance =
      GlobalCacheCoordinator._internal();

  factory GlobalCacheCoordinator() => _instance;

  GlobalCacheCoordinator._internal();

  /// Initialize the cache service and open boxes
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Open all boxes
      await Future.wait([
        Hive.openBox<Map<dynamic, dynamic>>(_feedBoxName)
            .then((box) => _feedBox = box),
        Hive.openBox<Map<dynamic, dynamic>>(_reelsBoxName)
            .then((box) => _reelsBox = box),
        Hive.openBox<Map<dynamic, dynamic>>(_storiesBoxName)
            .then((box) => _storiesBox = box),
        Hive.openBox<Map<dynamic, dynamic>>(_storeBoxName)
            .then((box) => _storeBox = box),
        Hive.openBox<NearbyUser>(_nearbyBoxName)
            .then((box) => _nearbyBox = box),
        Hive.openBox<Map<dynamic, dynamic>>(
                _userBoxName) // Added for Leaderboard
            .then((box) => _userBox = box),
      ]);

      _isInitialized = true;
      debugPrint(
          '[GlobalCacheCoordinator] *All* cache boxes initialized successfully');

      // Cleanup expired items on init
      _cleanupExpiredCache();
    } catch (e) {
      debugPrint('[GlobalCacheCoordinator] Error initializing cache: $e');
      _isInitialized = false;
    }
  }

  /// Generic method to cache items
  /// Handles PostModel, ReelModel, and StoryMedia
  Future<void> cacheItems<T>(List<T> items) async {
    if (!_isInitialized) await init();

    Box<Map<dynamic, dynamic>>? targetBox;
    String prefix;

    if (T == PostModel) {
      targetBox = _feedBox;
      prefix = 'post';
    } else if (T == ReelModel) {
      targetBox = _reelsBox;
      prefix = 'reel';
    } else if (T == StoryMedia) {
      targetBox = _storiesBox;
      prefix = 'story';
    } else if (T == GiftModel) {
      targetBox = _storeBox;
      prefix = 'gift';
    } else if (T == UserModel) {
      // Added for Leaderboard
      targetBox = _userBox;
      prefix = 'user';
    } else if (T == NearbyUser) {
      targetBox = null;
      prefix = 'nearby';
    } else {
      debugPrint('[GlobalCacheCoordinator] Unsupported type for caching: $T');
      return;
    }

    if (targetBox == null && T != NearbyUser) return;

    if (T == NearbyUser) {
      if (_nearbyBox == null) return;
      try {
        for (var item in items) {
          if (item is NearbyUser) {
            await _nearbyBox!.put(item.uidShort, item);
          }
        }
        debugPrint(
            '[GlobalCacheCoordinator] Cached ${items.length} items of type $T');
      } catch (e) {
        debugPrint('[GlobalCacheCoordinator] Error caching items for $T: $e');
      }
      return;
    }

    try {
      // 1. Convert new items to maps
      final Map<String, Map<String, dynamic>> newItemsMap = {};
      final List<String> newIds = [];

      for (var item in items) {
        String id;
        Map<String, dynamic> data;

        if (item is PostModel) {
          id = item.id;
          data = item.toMap();
        } else if (item is ReelModel) {
          id = item.reelId;
          data = item.toMap();
        } else if (item is StoryMedia) {
          id = item.storyId;
          data = item.toMap();
        } else if (item is GiftModel) {
          id = item.id;
          data = item.toMap();
        } else if (item is UserModel) {
          // Added for Leaderboard
          id = item.id;
          data = item.toMap();
        } else {
          continue;
        }

        // Ensure metadata (thumbnailUrl) is present (checking logic if needed, but mainly relying on toMap)
        // Note: Models already include thumbnailUrl in toMap if it exists.

        newItemsMap[id] = _convertForCache(data);
        newIds.add(id);
      }

      // 2. Manage LRU mechanism
      // Get current access order or strict list
      // We store a list of IDs to maintain order.
      // Format: 'access_order' -> ['id1', 'id2', ...] (Newest at end)

      List<String> currentOrder = [];
      final orderData = targetBox!.get('access_order');
      if (orderData != null && orderData['value'] is List) {
        currentOrder = List<String>.from(orderData['value']);
      }

      // Remove new IDs from current order if they exist (refreshing them)
      for (var id in newIds) {
        currentOrder.remove(id);
      }

      // Add new IDs to the end (most recently used)
      currentOrder.addAll(newIds);

      // Check if we exceed limit
      final int maxItems =
          T == UserModel ? _maxLeaderboardItems : _maxCachedItems;

      if (currentOrder.length > maxItems) {
        // Remove from start (least recently used)
        final int toRemoveCount = currentOrder.length - maxItems;
        final List<String> toRemove = currentOrder.sublist(0, toRemoveCount);
        currentOrder = currentOrder.sublist(toRemoveCount);

        // Delete evicted items from box
        await targetBox.deleteAll(toRemove.map((id) => '${prefix}_$id'));
        debugPrint(
            '[GlobalCacheCoordinator] Evicted ${toRemove.length} items from $T cache');
      }

      // 3. Save new items
      final Map<dynamic, Map<dynamic, dynamic>> batch = {};
      for (var entry in newItemsMap.entries) {
        batch['${prefix}_${entry.key}'] = entry.value;
      }

      // Update access order and timestamp
      batch['access_order'] = {'value': currentOrder};
      batch['last_cache_time'] = {'value': DateTime.now().toIso8601String()};

      await targetBox.putAll(batch);

      debugPrint(
          '[GlobalCacheCoordinator] Cached ${items.length} items of type $T');
    } catch (e) {
      debugPrint('[GlobalCacheCoordinator] Error caching items for $T: $e');
    }
  }

  /// Generic method to get cached items
  Future<List<T>> getCachedItems<T>() async {
    if (!_isInitialized) await init();

    Box<Map<dynamic, dynamic>>? targetBox;
    String prefix;

    if (T == PostModel) {
      targetBox = _feedBox;
      prefix = 'post';
    } else if (T == ReelModel) {
      targetBox = _reelsBox;
      prefix = 'reel';
    } else if (T == StoryMedia) {
      targetBox = _storiesBox;
      prefix = 'story';
    } else if (T == GiftModel) {
      targetBox = _storeBox;
      prefix = 'gift';
    } else if (T == NearbyUser) {
      // Nearby Users are special: return all from box directly (not using LRU map for now)
      if (_nearbyBox == null) return [];
      try {
        final users = _nearbyBox!.values.toList();
        // Return sorted by lastSeen desc
        users.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
        return users as List<T>;
      } catch (e) {
        debugPrint('[GlobalCacheCoordinator] Error fetching nearby users: $e');
        return [];
      }
    } else {
      return [];
    }

    if (targetBox == null) return [];

    try {
      List<String> order = [];
      final orderData = targetBox.get('access_order');
      if (orderData != null && orderData['value'] is List) {
        order = List<String>.from(orderData['value']);
      }

      // We want most recent first for the UI usually, but LRU keeps most recent at end.
      // Access order: [oldest, ..., newest] mechanism.
      // So detailed list should probably be reversed if we want newest first,
      // OR we just assume the generic "order" is correct for display?
      // Typically feeds are chronological or ranked. Cache just stores them.
      // Let's return them in the order they are stored in 'access_order' (which is LRU order).
      // Use cases can sort them mainly by their own timestamp if needed.
      // However, usually "cached feed" implies "last seen feed".
      // If we blindly return LRU order (access based), it might be shuffled if user engaged with random old items.
      // Use case: Offline feed. We want to show what was there.
      // For simplicity, we return all cached items, checking validity.

      final List<T> results = [];

      // Iterate in reverse order of access (most recently added/accessed first)?
      // Or just return all and let Bloc sort? Bloc logic usually sorts by score or timestamp.
      // I'll return them in the order they are in the access list (Oldest to Newest access).
      // Actually, for "feed", usually we want the list as it was cached.
      // But we are caching individual items.
      // I will return the list as is.

      for (var id in order.reversed) {
        // Newest accessed first
        final key = '${prefix}_$id';
        final data = targetBox.get(key);

        if (data != null) {
          try {
            // Convert Map<dynamic, dynamic> to Map<String, dynamic> and restore Timestamps
            final dataMap = data.map((k, v) => MapEntry(k.toString(), v));
            final restoredMap = _restoreFromCache(dataMap);

            if (T == PostModel) {
              results.add(PostModel.fromMap(id, restoredMap) as T);
            } else if (T == ReelModel) {
              results.add(ReelModel.fromMap(id, restoredMap) as T);
            } else if (T == StoryMedia) {
              results.add(StoryMedia.fromMap(id, restoredMap) as T);
            } else if (T == GiftModel) {
              results.add(GiftModel.fromMap(id, restoredMap) as T);
            } else if (T == UserModel) {
              // Added for Leaderboard
              results.add(UserModel.fromMap(id, restoredMap) as T);
            }
          } catch (e) {
            debugPrint(
                '[GlobalCacheCoordinator] Error parsing cached $T ($id): $e');
          }
        }
      }

      debugPrint(
          '[GlobalCacheCoordinator] Retrieved ${results.length} cached items of type $T');
      return results;
    } catch (e) {
      debugPrint('[GlobalCacheCoordinator] Error retrieving cache for $T: $e');
      return [];
    }
  }

  /// Get last cache timestamp for a specific type
  DateTime? getLastCacheTime<T>() {
    Box<Map<dynamic, dynamic>>? targetBox;
    if (T == PostModel) {
      targetBox = _feedBox;
    } else if (T == ReelModel) {
      targetBox = _reelsBox;
    } else if (T == StoryMedia) {
      targetBox = _storiesBox;
    } else if (T == GiftModel) {
      targetBox = _storeBox;
    }

    if (targetBox == null) return null;

    final data = targetBox.get('last_cache_time');
    if (data != null && data['value'] != null) {
      return DateTime.tryParse(data['value']);
    }
    return null;
  }

  /// Clear cache for a specific type
  Future<void> clearCache<T>() async {
    if (!_isInitialized) await init();

    Box<Map<dynamic, dynamic>>? targetBox;
    if (T == PostModel) {
      targetBox = _feedBox;
    } else if (T == ReelModel) {
      targetBox = _reelsBox;
    } else if (T == StoryMedia) {
      targetBox = _storiesBox;
    } else if (T == GiftModel) {
      targetBox = _storeBox;
    }

    await targetBox?.clear();
  }

  /// Internal: Cleanup expired caches
  Future<void> _cleanupExpiredCache() async {
    await _checkAndClear(_feedBox);
    await _checkAndClear(_reelsBox);
    await _checkAndClear(_storiesBox);
    await _checkAndClear(_storeBox);
    await _checkAndClear(_userBox);
    await _checkAndClearNearby(_nearbyBox);
  }

  Future<void> _checkAndClear(Box<Map<dynamic, dynamic>>? box) async {
    if (box == null) return;

    final data = box.get('last_cache_time');
    if (data != null && data['value'] != null) {
      final time = DateTime.tryParse(data['value']);
      if (time != null && DateTime.now().difference(time) > _cacheExpiry) {
        await box.clear();
        debugPrint(
            '[GlobalCacheCoordinator] Cleared expired cache box: ${box.name}');
      }
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
        converted[entry.key] =
            _convertForCache(Map<String, dynamic>.from(entry.value));
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
          restored[entry.key] =
              _restoreFromCache(Map<String, dynamic>.from(entry.value));
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

  Future<void> _checkAndClearNearby(Box<NearbyUser>? box) async {
    if (box == null) return;
    try {
      final now = DateTime.now();
      final expiredKeys = box.keys.where((key) {
        final user = box.get(key);
        if (user == null) return true;
        return now.difference(user.foundAt).inHours >= 24;
      }).toList();

      if (expiredKeys.isNotEmpty) {
        await box.deleteAll(expiredKeys);
        debugPrint(
            '[GlobalCacheCoordinator] Cleared ${expiredKeys.length} expired nearby users');
      }
    } catch (e) {
      debugPrint('[GlobalCacheCoordinator] Error clearing nearby cache: $e');
    }
  }
}
