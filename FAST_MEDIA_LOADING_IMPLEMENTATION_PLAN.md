# Fast Media Loading Implementation Plan
## Facebook/TikTok-Style Optimization Strategies for Freegram

---

## 📋 Executive Summary

This plan outlines the implementation of 4 core strategies used by Facebook, TikTok, and Instagram to achieve that "instant" media loading experience. The strategies are designed to be implemented incrementally, with each phase building on the previous one.

**⚠️ CRITICAL FIX APPLIED:**
- **Aspect Ratio Management**: Fixed Cloudinary transformations to only set width (not both width and height) to maintain 9:16 vertical Reels aspect ratio
- **ABR Integration**: Prefetching service now integrates with Adaptive Bitrate to prefetch the correct quality based on current network

**Current State Analysis:**
- ✅ Network Quality Service exists (basic detection)
- ✅ Basic image caching with `CachedNetworkImage`
- ✅ Video player integration exists
- ✅ Shimmer skeletons exist for some screens
- ✅ Basic pagination implemented
- ❌ No video prefetching
- ❌ No adaptive bitrate streaming
- ❌ No intelligent prefetching
- ❌ No LQIP (Low Quality Image Placeholders)
- ❌ Limited skeleton screens
- ❌ No modern format support (WebP, HEVC)

---

## 🎯 Strategy 1: Prefetching & Caching (THE MOST IMPORTANT)

### 1.1 Current State
- ✅ Basic image caching exists via `CacheManagerService`
- ✅ `NetworkQualityService` has prefetch recommendations
- ❌ No video prefetching
- ❌ No intelligent prefetching based on scroll position
- ❌ No background prefetching

### 1.2 Implementation Plan

#### Phase 1.1: Video Prefetching Service (Priority: HIGH)
**File:** `lib/services/media_prefetch_service.dart`

**Features:**
- Prefetch next 2-3 videos in reels feed while user watches current video
- Prefetch next 2-3 stories while user views current story
- **Integrated with ABR**: Prefetches the quality matching current network (not just default quality)
- Queue management with priority system
- Network-aware prefetching (only on WiFi/good 4G)
- Smart cancellation (cancel if user navigates away)

**Implementation:**
```dart
class MediaPrefetchService {
  final NetworkQualityService _networkService;
  final CacheManagerService _cacheService;
  
  // Video prefetch queue
  final Queue<PrefetchTask> _videoQueue = Queue();
  final Map<String, VideoPlayerController?> _prefetchedControllers = {};
  
  // Prefetch next N videos when current video starts playing
  void prefetchReelsVideos(List<ReelModel> reels, int currentIndex) {
    if (!_networkService.shouldAutoDownloadMedia()) return;
    
    // Prefetch next 2-3 videos
    for (int i = 1; i <= 3 && (currentIndex + i) < reels.length; i++) {
      final reel = reels[currentIndex + i];
      _prefetchVideo(reel, reel.reelId); // Pass entire reel model for ABR
    }
  }
  
  // Prefetch video and initialize controller (but don't play)
  // INTEGRATED WITH ABR: Prefetches the quality matching current network
  Future<void> _prefetchVideo(ReelModel reel, String reelId) async {
    if (_prefetchedControllers.containsKey(reelId)) return;
    
    // Use ABR logic to get the RIGHT URL to prefetch based on current network
    final NetworkQuality currentQuality = _networkService.currentQuality;
    final String videoUrlToPrefetch = reel.getVideoUrlForQuality(currentQuality);
    
    try {
      // Pre-cache the correct quality video file
      await _cacheService.manager.downloadFile(videoUrlToPrefetch);
      
      // Pre-initialize video controller with that same URL (but don't play)
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrlToPrefetch));
      await controller.initialize();
      controller.setLooping(true);
      controller.pause(); // Don't play, just ready it
      
      _prefetchedControllers[reelId] = controller;
    } catch (e) {
      debugPrint('MediaPrefetchService: Error prefetching video: $e');
    }
  }
  
  // Get pre-initialized controller (if available)
  VideoPlayerController? getPrefetchedController(String reelId) {
    return _prefetchedControllers.remove(reelId);
  }
}
```

**Integration Points:**
- `ReelsFeedScreen`: Call `prefetchReelsVideos()` in `onPageChanged`
- `ReelsPlayerWidget`: Use `getPrefetchedController()` instead of creating new controller
- `StoryViewerScreen`: Similar prefetching for stories

