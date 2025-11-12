// lib/services/media/smart_cache_manager.dart

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Smart Cache Manager for media files (images and videos)
///
/// Features:
/// - Dedicated cache configuration for media files
/// - Optimized limits to prevent excessive storage usage
/// - 2-day stale period for media freshness
/// - Maximum 100 cached objects to balance performance and storage
class SmartCacheManager {
  /// Unique cache key for Freegram media cache
  static const String _cacheKey = 'freegram_media_cache';

  /// Maximum number of cache objects (100 as specified)
  static const int _maxNrOfCacheObjects = 100;

  /// Stale period (2 days as specified)
  static const Duration _stalePeriod = Duration(days: 2);

  /// Singleton instance of the cache manager
  static CacheManager? _instance;

  /// Get the singleton instance of SmartCacheManager
  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        _cacheKey,
        stalePeriod: _stalePeriod,
        maxNrOfCacheObjects: _maxNrOfCacheObjects,
      ),
    );
    return _instance!;
  }

  /// Clear the cache (useful for "Pull to Refresh" scenarios)
  static Future<void> clearCache() async {
    await instance.emptyCache();
  }

  /// Get file from cache or download if not cached
  /// Returns a stream that emits FileInfo when the file is ready
  static Stream<FileResponse> getFileStream(String url) {
    return instance.getFileStream(url);
  }

  /// Get file from cache only (returns null if not cached)
  static Future<FileInfo?> getFileFromCache(String url) async {
    return await instance.getFileFromCache(url);
  }

  /// Remove a specific file from cache
  static Future<void> removeFile(String url) async {
    await instance.removeFile(url);
  }
}
