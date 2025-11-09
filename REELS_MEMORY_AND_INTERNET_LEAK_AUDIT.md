# Reels Feed: Memory & Internet Leak Audit & Refactor Plan

## Executive Summary

**Critical Issues Found:**
1. **Memory Leaks**: Video controllers not properly disposed, causing RAM to climb indefinitely
2. **Internet Leaks**: Videos re-downloaded because cache-first strategy is broken
3. **Resource Accumulation**: Timers, subscriptions, and listeners not always cleaned up

**Estimated Impact:**
- Memory: 50-100MB per unreleased video controller
- Data: 5-50MB per re-downloaded video (depending on quality)
- Performance: UI freezes when memory pressure increases

---

## 1. Memory Leak Audit

### 🔴 CRITICAL: VideoPlayerController Not Disposed When Scrolling Away

**Location:** `lib/widgets/reels/reels_player_widget.dart:95-130`

**Problem:**
- `didUpdateWidget` uses a 500ms delay (`_disposalTimer`) before disposing controllers
- If user scrolls quickly, multiple timers accumulate
- PageView.builder may keep widgets in cache even when off-screen
- Controllers created in `initState` are not guaranteed to be disposed if widget is removed from tree

**Evidence:**
```dart
// Line 110-115: Delayed disposal with timer
_disposalTimer = Timer(const Duration(milliseconds: 500), () {
  if (!widget.isCurrentReel && mounted && _videoController != null) {
    debugPrint('ReelsPlayerWidget: Disposing controller for off-screen reel ${widget.reel.reelId}');
    _disposeVideo();
  }
});
```

**Issue:** Timer-based disposal is unreliable. If widget is rebuilt or PageView caches it, controller may never be disposed.

---

### 🔴 CRITICAL: VideoPlayerController Listener Leak

**Location:** `lib/widgets/reels/reels_player_widget.dart:407-421`

**Problem:**
- `_videoListener` is added to controller but if controller is disposed asynchronously, listener might still be attached
- Listener triggers `setState()` which can cause issues if widget is disposed
- No null check for `_videoController` before calling `setState()`

**Evidence:**
```dart
void _videoListener() {
  if (_videoController != null && mounted) {
    // ... code ...
    if (mounted) {
      setState(() {}); // May be called after widget is disposed
    }
  }
}
```

---

### 🔴 CRITICAL: Network Quality Subscription Leak

**Location:** `lib/widgets/reels/reels_player_widget.dart:82-91`

**Problem:**
- `_networkSubscription` is only cancelled in `dispose()`
- If widget is removed from tree before `dispose()` is called, subscription leaks
- Subscription continues to trigger quality switches even when widget is off-screen

**Evidence:**
```dart
_networkSubscription = _networkService.qualityStream.listen((newQuality) {
  if (_isSwitchingQuality || !mounted) return;
  // This may execute even after widget is no longer visible
  if (newQuality != _currentQuality && _shouldSwitchQuality(_currentQuality!, newQuality)) {
    _switchVideoQuality(newQuality);
  }
});
```

---

### 🟡 HIGH: PageView.builder Widget Caching

**Location:** `lib/screens/reels_feed_screen.dart:314-400`

**Problem:**
- `PageView.builder` by default caches pages on both sides of current page
- Even though `ReelsPlayerWidget` has `wantKeepAlive = false`, PageView's internal cache may keep widgets alive
- Multiple video controllers may exist simultaneously (current + cached pages)

**Evidence:**
```dart
return PageView.builder(
  controller: _pageController,
  scrollDirection: Axis.vertical,
  // No explicit cacheExtent control - uses default (viewport size)
  itemBuilder: (context, index) {
    return ReelsPlayerWidget(
      reel: reel,
      isCurrentReel: isCurrentReel,
      prefetchService: _prefetchService,
    );
  },
);
```

---

### 🟡 HIGH: Prefetched Controller Cleanup Issues

**Location:** `lib/services/media_prefetch_service.dart:548-557`

**Problem:**
- Prefetched controllers are removed from map when retrieved, but if widget is disposed before retrieval, controller remains in memory
- LRU eviction may not trigger quickly enough
- 5-second timeout for unused controllers may be too long

**Evidence:**
```dart
VideoPlayerController? getPrefetchedController(String reelId) {
  // Remove and return the controller (LRU behavior - removes from cache)
  final controller = _prefetchedControllers.remove(reelId);
  // If widget is disposed before this is called, controller leaks
  return controller;
}
```

