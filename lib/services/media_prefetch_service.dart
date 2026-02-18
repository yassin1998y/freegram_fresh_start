import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'package:freegram/models/reel_model.dart';
import 'package:freegram/models/story_media_model.dart';
import 'package:freegram/services/network_quality_service.dart';
import 'package:freegram/services/cache_manager_service.dart';

/// Service for prefetching media content (videos, images) to improve perceived performance.
///
/// This service implements Strategy 1.1 from the Fast Media Loading Implementation Plan:
/// - Prefetches next 2-3 videos in reels feed while user watches current video
/// - Prefetches next 2-3 stories while user views current story
/// - Integrated with ABR: Prefetches the quality matching current network
/// - Network-aware prefetching (only on WiFi/good 4G)
/// - Smart cancellation (cancel if user navigates away)
/// - Memory management with LRU eviction (Phase 3 - Enhanced Reels Optimizations)
class MediaPrefetchService {
  final NetworkQualityService _networkService;
  final CacheManagerService _cacheService;

  // Phase 1.3: Reduced prefetch limit to minimize memory usage
  // Maximum number of prefetched controllers to keep in memory
  // CRITICAL FIX: Set to 0 to prevent memory crashes - disable prefetching for reels
  // Prefetching causes OOM crashes when scrolling quickly
  static const int _maxPrefetchedReelControllers = 0;
  // Increased from 3 to 5 per Stories Improvement Plan requirements
  static const int _maxPrefetchedStoryControllers = 5;

  // LRU cache for reel controllers (LinkedHashMap maintains insertion order)
  // When accessing, we remove and re-add to move to end (most recently used)
  final LinkedHashMap<String, VideoPlayerController?> _prefetchedControllers =
      LinkedHashMap();

  // LRU cache for story controllers
  final LinkedHashMap<String, VideoPlayerController?>
      _prefetchedStoryControllers = LinkedHashMap();

  // This queue helps manage the prefetch order (for reels)
  final Queue<String> _videoQueue = Queue();

  // This queue helps manage story prefetch order
  final Queue<String> _storyVideoQueue = Queue();

  // Track prefetched images to avoid duplicate requests
  final Set<String> _prefetchedImages = {};

  // Track if service is disposed
  bool _isDisposed = false;

  // Phase 4.1: Track active prefetch operations for cancellation
  final Map<String, Future<void>> _activePrefetchOperations = {};
  final Map<String, DateTime> _prefetchStartTimes =
      {}; // Track when prefetch started

  // Phase 4.1: Track prefetch cancellation tokens
  final Map<String, bool> _prefetchCancelled = {};

  MediaPrefetchService({
    required NetworkQualityService networkService,
    required CacheManagerService cacheService,
  })  : _networkService = networkService,
        _cacheService = cacheService;

  /// Prefetch the next few videos in the reels feed.
  ///
  /// Phase 4.1: Enhanced with intelligent prefetch timing:
  /// - Only prefetches when user is actively watching (not paused)
  /// - Cancels prefetch if user scrolls away quickly
  /// - Skips prefetch on fast scrolling
  ///
  /// [reels] - List of reels in the feed
  /// [currentIndex] - Current reel index being viewed
  /// [isVideoPlaying] - Whether the current video is playing (not paused)
  /// [scrollVelocity] - Scroll velocity in pages per second (0 = slow, >2 = fast)
  void prefetchReelsVideos(
    List<ReelModel> reels,
    int currentIndex, {
    bool isVideoPlaying = true,
    double scrollVelocity = 0.0,
  }) {
    // CRITICAL FIX: Disable prefetching completely to prevent memory crashes
    // Prefetching causes OutOfMemoryError when scrolling reels quickly
    // The async disposal and multiple controllers accumulate and exhaust memory
    debugPrint(
        'MediaPrefetchService: Prefetching disabled for reels to prevent OOM crashes');
    _cancelActivePrefetchOperations();
    clearDistantControllers([]); // Clear all prefetched controllers
    return;
  }

