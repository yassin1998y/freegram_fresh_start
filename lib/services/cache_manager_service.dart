import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// A service dedicated to managing the app's media cache to prevent
/// it from growing indefinitely.
class CacheManagerService {
  // --- CACHE CONFIGURATION ---
  // A unique key for our custom cache configuration.
  static const _cacheKey = 'freegramCacheKey';
  static const _videoCacheKey = 'freegramVideoCacheKey';

  // The maximum duration a file will be kept in the cache.
  static const Duration _maxCacheAge = Duration(days: 7);
  // Phase 2.1: Video cache with longer retention
  static const Duration _maxVideoCacheAge = Duration(days: 30);
  
  // The maximum number of files to store in the cache.
  // When this limit is reached, the oldest files are removed.
  static const int _maxCacheObjects = 500;
  // Phase 2.1: Video cache with smaller limit (videos are larger)
  static const int _maxVideoCacheObjects = 100;

  // Create a static instance of the configuration.
  static final CacheManager _cacheManager = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: _maxCacheAge,
      maxNrOfCacheObjects: _maxCacheObjects,
    ),
  );

  // Phase 2.1: Video-specific cache manager with longer retention
  static final CacheManager _videoCacheManager = CacheManager(
    Config(
      _videoCacheKey,
      stalePeriod: _maxVideoCacheAge,
      maxNrOfCacheObjects: _maxVideoCacheObjects,
    ),
  );

  /// Exposes the configured cache manager instance for other parts of the app to use.
  BaseCacheManager get manager => _cacheManager;
  
  /// Phase 2.1: Exposes the video-specific cache manager for video files.
  BaseCacheManager get videoManager => _videoCacheManager;

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