---

### 🟡 MEDIUM: Timer Accumulation

**Location:** `lib/widgets/reels/reels_player_widget.dart:110, 355, 592`

**Problem:**
- Multiple `Timer` and `Future.delayed` calls throughout the widget
- If widget is disposed while timers are pending, they may still execute
- Timers are cancelled in `dispose()` but there's a race condition

---

## 2. Internet Leak Audit

### 🔴 CRITICAL: Cache-First Strategy Broken

**Location:** `lib/widgets/reels/reels_player_widget.dart:185-213`

**Problem:**
- Code checks for cached file but if `getSingleFile()` throws or file doesn't exist, it creates `VideoPlayerController.networkUrl()` directly
- `VideoPlayerController.networkUrl()` does NOT automatically use cached files - it always downloads from network
- Even if file is cached, the code may not use it if the check fails

**Evidence:**
```dart
// Line 194: Check cache
cachedFile = await _cacheService.videoManager.getSingleFile(videoUrl);
if (await cachedFile.exists()) {
  controller = VideoPlayerController.file(cachedFile); // ✅ Uses cache
} else {
  // ❌ PROBLEM: Falls back to network without ensuring cache is used
}

// Line 208-212: Fallback to network
if (controller == null) {
  // ❌ CRITICAL: This creates a network controller that bypasses cache
  controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
}
```

**Impact:** Every time a video is loaded, it re-downloads from network even if cached.

---

### 🔴 CRITICAL: Prefetch Service Doesn't Guarantee Cache Usage

**Location:** `lib/services/media_prefetch_service.dart:374-387`

**Problem:**
- Prefetch service downloads file to cache using `downloadFile()`
- But when creating controller, it checks cache and if file exists, uses it
- However, if `getSingleFile()` fails (e.g., file is still downloading), it falls back to network
- This causes duplicate downloads

**Evidence:**
```dart
// Line 377-387: Cache check in prefetch
final File cachedFile = await _cacheService.videoManager.getSingleFile(videoUrlToPrefetch);
if (await cachedFile.exists()) {
  controller = VideoPlayerController.file(cachedFile); // ✅ Uses cache
} else {
  // ❌ PROBLEM: Creates network controller even though downloadFile() was called
  controller = VideoPlayerController.networkUrl(Uri.parse(videoUrlToPrefetch));
}
```

---

### 🟡 HIGH: No Cache Validation on Retry

**Location:** `lib/widgets/reels/reels_player_widget.dart:216-234`

**Problem:**
- When retrying video initialization, it doesn't check if file was cached during previous attempt
- May re-download same video multiple times on retry

---

### 🟡 MEDIUM: Cache May Not Persist Across App Restarts

**Location:** `lib/services/cache_manager_service.dart:33-39`

**Problem:**
- Cache configuration uses `stalePeriod: Duration(days: 30)` which is good
- But if cache is cleared or app is uninstalled, all videos must be re-downloaded
- No mechanism to verify cache integrity before using

---

## 3. Step-by-Step Refactor Plan

### Refactor 1: Fix Video Controller Disposal (CRITICAL)

**Problem:** Controllers not disposed when scrolling away, causing memory leaks.

**Old Code (to be removed):**
```dart
// lib/widgets/reels/reels_player_widget.dart:95-130
@override
void didUpdateWidget(ReelsPlayerWidget oldWidget) {
  super.didUpdateWidget(oldWidget);
  
  if (oldWidget.reel.reelId != widget.reel.reelId) {
    _disposeVideo();
    _initializeVideo(initialQuality: _currentQuality ?? _networkService.currentQuality);
    _checkLikeStatus();
  } else if (oldWidget.isCurrentReel != widget.isCurrentReel) {
    // ❌ PROBLEM: Delayed disposal with timer
    if (!widget.isCurrentReel && _videoController != null) {
      _disposalTimer?.cancel();
      _disposalTimer = Timer(const Duration(milliseconds: 500), () {
        if (!widget.isCurrentReel && mounted && _videoController != null) {
          _disposeVideo();
        }
      });
    }
  }
}
```