  /// CRITICAL FIX: Cancel all active prefetch operations immediately
  void _cancelActivePrefetchOperations() {
    final reelIdsToCancel = _activePrefetchOperations.keys.toList();
    for (final reelId in reelIdsToCancel) {
      _prefetchCancelled[reelId] = true;
      _activePrefetchOperations.remove(reelId);
      _videoQueue.remove(reelId);
      debugPrint('MediaPrefetchService: Cancelled prefetch for $reelId');
    }

    // CRITICAL FIX: Also dispose any controllers that were just initialized
    // This prevents memory leaks when scrolling quickly
    final controllersToDispose = _prefetchedControllers.entries
        .where((entry) => _prefetchCancelled[entry.key] == true)
        .toList();

    for (final entry in controllersToDispose) {
      final controller = _prefetchedControllers.remove(entry.key);
      controller?.dispose();
      _prefetchCancelled.remove(entry.key);
      debugPrint(
          'MediaPrefetchService: Disposed cancelled prefetch controller for ${entry.key}');
    }
  }

  /// Prefetch the next few story videos.
  ///
  /// Call this from StoryViewerScreen when the current story index changes.
  /// This will prefetch the next 1-2 story videos based on current network quality.
  ///
  /// Enhanced with better cleanup logic and reduced prefetching (Phase 3):
  /// - Cleans up controllers far from current position
  /// - Enforces memory limits automatically
  /// - Reduced prefetch count to minimize codec usage
  ///
  /// [stories] - List of StoryMedia objects
  /// [currentIndex] - Current story index being viewed
  void prefetchStoryVideos(List<StoryMedia> stories, int currentIndex) {
    if (_isDisposed) return;
    if (!_networkService.shouldAutoDownloadMedia()) return;

    // CRITICAL FIX: Prevent duplicate prefetch calls
    final prefetchKey = '${stories[currentIndex].storyId}_$currentIndex';
    if (_prefetchStartTimes.containsKey(prefetchKey)) {
      final startTime = _prefetchStartTimes[prefetchKey];
      if (startTime != null &&
          DateTime.now().difference(startTime) < const Duration(seconds: 5)) {
        debugPrint(
            'MediaPrefetchService: Prefetch already in progress for key $prefetchKey, skipping');
        return;
      }
    }

    // Determine which story IDs to keep (current + next few video stories)
    final keepStoryIds = <String>[];
    // Include current story if it's a video
    if (currentIndex < stories.length &&
        stories[currentIndex].mediaType == 'video') {
      keepStoryIds.add(stories[currentIndex].storyId);
    }
    // Add next few video stories (increased from 2 to 3-5)
    for (int i = 1; i <= 5 && (currentIndex + i) < stories.length; i++) {
      final story = stories[currentIndex + i];
      if (story.mediaType == 'video') {
        keepStoryIds.add(story.storyId);
      }
    }

    // Clean up distant controllers (Phase 3 - improved cleanup)
    clearDistantStoryControllers(keepStoryIds);

    // CRITICAL FIX: Mark this prefetch operation as active
    _prefetchStartTimes[prefetchKey] = DateTime.now();

    // Prefetch next 3-5 story videos (increased from 2-3 per plan requirements)
    int prefetchIndex = 0;
    for (int i = 1; i <= 5 && (currentIndex + i) < stories.length; i++) {
      final story = stories[currentIndex + i];
      // Only prefetch videos, not images
      if (story.mediaType == 'video') {
        final storyId = story.storyId;

        // CRITICAL FIX: Only prefetch if not already prefetched, in queue, or being prefetched
        if (!_prefetchedStoryControllers.containsKey(storyId) &&
            !_storyVideoQueue.contains(storyId) &&
            !_prefetchStartTimes.containsKey(storyId)) {
          _storyVideoQueue.add(storyId);
          _prefetchStartTimes[storyId] = DateTime.now();
          prefetchIndex++;
          // Add delay between prefetch operations to prevent codec exhaustion
          Future.delayed(Duration(milliseconds: 500 * prefetchIndex), () {
            if (!_isDisposed) {
              _prefetchStoryVideo(story, storyId);
            }
          });
        } else {
          debugPrint(
              'MediaPrefetchService: Skipping duplicate prefetch for story $storyId');
        }
      }
    }
  }

