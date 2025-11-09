# Video Testing Checklist

Use this checklist while testing to ensure we capture all the important scenarios.

## ✅ Testing Steps

### 1. Reels Feed Testing
- [ ] Navigate to Reels tab/feed
- [ ] Scroll down through 5-10 videos
- [ ] Let each video load completely
- [ ] Scroll back up 2-3 videos
- [ ] Scroll down again
- [ ] Try rapid scrolling (swipe quickly)
- [ ] Let videos auto-play
- [ ] Tap to pause/play videos

### 2. Stories Testing
- [ ] Open Stories tray
- [ ] Open a story with video content
- [ ] Navigate through multiple video stories
- [ ] Swipe to next/previous stories
- [ ] Let videos play completely
- [ ] Exit and re-enter stories

### 3. Edge Cases
- [ ] Quickly switch between reels and stories
- [ ] Open reels while a story video is playing
- [ ] Open stories while a reel video is playing
- [ ] Test on slower network (if possible)
- [ ] Test after app has been running for a while

## 🔍 What We're Looking For

### Positive Signs (Fixes Working):
- ✅ `ReelsPlayerWidget: Creating new controller`
- ✅ `ReelsPlayerWidget: Using prefetched controller`
- ✅ `MediaPrefetchService: Successfully prefetched reel video`
- ✅ `MediaPrefetchService: Prefetching next 1-2 videos`
- ✅ `Retrying video initialization` (if errors occur)
- ✅ `Memory error detected, falling back to lower quality`

### Negative Signs (Issues):
- ❌ `NO_MEMORY` errors (should be handled with retries)
- ❌ `Codec2Client: createComponent failed`
- ❌ `MediaCodec: Codec reported err`
- ❌ Long loading times without retry attempts
- ❌ `GetIt: Object/factory with type NetworkQualityService is not registered`
- ❌ `Unsupported operation: Infinity or NaN toInt`

## ⏱️ Timing

- **Minimum test time:** 2-3 minutes
- **Ideal test time:** 5 minutes
- **Focus on:** Video loading, scrolling, playback

## 📝 Notes

While testing, note:
- Are videos loading faster than before?
- Any crashes or freezes?
- Smooth scrolling through videos?
- Quick transitions between videos?