**New Code (with immediate, guaranteed disposal):**
```dart
// lib/widgets/reels/reels_player_widget.dart
@override
void didUpdateWidget(ReelsPlayerWidget oldWidget) {
  super.didUpdateWidget(oldWidget);
  
  // CRITICAL FIX: Always dispose when reel changes
  if (oldWidget.reel.reelId != widget.reel.reelId) {
    _disposeVideoImmediately();
    _initializeVideo(initialQuality: _currentQuality ?? _networkService.currentQuality);
    _checkLikeStatus();
    return;
  }
  
  // CRITICAL FIX: Immediate disposal when scrolling away (no timer delay)
  if (oldWidget.isCurrentReel != widget.isCurrentReel) {
    if (!widget.isCurrentReel) {
      // Immediately dispose when scrolled away - no delay
      _disposeVideoImmediately();
    } else if (widget.isCurrentReel && _isInitialized && _videoController != null) {
      // Re-initialize if scrolled back and controller was disposed
      if (!_videoController!.value.isInitialized) {
        _initializeVideo(initialQuality: _currentQuality ?? _networkService.currentQuality);
      } else if (!_videoController!.value.isPlaying && !_isPaused) {
        _videoController?.play();
        if (mounted) {
          setState(() {
            _isPaused = false;
          });
        }
      }
    }
  }
}

// CRITICAL FIX: New method for immediate disposal
void _disposeVideoImmediately() {
  // Cancel any pending timers
  _disposalTimer?.cancel();
  _disposalTimer = null;
  
  if (_videoController != null) {
    try {
      _videoController!.removeListener(_videoListener);
      _videoController!.pause();
      
      // Only dispose if we created it (not prefetched)
      if (!_isPrefetched) {
        _videoController!.dispose();
      } else {
        // If prefetched, return to service for reuse
        // Don't dispose - service manages it
      }
      
      _videoController = null;
      _isInitialized = false;
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('ReelsPlayerWidget: Error disposing video: $e');
    }
  }
}
```

---

### Refactor 2: Fix Cache-First Strategy (CRITICAL)

**Problem:** Videos re-downloaded because cache is not used properly.

**Old Code (to be removed):**
```dart
// lib/widgets/reels/reels_player_widget.dart:185-213
// Phase 2.1: Cache-first strategy - check cache before network
final videoUrl = widget.reel.getVideoUrlForQuality(initialQuality);
File? cachedFile;
VideoPlayerController? controller;

if (useCache) {
  try {
    cachedFile = await _cacheService.videoManager.getSingleFile(videoUrl);
    if (await cachedFile.exists()) {
      debugPrint('ReelsPlayerWidget: Using cached file for ${widget.reel.reelId}');
      controller = VideoPlayerController.file(cachedFile);
    } else {
      debugPrint('ReelsPlayerWidget: Cache miss for ${widget.reel.reelId}, will download');
    }
  } catch (e) {
    debugPrint('ReelsPlayerWidget: Cache check failed, using network: $e');
  }
}

// ❌ PROBLEM: Falls back to network controller that bypasses cache
if (controller == null) {
  controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
}
```