#### Phase 1.2: Image Prefetching for Feeds (Priority: HIGH)
**Enhancement to:** `lib/widgets/feed_widgets/post_card.dart`

**Features:**
- Prefetch images for next 5-10 posts when scrolling
- Use `ScrollController` to detect when user is near bottom
- Prefetch based on network quality

**Implementation:**
```dart
// In FeedScreen or FeedTab
void _onScroll() {
  if (_scrollController.position.pixels >= 
      _scrollController.position.maxScrollExtent * 0.8) {
    // Load more posts
    _loadMorePosts();
    
    // Prefetch images for next batch
    if (_networkQualityService.shouldPrefetchImages()) {
      _prefetchNextBatchImages();
    }
  }
}

void _prefetchNextBatchImages() {
  // Get next 5-10 posts that will be visible
  final nextPosts = _getNextVisiblePosts(count: 10);
  
  for (final post in nextPosts) {
    for (final imageUrl in post.mediaUrls) {
      if (post.mediaTypes.contains('image')) {
        _mediaPrefetchService.prefetchImage(imageUrl);
      }
    }
  }
}
```

#### Phase 1.3: Intelligent Background Prefetching (Priority: MEDIUM)
**File:** `lib/services/intelligent_prefetch_service.dart`

**Features:**
- Learn user behavior patterns (e.g., "user opens app at 9 AM")
- Prefetch feed content before user opens app
- Use `workmanager` or `flutter_background_service` for background tasks
- Only on WiFi to save mobile data

**Implementation:**
```dart
class IntelligentPrefetchService {
  // Store user behavior patterns
  final SharedPreferences _prefs;
  
  // Track app open times
  void recordAppOpen() {
    final now = DateTime.now();
    final hour = now.hour;
    // Store in preferences: "app_open_hour_9", "app_open_hour_10", etc.
    _incrementAppOpenCount(hour);
  }
  
  // Predict next app open time
  DateTime? predictNextAppOpen() {
    // Find most common hour
    final commonHour = _getMostCommonOpenHour();
    if (commonHour == null) return null;
    
    // Schedule prefetch 5 minutes before predicted time
    final now = DateTime.now();
    var prefetchTime = DateTime(now.year, now.month, now.day, commonHour);
    
    if (prefetchTime.isBefore(now)) {
      prefetchTime = prefetchTime.add(Duration(days: 1));
    }
    
    return prefetchTime.subtract(Duration(minutes: 5));
  }
  
  // Schedule background prefetch
  Future<void> scheduleBackgroundPrefetch() async {
    final prefetchTime = predictNextAppOpen();
    if (prefetchTime == null) return;
    
    // Use workmanager to schedule background task
    await Workmanager().registerOneOffTask(
      "prefetch_feed",
      "prefetchFeedTask",
      initialDelay: prefetchTime.difference(DateTime.now()),
      constraints: Constraints(
        networkType: NetworkType.wifi,
      ),
    );
  }
}
```

**Note:** Requires `workmanager` package addition.

---

## 🌊 Strategy 2: Adaptive Bitrate Streaming (ABR)

### 2.1 Current State
- ❌ No adaptive bitrate streaming
- ✅ Videos are stored in Cloudinary (supports transformations)
- ❌ No quality selection based on network
- ❌ No automatic quality switching

### 2.2 Implementation Plan

**⚠️ ASPECT RATIO CRITICAL FIX:**
When generating multi-quality video URLs, **NEVER set both width and height** unless you want to force a new aspect ratio. Reels are vertical (9:16 ratio, e.g., 1080x1920). Setting both dimensions would break the video by forcing a different aspect ratio (e.g., 16:9). 

**Solution:** Only set the width. Cloudinary automatically maintains the original aspect ratio.

#### Phase 2.1: Multi-Quality Video URLs (Priority: HIGH)
**Enhancement to:** `lib/models/reel_model.dart` and `lib/models/story_media_model.dart`

**Changes:**
```dart
class ReelModel {
  // ... existing fields ...
  
  // Add quality URLs
  final String? videoUrl360p;  // Low quality (360p)
  final String? videoUrl720p;  // Medium quality (720p)
  final String? videoUrl1080p; // High quality (1080p)
  
  // Get video URL based on network quality
  String getVideoUrlForQuality(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
        return videoUrl1080p ?? videoUrl720p ?? videoUrl;
      case NetworkQuality.good:
        return videoUrl720p ?? videoUrl1080p ?? videoUrl;
      case NetworkQuality.fair:
        return videoUrl360p ?? videoUrl720p ?? videoUrl;
      case NetworkQuality.poor:
        return videoUrl360p ?? videoUrl;
      case NetworkQuality.offline:
        return videoUrl; // Use cached version
    }
  }
}
```

