# Debug Log Analysis Guide

This guide helps you analyze debug logs to verify if the fixes for feed, stories, and reels issues are working.

## How to Capture Logs

### Option 1: Using VS Code (Recommended)
1. Open VS Code
2. Go to Run and Debug (Ctrl+Shift+D)
3. Select "Debug on Samsung SM A155F"
4. Press F5 to start debugging
5. The Debug Console will show all logs

### Option 2: Using Terminal
```bash
# Windows PowerShell
.\scripts\capture_logs.ps1

# Linux/Mac
./scripts/capture_logs.sh

# Or manually
flutter logs --device-id R58X20FBRJX > debug_log.txt
```

### Option 3: Using Android Logcat
```bash
adb -s R58X20FBRJX logcat | grep -i "freegram\|flutter\|exoplayer\|codec" > debug_log.txt
```

## What to Look For - Fix Verification

### ✅ Fix 1: NetworkQualityService Registration

**What to check:**
- ❌ **Before Fix:** Look for errors like:
  ```
  Bad state: GetIt: Object/factory with type NetworkQualityService is not registered inside GetIt
  ```

- ✅ **After Fix:** Should see:
  ```
  NetworkQualityService initialized
  Network quality changed to: excellent/good/fair/poor
  ```

**Search for:**
- `NetworkQualityService`
- `GetIt`
- `locator`

---

### ✅ Fix 2: LQIPImage Infinity/NaN Error

**What to check:**
- ❌ **Before Fix:** Look for errors like:
  ```
  Unsupported operation: Infinity or NaN toInt
  Exception caught by widgets library
  LQIPImage
  ```

- ✅ **After Fix:** Should NOT see Infinity/NaN errors. Images should load normally.

**Search for:**
- `LQIPImage`
- `Infinity`
- `NaN`
- `Unsupported operation`

---

### ✅ Fix 3: Video Codec NO_MEMORY Errors (CRITICAL FIX)

**What to check:**
- ❌ **Before Fix:** Look for errors like:
  ```
  E/Codec2Client: createComponent(c2.mtk.avc.decoder) -- call failed: NO_MEMORY
  E/MediaCodec: Codec reported err 0xfffffff4/NO_MEMORY
  E/ExoPlayerImplInternal: Playback error
  ```

- ✅ **After Fix:** Should see:
  ```
  ReelsPlayerWidget: Retrying video initialization (attempt X/3) after Xms delay
  ReelsPlayerWidget: Memory error detected, falling back to lower quality: good/fair/poor
  MediaPrefetchService: Memory error prefetching [reelId], will retry
  ```

**Search for:**
- `NO_MEMORY`
- `Codec2Client`
- `MediaCodec`
- `Retrying video initialization`
- `Memory error detected`
- `falling back to lower quality`

---

### ✅ Fix 4: Memory Management Improvements

**What to check:**
- ✅ **After Fix:** Should see:
  ```
  MediaPrefetchService: Successfully prefetched reel video [reelId]
  MediaPrefetchService: Evicted reel controller [reelId] (LRU, limit: 3)
  MediaPrefetchService: Cleared distant reel controller [reelId]
  ```

- ❌ **Before Fix:** Would see memory warnings and too many prefetched controllers.

**Search for:**
- `MediaPrefetchService`
- `Evicted`
- `Cleared distant`
- `LRU`
- `limit: 3`

---

### ✅ Fix 5: Reduced Prefetch Aggressiveness

**What to check:**
- ✅ **After Fix:** Should see staggered prefetching:
  ```
  MediaPrefetchService: Prefetching next 1-2 videos (reduced from 2-3)
  ```

- ❌ **Before Fix:** Would prefetch 2-3 videos simultaneously, causing codec exhaustion.

**Search for:**
- `prefetchReelsVideos`
- `prefetchStoryVideos`
- `prefetch count`

---

## Key Performance Indicators

### Video Loading Performance
1. **Loading Time:** Videos should load within 1-2 seconds (after initial load)
2. **Retry Success Rate:** Should see successful retries after memory errors
3. **Quality Adaptation:** Should automatically downgrade quality on memory errors

### Memory Usage
1. **Controller Count:** Maximum 3 prefetched controllers (down from 5)
2. **Cleanup:** Should see regular cleanup of distant controllers
3. **LRU Eviction:** Should see LRU eviction when limit reached

### Error Rates
1. **Codec Errors:** Should decrease significantly
2. **Memory Errors:** Should be handled gracefully with retries
3. **GetIt Errors:** Should be completely eliminated

---

## Sample Good Log Output

```
[✓] NetworkQualityService initialized
[✓] Network quality changed to: excellent
[✓] MediaPrefetchService: Prefetching next 1-2 videos
[✓] ReelsPlayerWidget: Creating new controller for reel_123 with quality: excellent
[✓] MediaPrefetchService: Successfully prefetched reel video reel_123
[✓] ReelsPlayerWidget: Using prefetched controller for reel_123
```

## Sample Bad Log Output (Before Fixes)

```
[✗] Bad state: GetIt: Object/factory with type NetworkQualityService is not registered
[✗] Unsupported operation: Infinity or NaN toInt
[✗] E/Codec2Client: createComponent(c2.mtk.avc.decoder) -- call failed: NO_MEMORY
[✗] E/MediaCodec: Codec reported err 0xfffffff4/NO_MEMORY
[✗] E/ExoPlayerImplInternal: Playback error
[✗] I/Choreographer: Skipped 138 frames! The application may be doing too much work
```

---

## Testing Checklist

When reviewing logs, check:

- [ ] No GetIt registration errors for NetworkQualityService
- [ ] No Infinity/NaN errors in LQIPImage
- [ ] NO_MEMORY errors are handled with retries
- [ ] Quality downgrade occurs on memory errors
- [ ] Prefetch count is reduced (1-2 instead of 2-3)
- [ ] Memory limits enforced (max 3 controllers)
- [ ] LRU eviction working
- [ ] Distant controllers cleaned up
- [ ] Video loading is faster
- [ ] Fewer skipped frames

---

## Quick Analysis Commands

### Count specific errors:
```bash
# Count NO_MEMORY errors
grep -i "no_memory" debug_log.txt | wc -l

# Count retry attempts
grep -i "retrying video initialization" debug_log.txt | wc -l

# Count successful prefetches
grep -i "successfully prefetched" debug_log.txt | wc -l

# Count GetIt errors (should be 0)
grep -i "getit.*not registered" debug_log.txt | wc -l

# Count Infinity/NaN errors (should be 0)
grep -i "infinity\|nan" debug_log.txt | wc -l
```

---

## Next Steps

1. Capture logs while using the app (focus on reels feed)
2. Search for the keywords above
3. Verify fixes are working
4. Share logs if issues persist