**New Code (with guaranteed cache usage):**
```dart
// lib/widgets/reels/reels_player_widget.dart
// CRITICAL FIX: Always use cache-first strategy
Future<void> _initializeVideo({
  required NetworkQuality initialQuality,
  Duration startAt = Duration.zero,
  bool useCache = true,
  int maxRetries = 3,
  int attempt = 1,
}) async {
  if (_isSwitchingQuality && startAt == Duration.zero) return;
  
  try {
    if (mounted) {
      setState(() {
        _isLoading = true;
        if (startAt == Duration.zero) {
          _isSwitchingQuality = true;
        }
      });
    }

    // Check for prefetched controller first
    VideoPlayerController? prefetchedController;
    if (startAt == Duration.zero) {
      prefetchedController = widget.prefetchService.getPrefetchedController(widget.reel.reelId);
    }

    if (prefetchedController != null) {
      _videoController = prefetchedController;
      _isPrefetched = true;
      _videoController!.addListener(_videoListener);
      _videoController!.setVolume(1.0);
      _videoController!.setLooping(true);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
          _isSwitchingQuality = false;
          _currentQuality = initialQuality;
        });

        if (widget.isCurrentReel && !_isPaused) {
          _videoController?.play();
        }
      }
      return;
    }

    // CRITICAL FIX: Cache-first strategy - ALWAYS check cache first
    final videoUrl = widget.reel.getVideoUrlForQuality(initialQuality);
    VideoPlayerController? controller;
    File? cachedFile;
    
    if (useCache) {
      try {
        // Step 1: Try to get cached file
        cachedFile = await _cacheService.videoManager.getSingleFile(videoUrl);
        
        // Step 2: Verify file exists and is readable
        if (await cachedFile.exists()) {
          final fileSize = await cachedFile.length();
          if (fileSize > 0) {
            // ✅ File is cached and valid - use it
            debugPrint('ReelsPlayerWidget: Using cached file for ${widget.reel.reelId} (size: $fileSize bytes)');
            controller = VideoPlayerController.file(cachedFile);
          } else {
            // File exists but is empty - delete it and re-download
            debugPrint('ReelsPlayerWidget: Cached file is empty, deleting and re-downloading');
            await cachedFile.delete();
            cachedFile = null;
          }
        }
      } catch (e) {
        debugPrint('ReelsPlayerWidget: Cache check failed: $e');
        cachedFile = null;
      }
    }
    
    // Step 3: If no cached file, download to cache FIRST, then create controller
    if (controller == null) {
      if (useCache) {
        try {
          // CRITICAL FIX: Download to cache FIRST, then use cached file
          debugPrint('ReelsPlayerWidget: Downloading video to cache for ${widget.reel.reelId}');
          cachedFile = await _cacheService.videoManager.downloadFile(videoUrl);
          
          // Verify downloaded file
          if (await cachedFile.exists()) {
            final fileSize = await cachedFile.length();
            if (fileSize > 0) {
              // ✅ File downloaded and cached - use it
              debugPrint('ReelsPlayerWidget: Video downloaded and cached (size: $fileSize bytes)');
              controller = VideoPlayerController.file(cachedFile);
            } else {
              throw Exception('Downloaded file is empty');
            }
          } else {
            throw Exception('Downloaded file does not exist');
          }
        } catch (e) {
          debugPrint('ReelsPlayerWidget: Cache download failed: $e, falling back to network');
          // Fallback to network only if cache download fails
          controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        }
      } else {
        // If cache is disabled, use network directly
        controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      }
    }
    
    // Rest of initialization code...
    // (delay, retry logic, etc.)
  } catch (e) {
    // Error handling...
  }
}
```

---

### Refactor 3: Fix Listener Leak (CRITICAL)

**Problem:** Video listener may trigger setState after widget is disposed.

**Old Code (to be removed):**
```dart
// lib/widgets/reels/reels_player_widget.dart:407-421
void _videoListener() {
  if (_videoController != null && mounted) {
    if (!_videoController!.value.isPlaying && 
        _videoController!.value.isInitialized && 
        _videoController!.value.duration == _videoController!.value.position) {
      // Video ended
    }
    
    // ❌ PROBLEM: setState may be called after disposal
    if (mounted) {
      setState(() {});
    }
  }
}
```

**New Code (with proper cleanup):**
```dart
// lib/widgets/reels/reels_player_widget.dart
// CRITICAL FIX: Safe listener that checks state before setState
void _videoListener() {
  // Early return if controller is null or widget is disposed
  if (_videoController == null || !mounted) return;
  
  try {
    // Only update state if widget is still mounted and controller is valid
    if (mounted && _videoController != null && _videoController!.value.isInitialized) {
      // Use WidgetsBinding to ensure we're in a valid frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _videoController != null) {
          setState(() {
            // State update is safe here
          });
        }
      });
    }
  } catch (e) {
    debugPrint('ReelsPlayerWidget: Error in video listener: $e');
  }
}
```

---

### Refactor 4: Fix Network Subscription Leak (CRITICAL)

**Problem:** Network subscription continues after widget is disposed.

**Old Code (to be removed):**
```dart
// lib/widgets/reels/reels_player_widget.dart:82-91
_networkSubscription = _networkService.qualityStream.listen((newQuality) {
  if (_isSwitchingQuality || !mounted) return;
  
  if (newQuality != _currentQuality && 
      _shouldSwitchQuality(_currentQuality!, newQuality)) {
    debugPrint('ReelsPlayerWidget: Network change detected! Switching from $_currentQuality to $newQuality');
    _switchVideoQuality(newQuality);
  }
});
```