#### Phase 2.2: Video Transcoding on Upload (Priority: HIGH)
**Enhancement to:** `lib/services/video_upload_service.dart` and Cloudinary setup

**Cloudinary Configuration:**
- Use Cloudinary's automatic video transformation API
- Create multiple quality versions on upload
- Store all quality URLs in Firestore

**Implementation:**
```dart
class VideoUploadService {
  // Upload video and create multiple quality versions
  // CRITICAL: Only set width to maintain aspect ratio (9:16 for Reels)
  Future<Map<String, String>> uploadVideoWithMultipleQualities(File videoFile) async {
    final videoUrl = await uploadVideo(videoFile);
    
    // Request Cloudinary transformations for different qualities
    final basePublicId = extractPublicId(videoUrl);
    
    // ⚠️ IMPORTANT: Never set both width AND height unless you want to force a new aspect ratio.
    // Reels are vertical (9:16 ratio, e.g., 1080x1920). Setting both w_1280,h_720 would
    // force a 16:9 ratio, breaking the video by adding black bars or cropping.
    // 
    // SOLUTION: Only set the width. Cloudinary automatically maintains the original aspect ratio.
    
    // GOOD: Set only width - Cloudinary keeps aspect ratio (e.g., 360x640 for 9:16)
    final videoUrl360p = generateCloudinaryUrl(
      basePublicId,
      transformation: 'q_auto:low,w_360', // 360p-width, height auto-calculated
    );
    
    // GOOD: Set only width - maintains 9:16 ratio (e.g., 720x1280)
    final videoUrl720p = generateCloudinaryUrl(
      basePublicId,
      transformation: 'q_auto:good,w_720', // 720p-width, height auto-calculated
    );
    
    // GOOD: Set only width - maintains 9:16 ratio (e.g., 1080x1920)
    final videoUrl1080p = generateCloudinaryUrl(
      basePublicId,
      transformation: 'q_auto:best,w_1080', // 1080p-width, height auto-calculated
    );
    
    return {
      'videoUrl': videoUrl,
      'videoUrl360p': videoUrl360p,
      'videoUrl720p': videoUrl720p,
      'videoUrl1080p': videoUrl1080p,
    };
  }
}
```

**⚠️ CRITICAL ASPECT RATIO NOTE:**
- Reels are **vertical videos** (9:16 aspect ratio, like 1080x1920)
- Setting both `w_1280,h_720` would force a 16:9 (widescreen) ratio
- This would either add black bars (padding) or crop the top/bottom of the video
- **Solution**: Only set the width. Cloudinary automatically calculates height to maintain the original aspect ratio

#### Phase 2.3: Adaptive Video Player (Priority: HIGH)
**Enhancement to:** `lib/widgets/reels/reels_player_widget.dart` and `lib/screens/story_viewer_screen.dart`

**Features:**
- Monitor network quality changes during playback
- Switch video quality automatically if network degrades
- Show quality indicator (optional)

**Implementation:**
```dart
class AdaptiveVideoPlayer extends StatefulWidget {
  final ReelModel reel;
  final NetworkQualityService networkService;
  
  @override
  State<AdaptiveVideoPlayer> createState() => _AdaptiveVideoPlayerState();
}

class _AdaptiveVideoPlayerState extends State<AdaptiveVideoPlayer> {
  VideoPlayerController? _videoController;
  NetworkQuality? _currentQuality;
  StreamSubscription? _networkSubscription;
  
  @override
  void initState() {
    super.initState();
    _currentQuality = widget.networkService.currentQuality;
    _loadVideoForQuality(_currentQuality!);
    
    // Listen to network quality changes
    _networkSubscription = widget.networkService.qualityStream.listen((quality) {
      if (quality != _currentQuality) {
        _switchVideoQuality(quality);
      }
    });
  }
  
  Future<void> _loadVideoForQuality(NetworkQuality quality) async {
    final videoUrl = widget.reel.getVideoUrlForQuality(quality);
    
    // Dispose old controller
    await _videoController?.dispose();
    
    // Create new controller with appropriate quality
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await _videoController!.initialize();
    
    if (mounted) {
      setState(() {
        _currentQuality = quality;
      });
      _videoController?.play();
    }
  }
  
  Future<void> _switchVideoQuality(NetworkQuality newQuality) async {
    // Only switch if quality changed significantly
    if (_shouldSwitchQuality(_currentQuality!, newQuality)) {
      await _loadVideoForQuality(newQuality);
    }
  }
  
  bool _shouldSwitchQuality(NetworkQuality old, NetworkQuality new_) {
    // Switch from high to low quality if network degraded
    if (old == NetworkQuality.excellent && 
        (new_ == NetworkQuality.poor || new_ == NetworkQuality.fair)) {
      return true;
    }
    // Switch from low to high quality if network improved
    if ((old == NetworkQuality.poor || old == NetworkQuality.fair) &&
        new_ == NetworkQuality.excellent) {
      return true;
    }
    return false;
  }
}
```