  /// Prefetch story images for the next few stories.
  ///
  /// Call this from StoryViewerScreen to prefetch upcoming story images.
  ///
  /// [stories] - List of StoryMedia objects
  /// [currentIndex] - Current story index being viewed
  void prefetchStoryImages(List<StoryMedia> stories, int currentIndex) {
    if (_isDisposed) return;
    if (!_networkService.shouldPrefetchImages()) return;

    // Prefetch next 3-5 story images (increased from 2-3 per plan requirements)
    for (int i = 1; i <= 5 && (currentIndex + i) < stories.length; i++) {
      final story = stories[currentIndex + i];
      // Only prefetch images
      if (story.mediaType == 'image' && story.mediaUrl.isNotEmpty) {
        prefetchImage(story.mediaUrl);
      }
      // Also prefetch thumbnail if available
      if (story.thumbnailUrl != null && story.thumbnailUrl!.isNotEmpty) {
        prefetchImage(story.thumbnailUrl!);
      }
    }
  }

  /// Prefetch story preview thumbnails for a list of stories.
  ///
  /// Call this from StoriesTray to prefetch all visible story preview thumbnails.
  ///
  /// [stories] - List of StoryMedia objects to prefetch thumbnails for
  void prefetchStoryThumbnails(List<StoryMedia> stories) {
    if (_isDisposed) return;
    if (!_networkService.shouldPrefetchImages()) return;

    for (final story in stories) {
      // Prefetch thumbnail (preferred) or media URL if no thumbnail
      final urlToPrefetch = story.thumbnailUrl ?? story.mediaUrl;
      if (urlToPrefetch.isNotEmpty) {
        prefetchImage(urlToPrefetch);
      }
    }
  }

  /// Prefetches a single image URL and adds it to the cache.
  ///
  /// This method implements Phase 1.2 of the Fast Media Loading Implementation Plan.
  /// It downloads and caches images before they scroll into view, improving perceived
  /// loading performance in feeds and galleries.
  ///
  /// [imageUrl] - The URL of the image to prefetch
  Future<void> prefetchImage(String imageUrl) async {
    if (_isDisposed) return;

    // If we've already tried this URL, don't try again
    if (_prefetchedImages.contains(imageUrl)) {
      return;
    }

    // Don't prefetch if network is not excellent (images are less critical than videos)
    if (!_networkService.shouldPrefetchImages()) {
      return;
    }

    // Add to set to prevent re-fetching
    _prefetchedImages.add(imageUrl);

    try {
      // Use the cache manager to download the file.
      // This will automatically store it in the cache.
      await _cacheService.manager.downloadFile(imageUrl);
      debugPrint('MediaPrefetchService: Prefetched image $imageUrl');
    } catch (e) {
      debugPrint('MediaPrefetchService: Error prefetching image $imageUrl: $e');
      // If it fails, remove from set so we can retry later
      _prefetchedImages.remove(imageUrl);
    }
  }

  /// Prefetches multiple images at once.
  ///
  /// Useful for prefetching images in a feed or gallery.
  ///
  /// [imageUrls] - List of image URLs to prefetch
  Future<void> prefetchImages(List<String> imageUrls) async {
    if (_isDisposed) return;
    if (!_networkService.shouldPrefetchImages()) return;

    // Prefetch images in parallel (but limit concurrency)
    final futures = imageUrls.map((url) => prefetchImage(url));
    await Future.wait(futures, eagerError: false);
  }