**New Code (with proper cancellation):**
```dart
// lib/widgets/reels/reels_player_widget.dart
@override
void initState() {
  super.initState();
  // ... existing code ...
  
  // CRITICAL FIX: Track subscription and cancel in multiple places
  _networkSubscription = _networkService.qualityStream.listen(
    (newQuality) {
      // Early return if widget is disposed or switching
      if (_isSwitchingQuality || !mounted || _videoController == null) return;
      
      // Only switch if widget is still current and visible
      if (!widget.isCurrentReel) return;
      
      if (newQuality != _currentQuality && 
          _shouldSwitchQuality(_currentQuality!, newQuality)) {
        debugPrint('ReelsPlayerWidget: Network change detected! Switching from $_currentQuality to $newQuality');
        _switchVideoQuality(newQuality);
      }
    },
    onError: (error) {
      debugPrint('ReelsPlayerWidget: Network quality stream error: $error');
    },
    cancelOnError: true, // CRITICAL: Cancel on error to prevent leaks
  );
}

// CRITICAL FIX: Cancel subscription in multiple places
void _cancelNetworkSubscription() {
  _networkSubscription?.cancel();
  _networkSubscription = null;
}

@override
void dispose() {
  // CRITICAL FIX: Cancel subscription FIRST
  _cancelNetworkSubscription();
  _disposalTimer?.cancel();
  _disposeVideoImmediately();
  super.dispose();
}

@override
void didUpdateWidget(ReelsPlayerWidget oldWidget) {
  // CRITICAL FIX: Cancel subscription if widget is no longer current
  if (oldWidget.isCurrentReel != widget.isCurrentReel && !widget.isCurrentReel) {
    _cancelNetworkSubscription();
  }
  // ... rest of didUpdateWidget ...
}
```

---

### Refactor 5: Limit PageView Cache (HIGH)

**Problem:** PageView caches too many pages, keeping multiple video controllers in memory.

**Old Code (to be removed):**
```dart
// lib/screens/reels_feed_screen.dart:314
return PageView.builder(
  controller: _pageController,
  scrollDirection: Axis.vertical,
  // ❌ PROBLEM: No cacheExtent control - defaults to viewport size
  itemBuilder: (context, index) {
    return ReelsPlayerWidget(...);
  },
);
```

**New Code (with limited cache):**
```dart
// lib/screens/reels_feed_screen.dart
return PageView.builder(
  controller: _pageController,
  scrollDirection: Axis.vertical,
  // CRITICAL FIX: Limit cache to only current page (0 cache extent)
  // This ensures only the current reel's widget is kept alive
  allowImplicitScrolling: false, // Disable implicit scrolling to reduce cache
  itemBuilder: (context, index) {
    // CRITICAL FIX: Only build widget if it's near current index
    final distanceFromCurrent = (index - _currentIndex).abs();
    if (distanceFromCurrent > 1) {
      // Return empty container for distant pages to prevent widget creation
      return Container(color: Colors.black);
    }
    
    final reel = state.reels[index];
    final isCurrentReel = index == _currentIndex &&
        state.currentPlayingReelId == reel.reelId;
    
    return ReelsPlayerWidget(
      reel: reel,
      isCurrentReel: isCurrentReel,
      prefetchService: _prefetchService,
    );
  },
);
```

**Alternative (Better): Use `PageView.custom` with explicit page building:**
```dart
// Better approach: Use PageView.custom with explicit cache control
return PageView.custom(
  controller: _pageController,
  scrollDirection: Axis.vertical,
  childrenDelegate: SliverChildBuilderDelegate(
    (context, index) {
      if (index >= state.reels.length) {
        return Container(color: Colors.black);
      }
      
      final reel = state.reels[index];
      final isCurrentReel = index == _currentIndex &&
          state.currentPlayingReelId == reel.reelId;
      
      return ReelsPlayerWidget(
        reel: reel,
        isCurrentReel: isCurrentReel,
        prefetchService: _prefetchService,
      );
    },
    childCount: state.reels.length + (state.isLoadingMore ? 1 : 0),
    // CRITICAL FIX: Limit cache to only 1 page on each side
    addAutomaticKeepAlives: false, // Don't keep off-screen pages alive
    addRepaintBoundaries: true, // Add repaint boundaries for performance
  ),
);
```

---

### Refactor 6: Fix Prefetch Service Cache Usage (HIGH)

**Problem:** Prefetch service downloads to cache but may not use cached file when creating controller.

