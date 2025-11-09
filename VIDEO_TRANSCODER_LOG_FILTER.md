# Video Transcoder Log Filter Guide

## Problem
The `video_compress` package uses `com.otaliastudios.transcoder` internally, which outputs excessive verbose (V-level) logs during video processing. These logs can flood the console, especially when processing audio segments after video completion.

## Solution

### For Development (Android Studio/Logcat)

Use logcat filters to exclude verbose transcoder logs:

```bash
# Filter out verbose transcoder logs
adb logcat | grep -v "V/TranscodeEngine" | grep -v "V/Segment" | grep -v "V/Segments" | grep -v "V/Pipeline" | grep -v "I/Decoder"

# Or use logcat tag filters (more efficient)
adb logcat *:S -s "MainApplication:*" "MainActivity:*" "flutter:*" "FirebaseApp:*"
```

### For Android Studio

1. Open **Logcat** window
2. Click the **Filter** dropdown
3. Add a filter with **Regex**:
   ```
   ^(?!(V/TranscodeEngine|V/Segment|V/Segments|V/Pipeline|I/Decoder))
   ```
4. Or use **Tag** filter and exclude:
   - `V/TranscodeEngine`
   - `V/Segment`
   - `V/Segments`
   - `V/Pipeline`
   - `I/Decoder`

### For Release Builds

Release builds automatically filter verbose logs. If you still see them, add to `proguard-rules.pro`:

```proguard
# Suppress verbose transcoder logs in release builds
-assumenosideeffects class com.otaliastudios.transcoder.** {
    public static *** v(...);
}
```

## Technical Details

The transcoder library outputs logs at these levels:
- `V/TranscodeEngine` - Transcoding engine status
- `V/Segment` - Video/audio segment processing
- `V/Segments` - Segment management
- `V/Pipeline` - Processing pipeline status
- `I/Decoder` - Decoder information (INFO level)

These are normal operation logs but can be excessive during video processing, especially when the transcoder is processing audio segments after video completion.

## Timeout Protection

A 5-minute timeout has been added to video compression operations to prevent infinite loops. If compression times out, the original video file will be used instead.

## Notes

- This is a development/debugging issue - release builds filter verbose logs automatically
- The transcoder logs don't indicate an error - they're just verbose status updates
- If you see the logs stuck in a loop, check the timeout handling in `VideoUploadService._compressVideo()`