  /// Prefetches a single story video with retry support.
  ///
  /// This method:
  /// 1. Uses ABR logic to get the correct quality URL based on current network
  /// 2. Pre-caches the video file
  /// 3. Pre-initializes the video controller (but doesn't play it)
  /// 4. Handles errors gracefully with retry logic
  Future<void> _prefetchStoryVideo(StoryMedia story, String storyId,
      {int attempt = 1, int maxAttempts = 2}) async {
    if (_isDisposed) return;

    // CRITICAL FIX: Check if already prefetched or being prefetched
    if (_prefetchedStoryControllers.containsKey(storyId)) {
      debugPrint(
          'MediaPrefetchService: Story $storyId already prefetched, skipping');
      _prefetchStartTimes.remove(storyId);
      return;
    }

    // CRITICAL FIX: Check if already in progress (prevent duplicates)
    if (_prefetchStartTimes.containsKey(storyId) && attempt == 1) {
      final startTime = _prefetchStartTimes[storyId];
      if (startTime != null &&
          DateTime.now().difference(startTime) < const Duration(seconds: 30)) {
        debugPrint(
            'MediaPrefetchService: Story $storyId prefetch already in progress, skipping duplicate');
        return;
      }
    }

    try {
      // Add delay before retry (exponential backoff)
      if (attempt > 1) {
        final delayMs =
            (300 * (1 << (attempt - 2))).clamp(300, 1500); // 300ms, 600ms
        debugPrint(
            'MediaPrefetchService: Retrying story prefetch for $storyId (attempt $attempt/$maxAttempts) after ${delayMs}ms delay');
        await Future.delayed(Duration(milliseconds: delayMs));
        if (_isDisposed) return;
      }

      // Use ABR logic to get the RIGHT URL to prefetch based on current network
      final NetworkQuality currentQuality = _networkService.currentQuality;
      final String videoUrlToPrefetch =
          story.getVideoUrlForQuality(currentQuality);

      // 1. Pre-cache the video file using video-specific cache service
      try {
        await _cacheService.videoManager.downloadFile(videoUrlToPrefetch);
        debugPrint(
            'MediaPrefetchService: Successfully cached story video file for $storyId');
      } catch (e) {
        debugPrint(
            'MediaPrefetchService: Error caching story video file for $storyId: $e');
        // Continue even if cache fails, controller can still load from network
      }

      // Check if service was disposed during download
      if (_isDisposed) return;

      // CRITICAL FIX: Always use cached file (never network for prefetched controllers)
      VideoPlayerController controller;
      try {
        // CRITICAL FIX: Enhanced verification - verify downloaded file exists and has valid size
        final File cachedFile =
            await _cacheService.videoManager.getSingleFile(videoUrlToPrefetch);

        if (await cachedFile.exists()) {
          final fileSize = await cachedFile.length();
          // File must be > 1KB to be considered valid (prevents using corrupted/incomplete files)
          if (fileSize > 1024) {
            // ✅ File is cached and valid - use it
            debugPrint(
                'MediaPrefetchService: Using cached file for prefetched story controller $storyId (size: $fileSize bytes)');
            controller = VideoPlayerController.file(cachedFile);
          } else {
            throw Exception('Cached file is invalid (size: $fileSize bytes)');
          }
        } else {
          throw Exception('Cached file does not exist');
        }
      } catch (e) {
        debugPrint(
            'MediaPrefetchService: Error using cached file for story $storyId: $e, skipping prefetch');
        // CRITICAL FIX: Don't create network controller - skip prefetch if cache fails
        // This prevents internet leaks by ensuring we never fall back to network for prefetched content
        _storyVideoQueue.remove(storyId);
        return;
      }

      try {
        await controller.initialize();
      } catch (e) {
        controller.dispose();

        // Check if it's a memory/codec error
        final errorStr = e.toString().toLowerCase();
        final isMemoryError = errorStr.contains('no_memory') ||
            errorStr.contains('memory') ||
            errorStr.contains('codec');

        if (isMemoryError && attempt < maxAttempts) {
          debugPrint(
              'MediaPrefetchService: Memory error prefetching story $storyId, will retry');
          // Retry with exponential backoff
          return _prefetchStoryVideo(story, storyId,
              attempt: attempt + 1, maxAttempts: maxAttempts);
        }

        // If not a memory error or max attempts reached, give up
        debugPrint(
            'MediaPrefetchService: Error initializing story controller for $storyId: $e');
        _storyVideoQueue.remove(storyId);
        return;
      }

      // Check if service was disposed during initialization
      if (_isDisposed) {
        controller.dispose();
        return;
      }

      controller.setLooping(false); // Stories don't loop by default
      controller.pause(); // CRITICAL: Don't play, just get it ready

      // 3. Add to map with memory management (Phase 3)
      _enforceMemoryLimitForStories();
      _prefetchedStoryControllers[storyId] = controller;
      debugPrint(
          'MediaPrefetchService: Successfully prefetched story video $storyId');

      // CRITICAL FIX: Remove from active operations
      _prefetchStartTimes.remove(storyId);
    } catch (e) {
      debugPrint('MediaPrefetchService: Error prefetching story $storyId: $e');
      // Remove from queue and active operations on error
      _storyVideoQueue.remove(storyId);
      _prefetchStartTimes.remove(storyId);
    } finally {
      // CRITICAL FIX: Always clean up
      _storyVideoQueue.remove(storyId);
      _prefetchStartTimes.remove(storyId);
    }
  }