---

## 🎛️ Strategy 3: Lazy Loading & Placeholders

### 3.1 Current State
- ✅ Basic lazy loading with pagination
- ✅ Some shimmer skeletons exist
- ❌ No LQIP (Low Quality Image Placeholders)
- ❌ Limited skeleton screens
- ❌ No blur-up effect

### 3.2 Implementation Plan

#### Phase 3.1: LQIP (Low Quality Image Placeholders) (Priority: HIGH)
**New File:** `lib/widgets/lqip_image.dart`

**Features:**
- Load tiny, blurry version of image first (1-5KB)
- Show blur-up effect when full image loads
- Use Cloudinary's `q_auto:low,w_20` transformation for LQIP

**Implementation:**
```dart
class LQIPImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  
  const LQIPImage({
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });
  
  @override
  State<LQIPImage> createState() => _LQIPImageState();
}

class _LQIPImageState extends State<LQIPImage> {
  bool _isLoading = true;
  
  // Generate LQIP URL from Cloudinary
  String _getLQIPUrl(String originalUrl) {
    // If already Cloudinary URL, add transformation
    if (originalUrl.contains('cloudinary.com')) {
      // Insert transformation before filename
      return originalUrl.replaceFirst(
        '/upload/',
        '/upload/q_auto:low,w_20,blur_300/',
      );
    }
    // Fallback: use original URL (LQIP not supported)
    return originalUrl;
  }
  
  @override
  Widget build(BuildContext context) {
    final lqipUrl = _getLQIPUrl(widget.imageUrl);
    
    return Stack(
      children: [
        // Blurry placeholder
        if (_isLoading)
          CachedNetworkImage(
            imageUrl: lqipUrl,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            filterQuality: FilterQuality.low,
          ),
        
        // Full quality image (fades in)
        AnimatedOpacity(
          opacity: _isLoading ? 0.0 : 1.0,
          duration: Duration(milliseconds: 300),
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            onLoad: () {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            },
          ),
        ),
      ],
    );
  }
}
```

**Integration:**
- Replace `CachedNetworkImage` in `PostCard` with `LQIPImage`
- Replace in `StoryPreviewCard` with `LQIPImage`
- Replace in `ReelsPlayerWidget` thumbnail with `LQIPImage`

#### Phase 3.2: Enhanced Skeleton Screens (Priority: MEDIUM)
**Enhancement to:** Existing skeleton widgets + new ones

**New Files:**
- `lib/widgets/skeletons/reel_skeleton.dart`
- `lib/widgets/skeletons/story_skeleton.dart`
- `lib/widgets/skeletons/feed_post_skeleton.dart`

**Features:**
- Match exact layout of actual content
- Smooth shimmer animation
- Progressive loading (avatar → text → image)

**Example:**
```dart
class FeedPostSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // Header skeleton
          ListTile(
            leading: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: CircleAvatar(radius: 20),
            ),
            title: Shimmer.fromColors(
              child: Container(height: 16, width: 100, color: Colors.white),
            ),
            subtitle: Shimmer.fromColors(
              child: Container(height: 12, width: 60, color: Colors.white),
            ),
          ),
          // Image skeleton
          Shimmer.fromColors(
            child: Container(height: 300, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
```

#### Phase 3.3: Optimized Lazy Loading (Priority: MEDIUM)
**Enhancement to:** Feed screens

**Features:**
- Load only visible items + 2-3 below viewport
- Unload items that are far from viewport
- Use `ListView.builder` with `cacheExtent` optimization