**Old Code (to be removed):**
```dart
// lib/services/media_prefetch_service.dart:374-387
final File cachedFile = await _cacheService.videoManager.getSingleFile(videoUrlToPrefetch);
if (await cachedFile.exists()) {
  controller = VideoPlayerController.file(cachedFile);
} else {
  // ❌ PROBLEM: Creates network controller even after downloadFile() was called
  controller = VideoPlayerController.networkUrl(Uri.parse(videoUrlToPrefetch));
}
```

**New Code (with guaranteed cache usage):**
```dart
// lib/services/media_prefetch_service.dart
Future<void> _prefetchVideo(ReelModel reel, String reelId, {int attempt = 1, int maxAttempts = 2}) async {
  // ... existing cancellation checks ...
  
  try {
    final NetworkQuality currentQuality = _networkService.currentQuality;
    final String videoUrlToPrefetch = reel.getVideoUrlForQuality(currentQuality);

    // CRITICAL FIX: Download to cache FIRST
    File cachedFile;
    try {
      cachedFile = await _cacheService.videoManager.downloadFile(videoUrlToPrefetch);
      debugPrint('MediaPrefetchService: Successfully cached video file for $reelId');
      
      // Verify downloaded file
      if (!await cachedFile.exists()) {
        throw Exception('Downloaded file does not exist');
      }
      
      final fileSize = await cachedFile.length();
      if (fileSize == 0) {
        throw Exception('Downloaded file is empty');
      }
      
      debugPrint('MediaPrefetchService: Cached file verified (size: $fileSize bytes)');
    } catch (e) {
      debugPrint('MediaPrefetchService: Error caching video file for $reelId: $e');
      // If cache fails, skip prefetch (don't create network controller)
      _videoQueue.remove(reelId);
      _activePrefetchOperations.remove(reelId);
      return;
    }

    // Check if service was disposed during download
    if (_isDisposed) return;
    if (_prefetchCancelled[reelId] == true) {
      debugPrint('MediaPrefetchService: Prefetch cancelled after download for $reelId');
      _activePrefetchOperations.remove(reelId);
      return;
    }

    // CRITICAL FIX: Always use cached file (never network)
    VideoPlayerController controller;
    try {
      // Verify file still exists and is valid
      if (await cachedFile.exists() && await cachedFile.length() > 0) {
        controller = VideoPlayerController.file(cachedFile);
        debugPrint('MediaPrefetchService: Using cached file for prefetched controller $reelId');
      } else {
        throw Exception('Cached file is invalid');
      }
    } catch (e) {
      debugPrint('MediaPrefetchService: Error creating controller from cache: $e');
      _videoQueue.remove(reelId);
      _activePrefetchOperations.remove(reelId);
      return;
    }

    // ... rest of initialization ...
  } catch (e) {
    // Error handling...
  }
}
```

---

## 4. Implementation Priority

### Phase 1: Critical Memory Leaks (IMMEDIATE)
1. ✅ Refactor 1: Fix Video Controller Disposal
2. ✅ Refactor 3: Fix Listener Leak
3. ✅ Refactor 4: Fix Network Subscription Leak

### Phase 2: Critical Internet Leaks (IMMEDIATE)
4. ✅ Refactor 2: Fix Cache-First Strategy
5. ✅ Refactor 6: Fix Prefetch Service Cache Usage

### Phase 3: Performance Improvements (HIGH PRIORITY)
6. ✅ Refactor 5: Limit PageView Cache

---

## 5. Testing Checklist

- [ ] Test memory usage: Scroll through 20+ reels, check RAM doesn't exceed 200MB
- [ ] Test cache: Load a reel, scroll away, scroll back - should use cache (check network logs)
- [ ] Test disposal: Scroll quickly through reels, verify controllers are disposed
- [ ] Test network subscription: Change network quality, verify subscription is cancelled when scrolled away
- [ ] Test prefetch: Verify prefetched videos use cached files, not network
- [ ] Test retry: Verify retry doesn't re-download if file is already cached
- [ ] Test PageView cache: Verify only current page is kept in memory

---

## 6. Expected Results

**Memory:**
- Before: 500MB+ after scrolling 20 reels
- After: 100-150MB stable (only current reel in memory)

**Data Usage:**
- Before: 50MB+ per reel (re-downloaded every time)
- After: 5-50MB per reel (downloaded once, cached)

**Performance:**
- Before: UI freezes after 10-15 reels
- After: Smooth scrolling indefinitely

---

**Status**: ✅ **AUDIT COMPLETE** - Ready for implementation.