  /// Get a prefetched controller for a specific reel.
  ///
  /// Call this from your ReelsPlayerWidget to get a ready-to-use controller.
  /// This removes the controller from the prefetch map so it's only used once.
  ///
  /// Returns null if no prefetched controller is available for this reel.
  VideoPlayerController? getPrefetchedController(String reelId) {
    if (_isDisposed) return null;

    // Remove and return the controller (LRU behavior - removes from cache)
    final controller = _prefetchedControllers.remove(reelId);
    if (controller != null) {
      debugPrint(
          'MediaPrefetchService: Retrieved prefetched controller for reel $reelId');
    }
    return controller;
  }

  /// Get a prefetched controller for a specific story.
  ///
  /// Call this from StoryViewerScreen to get a ready-to-use controller.
  /// This removes the controller from the prefetch map so it's only used once.
  ///
  /// Returns null if no prefetched controller is available for this story.
  VideoPlayerController? getPrefetchedStoryController(String storyId) {
    if (_isDisposed) return null;

    // Remove and return the controller (LRU behavior - removes from cache)
    final controller = _prefetchedStoryControllers.remove(storyId);
    if (controller != null) {
      debugPrint(
          'MediaPrefetchService: Retrieved prefetched controller for story $storyId');
    }
    return controller;
  }

  /// Check if a controller is already prefetched for a given reel.
  bool hasPrefetchedController(String reelId) {
    return _prefetchedControllers.containsKey(reelId);
  }

  /// Check if a controller is already prefetched for a given story.
  bool hasPrefetchedStoryController(String storyId) {
    return _prefetchedStoryControllers.containsKey(storyId);
  }

  /// Enforce memory limit for reel controllers using LRU eviction (Phase 3).
  ///
  /// When the limit is exceeded, removes the least recently used controllers.
  void _enforceMemoryLimitForReels() {
    if (_isDisposed) return;

    // CRITICAL FIX: Add isEmpty check to prevent "Bad state: no element" crash
    // Remove oldest entries (from front of LinkedHashMap) if over limit
    while (_prefetchedControllers.isNotEmpty &&
        _prefetchedControllers.length >= _maxPrefetchedReelControllers) {
      final oldestKey = _prefetchedControllers.keys.first;
      final controller = _prefetchedControllers.remove(oldestKey);
      controller?.dispose();
      debugPrint(
          'MediaPrefetchService: Evicted reel controller $oldestKey (LRU, limit: $_maxPrefetchedReelControllers)');
    }
  }