**Implementation:**
```dart
ListView.builder(
  controller: _scrollController,
  cacheExtent: 500, // Only cache 500px below viewport
  itemCount: _posts.length,
  itemBuilder: (context, index) {
    // Only load media if item is near viewport
    final isNearViewport = _isItemNearViewport(index);
    
    return FeedPostCard(
      post: _posts[index],
      loadMedia: isNearViewport, // Only load if near viewport
    );
  },
);
```

---

## 🗜️ Strategy 4: Compression & Modern Formats

### 4.1 Current State
- ✅ Basic video compression on upload
- ✅ Cloudinary supports WebP
- ❌ No WebP conversion for images
- ❌ No HEVC/AV1 support
- ❌ No format selection based on browser support

### 4.2 Implementation Plan

#### Phase 4.1: WebP Image Format (Priority: HIGH)
**Enhancement to:** `lib/services/cloudinary_service.dart`

**Features:**
- Automatically convert images to WebP on upload
- Use `f_auto` Cloudinary transformation for format selection
- Fallback to JPEG for unsupported browsers

**Implementation:**
```dart
class CloudinaryService {
  // Generate WebP URL with fallback
  static String getOptimizedImageUrl(String originalUrl, {
    int? width,
    int? height,
    int? quality,
  }) {
    if (!originalUrl.contains('cloudinary.com')) {
      return originalUrl; // Not Cloudinary, return as-is
    }
    
    // Build transformation string
    final transformations = <String>[];
    
    // Format: Auto WebP with JPEG fallback
    transformations.add('f_auto');
    
    // Quality
    if (quality != null) {
      transformations.add('q_auto:$quality');
    } else {
      transformations.add('q_auto');
    }
    
    // Dimensions
    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');
    
    // Insert transformations
    return originalUrl.replaceFirst(
      '/upload/',
      '/upload/${transformations.join(',')}/',
    );
  }
}
```

#### Phase 4.2: HEVC Video Format (Priority: MEDIUM)
**Note:** HEVC (H.265) is more efficient but requires:
- iOS 11+ support
- Android 5.0+ support (varies by device)
- Cloudinary automatic format selection

**Implementation:**
- Use Cloudinary's `f_auto` transformation for videos
- Cloudinary will automatically serve HEVC to supported devices
- Fallback to H.264 for unsupported devices

**Cloudinary Video URL:**
```
https://res.cloudinary.com/your-cloud/video/upload/f_auto,q_auto:best/v1234567890/video.mp4
```

#### Phase 4.3: Enhanced Compression Settings (Priority: MEDIUM)
**Enhancement to:** Upload services

**Features:**
- Adjust compression based on content type
- Profile pictures: Higher quality (90%)
- Feed images: Medium quality (75-80%)
- Thumbnails: Lower quality (60%)

**Implementation:**
```dart
enum ImageQuality {
  thumbnail(60),
  medium(75),
  high(90);
  
  final int quality;
  const ImageQuality(this.quality);
}

class CloudinaryService {
  static Future<String?> uploadImageWithQuality(
    File imageFile,
    ImageQuality quality,
  ) async {
    // Use appropriate quality based on use case
    return uploadImage(
      imageFile,
      quality: quality.quality,
      format: 'auto', // WebP if supported
    );
  }
}
```

---

## 📦 Dependencies to Add

```yaml
# pubspec.yaml additions
dependencies:
  # Background tasks for intelligent prefetching
  workmanager: ^0.5.2
  
  # Enhanced video player (if needed for ABR)
  # video_player: ^2.8.6 (already exists)
  
  # Image format detection
  image: ^4.1.3
```

---

## 🚀 Implementation Priority & Phases

### Phase 1 (Week 1-2): Critical Foundation
1. ✅ Video Prefetching Service (Strategy 1.1)
2. ✅ Image Prefetching for Feeds (Strategy 1.2)
3. ✅ LQIP Implementation (Strategy 3.1)
4. ✅ Multi-Quality Video URLs (Strategy 2.1)

### Phase 2 (Week 3-4): Performance Boost
5. ✅ Adaptive Video Player (Strategy 2.3)
6. ✅ Video Transcoding on Upload (Strategy 2.2)
7. ✅ WebP Image Format (Strategy 4.1)
8. ✅ Enhanced Skeleton Screens (Strategy 3.2)

### Phase 3 (Week 5-6): Polish & Optimization
9. ✅ Intelligent Background Prefetching (Strategy 1.3)
10. ✅ Optimized Lazy Loading (Strategy 3.3)
11. ✅ Enhanced Compression Settings (Strategy 4.3)
12. ✅ HEVC Video Format (Strategy 4.2)

