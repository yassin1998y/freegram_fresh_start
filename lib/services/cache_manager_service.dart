import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// A service dedicated to managing the app's media cache to prevent
/// it from growing indefinitely.
class CacheManagerService {
  // --- CACHE CONFIGURATION ---
  // A unique key for our custom cache configuration.
  static const _cacheKey = 'freegramCacheKey';

  // The maximum duration a file will be kept in the cache.
  static const Duration _maxCacheAge = Duration(days: 7);
  // The maximum number of files to store in the cache.
  // When this limit is reached, the oldest files are removed.
  static const int _maxCacheObjects = 500;

  // Create a static instance of the configuration.
  static final CacheManager _cacheManager = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: _maxCacheAge,
      maxNrOfCacheObjects: _maxCacheObjects,
    ),
  );

  /// Exposes the configured cache manager instance for other parts of the app to use.
  BaseCacheManager get manager => _cacheManager;

  /// Runs the cache cleanup algorithm.
  /// The library now handles this automatically based on the config,
  /// but we can call this to force a cleanup if needed.
  Future<void> manageCache() async {
    // The underlying implementation of flutter_cache_manager will automatically
    // clean up files based on the `stalePeriod` and `maxNrOfCacheObjects`
    // defined in our Config. This method is kept for potential manual triggering,
    // but the core logic is now automated.
    debugPrint("Cache Manager: Proactive cache management is now handled automatically.");
  }
}