  /// Enforce memory limit for story controllers using LRU eviction (Phase 3).
  ///
  /// When the limit is exceeded, removes the least recently used controllers.
  void _enforceMemoryLimitForStories() {
    if (_isDisposed) return;

    // CRITICAL FIX: Add isEmpty check to prevent "Bad state: no element" crash
    // Remove oldest entries (from front of LinkedHashMap) if over limit
    while (_prefetchedStoryControllers.isNotEmpty &&
        _prefetchedStoryControllers.length >= _maxPrefetchedStoryControllers) {
      final oldestKey = _prefetchedStoryControllers.keys.first;
      final controller = _prefetchedStoryControllers.remove(oldestKey);
      controller?.dispose();
      debugPrint(
          'MediaPrefetchService: Evicted story controller $oldestKey (LRU, limit: $_maxPrefetchedStoryControllers)');
    }
  }

  /// Clear prefetched controllers that are far from the current index.
  ///
  /// Enhanced cleanup logic (Phase 3) - Also enforces memory limits.
  /// This helps manage memory by disposing controllers that are unlikely to be used.
  ///
  /// [keepReelIds] - List of reel IDs to keep (current + next few)
  void clearDistantControllers(List<String> keepReelIds) {
    if (_isDisposed || _prefetchedControllers.isEmpty) return;

    // Get IDs to remove (not in keep list)
    final reelIdsToRemove = _prefetchedControllers.keys
        .where((reelId) => !keepReelIds.contains(reelId))
        .toList();

    // Dispose and remove distant controllers
    for (final reelId in reelIdsToRemove) {
      final controller = _prefetchedControllers.remove(reelId);
      controller?.dispose();
      debugPrint(
          'MediaPrefetchService: Cleared distant reel controller $reelId');
    }

    // Also enforce memory limit after cleanup
    _enforceMemoryLimitForReels();
  }

  /// Clear prefetched story controllers that are far from the current index.
  ///
  /// Enhanced cleanup logic (Phase 3) - Also enforces memory limits.
  /// This helps manage memory by disposing story controllers that are unlikely to be used.
  ///
  /// [keepStoryIds] - List of story IDs to keep (current + next few)
  void clearDistantStoryControllers(List<String> keepStoryIds) {
    if (_isDisposed || _prefetchedStoryControllers.isEmpty) return;

    // Get IDs to remove (not in keep list)
    final storyIdsToRemove = _prefetchedStoryControllers.keys
        .where((storyId) => !keepStoryIds.contains(storyId))
        .toList();

    // Dispose and remove distant controllers
    for (final storyId in storyIdsToRemove) {
      final controller = _prefetchedStoryControllers.remove(storyId);
      controller?.dispose();
      debugPrint(
          'MediaPrefetchService: Cleared distant story controller $storyId');
    }

    // Also enforce memory limit after cleanup
    _enforceMemoryLimitForStories();
  }

  /// Get memory usage statistics for debugging (Phase 3).
  ///
  /// Returns a map with counts of prefetched controllers.
  Map<String, int> getMemoryStats() {
    return {
      'prefetchedReelControllers': _prefetchedControllers.length,
      'prefetchedStoryControllers': _prefetchedStoryControllers.length,
      'maxReelControllers': _maxPrefetchedReelControllers,
      'maxStoryControllers': _maxPrefetchedStoryControllers,
      'prefetchedImages': _prefetchedImages.length,
    };
  }

  /// Dispose the service and clean up all resources.
  ///
  /// Call this when the service is no longer needed (e.g., user logs out).
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    _videoQueue.clear();
    _storyVideoQueue.clear();

    // Phase 4.1: Cancel all active prefetch operations
    _cancelActivePrefetchOperations();
    _prefetchCancelled.clear();

    // Dispose all prefetched reel controllers
    for (final controller in _prefetchedControllers.values) {
      controller?.dispose();
    }

    // Dispose all prefetched story controllers
    for (final controller in _prefetchedStoryControllers.values) {
      controller?.dispose();
    }

    _prefetchedControllers.clear();
    _prefetchedStoryControllers.clear();
    _prefetchedImages.clear();
  }
}