---

## 📊 Expected Performance Improvements

| Strategy | Expected Improvement |
|----------|---------------------|
| Video Prefetching | **80-90%** reduction in video load time |
| LQIP | **60-70%** improvement in perceived load time |
| Adaptive Bitrate | **50-60%** reduction in buffering |
| WebP Format | **25-35%** reduction in image file size |
| Intelligent Prefetching | **Instant** feed load (content ready before app open) |

---

## 🔧 Technical Considerations

### Aspect Ratio Management ⚠️ CRITICAL
- **NEVER set both width and height** in Cloudinary transformations for videos
- Reels are vertical (9:16 ratio, e.g., 1080x1920)
- Only set width - Cloudinary automatically maintains aspect ratio
- Setting both dimensions would force a different ratio (e.g., 16:9), breaking the video

### Memory Management
- Limit prefetched video controllers to 3-5 max
- Implement LRU (Least Recently Used) cache eviction
- Monitor memory usage and adjust prefetch count

### Network Usage
- Only prefetch on WiFi or good 4G
- Respect user's data saver settings
- Provide user control over prefetching
- **ABR Integration**: Prefetch the quality matching current network (not default quality)

### Error Handling
- Graceful fallback if prefetch fails
- Retry mechanism with exponential backoff
- Clear error messages for users

### Testing
- Test on slow 3G networks
- Test on WiFi
- Test with data saver enabled
- Test memory usage on low-end devices
- **Test aspect ratio preservation** with different video dimensions (9:16, 16:9, 1:1)

---

## 📝 Notes

1. **Cloudinary Integration**: Most optimizations rely on Cloudinary's transformation API. Ensure Cloudinary account is properly configured.

2. **Firestore Changes**: Need to update Firestore document structure to include multiple quality URLs for videos.

3. **Backward Compatibility**: Ensure app works with existing videos that don't have multiple quality versions.

4. **User Settings**: Consider adding user preferences for:
   - Data saver mode (disable prefetching)
   - Video quality preference
   - Auto-download settings

5. **Analytics**: Track metrics like:
   - Video load time
   - Buffering events
   - Prefetch success rate
   - Network quality distribution

---

## 🎯 Success Metrics

- **Video Load Time**: < 500ms (from cache) or < 2s (from network)
- **Image Load Time**: < 200ms (LQIP) or < 1s (full quality)
- **Buffering Rate**: < 2% of videos
- **Cache Hit Rate**: > 70% for frequently viewed content
- **Data Usage**: < 5% increase (due to intelligent prefetching)

---

## 📚 References

- [Cloudinary Video Transformations](https://cloudinary.com/documentation/video_transformation_reference)
- [Cloudinary Image Transformations](https://cloudinary.com/documentation/image_transformation_reference)
- [Flutter Cache Manager](https://pub.dev/packages/flutter_cache_manager)
- [Video Player Best Practices](https://pub.dev/packages/video_player)

---

**Last Updated:** 2024-12-19
**Status:** Ready for Implementation

---

## ⚠️ CRITICAL FIXES APPLIED (2024-12-19)

### Fix 1: Aspect Ratio Management
**Problem:** Setting both width and height in Cloudinary transformations (e.g., `w_1280,h_720`) forces a 16:9 aspect ratio, breaking vertical 9:16 Reels videos.

**Solution:** Only set width in transformations. Cloudinary automatically maintains the original aspect ratio.
- ✅ `w_360` (not `w_640,h_360`) - maintains 9:16 ratio
- ✅ `w_720` (not `w_1280,h_720`) - maintains 9:16 ratio  
- ✅ `w_1080` (not `w_1920,h_1080`) - maintains 9:16 ratio

**Files Updated:**
- Phase 2.2: Video Transcoding on Upload - Fixed Cloudinary URL generation

### Fix 2: ABR Integration with Prefetching
**Problem:** Prefetching service was using default video URL, not the quality matching current network.

**Solution:** Prefetching service now integrates with Adaptive Bitrate service to prefetch the correct quality based on current network conditions.
- ✅ `_prefetchVideo()` now accepts `ReelModel` instead of just URL
- ✅ Uses `reel.getVideoUrlForQuality(currentQuality)` to get appropriate URL
- ✅ Prefetches the quality that will actually be used

**Files Updated:**
- Phase 1.1: Video Prefetching Service - Integrated with ABR logic

