# Create Reel Screen - Phase 2 Implementation Plan

## Overview

Phase 2 focuses on adding professional content creation features that will significantly enhance user engagement and content quality. These features are based on industry standards from TikTok, Instagram Reels, and YouTube Shorts.

**Timeline**: 2 weeks  
**Priority**: High  
**Dependencies**: Phase 1 must be complete

---

## Features to Implement

### 1. Video Trimming & Editing 🎬

**Priority**: 🔴 Critical  
**Effort**: 2-3 days  
**Impact**: High - Users need to trim unwanted parts

#### Requirements

- Trim video start/end points
- Visual timeline with frame previews
- Drag handles for precise trimming
- Real-time preview of trimmed video
- Duration indicator

#### Technical Approach

**Package**: `video_editor: ^3.0.0`

```dart
// New screen: ReelVideoEditorScreen
class ReelVideoEditorScreen extends StatefulWidget {
  final File videoFile;
  final Function(File editedVideo) onSave;
  
  // Provides:
  // - Timeline scrubber
  // - Trim handles
  // - Play/pause preview
  // - Save edited video
}
```

#### Implementation Steps

1. **Add Dependencies**
   ```yaml
   dependencies:
     video_editor: ^3.0.0
     ffmpeg_kit_flutter: ^6.0.3
   ```

2. **Create Video Editor Screen**
   - Timeline widget with thumbnails
   - Trim handles (start/end)
   - Preview player
   - Save/cancel buttons

3. **Integrate into Create Reel Flow**
   ```dart
   // After video selection/recording
   if (_selectedVideo != null) {
     final editedVideo = await Navigator.push(
       context,
       MaterialPageRoute(
         builder: (_) => ReelVideoEditorScreen(
           videoFile: _selectedVideo!,
         ),
       ),
     );
   }
   ```

4. **Export Trimmed Video**
   - Use FFmpeg to trim video
   - Maintain original quality
   - Show progress indicator

#### UI Mockup

```
┌─────────────────────────────────────┐
│         Video Preview               │
│      [Playing trimmed section]      │
│                                     │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ [▌────────────────────▐]            │
│  0:00        0:15        0:30       │
└─────────────────────────────────────┘
  [Cancel]              [Save ✓]
```

#### Acceptance Criteria

- ✅ User can trim video to any duration (1-60s)
- ✅ Timeline shows frame thumbnails
- ✅ Preview updates in real-time
- ✅ Trimmed video maintains quality
- ✅ Process completes in < 5 seconds

---

### 2. Music & Audio Selection 🎵

**Priority**: 🔴 Critical  
**Effort**: 2-3 days  
**Impact**: Very High - Music drives engagement

#### Requirements

- Browse trending sounds/music
- Search music library
- Upload custom audio
- Trim audio to match video length
- Adjust audio volume
- Mix original video audio with music

#### Technical Approach

**Option 1**: Use local music library  
**Option 2**: Integrate music API (e.g., Spotify, SoundCloud)  
**Recommended**: Start with local library, add API later

```dart
class ReelMusicPickerWidget extends StatefulWidget {
  final Duration videoDuration;
  final Function(AudioTrack) onMusicSelected;
  
  // Features:
  // - Browse trending sounds
  // - Search by name/artist
  // - Preview audio (15s)
  // - Select and trim
}
```

#### Implementation Steps

1. **Create Music Library Service**
   ```dart
   class MusicLibraryService {
     Future<List<AudioTrack>> getTrendingSounds();
     Future<List<AudioTrack>> searchMusic(String query);
     Future<File> trimAudio(File audio, Duration start, Duration end);
     Future<File> mixAudioWithVideo(File video, File audio, double volume);
   }
   ```

2. **Build Music Picker UI**
   - Trending sounds section
   - Search bar
   - Audio preview player
   - Volume slider
   - Trim controls

3. **Audio Processing**
   - Use FFmpeg for audio mixing
   - Trim audio to video duration
   - Adjust volume levels
   - Merge with video

4. **Integration**
   ```dart
   // In video preview screen
   IconButton(
     icon: Icon(Icons.music_note),
     onPressed: () => _showMusicPicker(),
   )
   ```

#### Data Model

```dart
class AudioTrack {
  final String id;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final String audioUrl;
  final Duration duration;
  final int usageCount; // For trending
}
```

#### Acceptance Criteria

- ✅ User can browse trending sounds
- ✅ Search returns relevant results
- ✅ Audio preview plays smoothly
- ✅ Audio trims to match video duration
- ✅ Volume adjustment works (0-100%)
- ✅ Final video has mixed audio

---

### 3. Recording Enhancements 📹

**Priority**: 🟡 High  
**Effort**: 1-2 days  
**Impact**: Medium - Improves recording quality

#### Features to Add

1. **Flash Control**
   - Toggle: Off / On / Auto
   - Works with front/back camera

2. **Countdown Timer**
   - 3 seconds
   - 10 seconds
   - Visual countdown indicator

3. **Grid Overlay**
   - Rule of thirds
   - Toggle on/off
   - Helps with composition

4. **Camera Switch**
   - Front/back toggle button
   - Smooth transition
   - Maintains recording state

5. **Quality Selector**
   - 720p (HD)
   - 1080p (Full HD)
   - Auto (based on network)

#### Implementation

```dart
// Update ReelCameraPreviewWidget
class ReelCameraPreviewWidget extends StatefulWidget {
  // Add new properties
  final bool showGrid;
  final FlashMode flashMode;
  final int? countdownSeconds;
  final ResolutionPreset quality;
  
  // Add new callbacks
  final VoidCallback? onFlashToggle;
  final VoidCallback? onCameraSwitch;
  final VoidCallback? onGridToggle;
}
```

#### UI Controls

```
┌─────────────────────────────────────┐
│ [Flash] [Grid] [Timer]    [Switch] │
│                                     │
│         Camera Preview              │
│                                     │
│                                     │
│         [Record Button]             │
│     [720p] [1080p] [Auto]          │
└─────────────────────────────────────┘
```

#### Acceptance Criteria

- ✅ Flash works on both cameras
- ✅ Countdown shows visual indicator
- ✅ Grid overlay is visible
- ✅ Camera switch is smooth
- ✅ Quality selector changes resolution

---

### 4. Video Compression 📦

**Priority**: 🟡 High  
**Effort**: 1 day  
**Impact**: Medium - Faster uploads, less data

#### Requirements

- Auto-compress before upload
- Quality presets (High/Medium/Low)
- Show estimated upload time
- Progress indicator during compression
- Maintain acceptable quality

#### Technical Approach

**Package**: `ffmpeg_kit_flutter: ^6.0.3`

```dart
class VideoCompressionService {
  Future<File> compressVideo(
    File inputFile, {
    VideoQuality quality = VideoQuality.medium,
    Function(double progress)? onProgress,
  }) async {
    // Use FFmpeg for compression
    final outputPath = '${inputFile.path}_compressed.mp4';
    
    final compressionLevel = _getCompressionLevel(quality);
    
    await FFmpegKit.executeAsync(
      '-i ${inputFile.path} -c:v libx264 -crf $compressionLevel $outputPath',
      (session) async {
        // Handle completion
      },
      (log) {
        // Handle logs
      },
      (statistics) {
        // Update progress
        final progress = statistics.getTime() / duration;
        onProgress?.call(progress);
      },
    );
    
    return File(outputPath);
  }
  
  int _getCompressionLevel(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.high: return 23; // Better quality
      case VideoQuality.medium: return 28; // Balanced
      case VideoQuality.low: return 32; // Smaller file
    }
  }
}
```

#### Quality Presets

| Quality | CRF | Bitrate | File Size (60s) | Upload Time (4G) |
|---------|-----|---------|-----------------|------------------|
| High    | 23  | ~5 Mbps | ~37 MB         | ~15s            |
| Medium  | 28  | ~2 Mbps | ~15 MB         | ~6s             |
| Low     | 32  | ~1 Mbps | ~7 MB          | ~3s             |

#### Implementation Steps

1. **Add Compression Service**
   - Create `VideoCompressionService`
   - Implement quality presets
   - Add progress tracking

2. **Update Upload Flow**
   ```dart
   Future<void> _uploadReel() async {
     // Show compression dialog
     final quality = await _showQualitySelector();
     
     // Compress video
     final compressedVideo = await _compressionService.compressVideo(
       _selectedVideo!,
       quality: quality,
       onProgress: (progress) {
         setState(() => _compressionProgress = progress);
       },
     );
     
     // Upload compressed video
     context.read<ReelUploadBloc>().add(
       StartReelUpload(videoPath: compressedVideo.path, ...),
     );
   }
   ```

3. **Add Quality Selector UI**
   ```dart
   Future<VideoQuality?> _showQualitySelector() {
     return showDialog<VideoQuality>(
       context: context,
       builder: (context) => AlertDialog(
         title: Text('Video Quality'),
         content: Column(
           children: [
             ListTile(
               title: Text('High (37 MB)'),
               subtitle: Text('Best quality, ~15s upload'),
               onTap: () => Navigator.pop(context, VideoQuality.high),
             ),
             // ... other options
           ],
         ),
       ),
     );
   }
   ```

#### Acceptance Criteria

- ✅ Compression reduces file size by 50-70%
- ✅ Quality remains acceptable
- ✅ Progress indicator shows accurately
- ✅ Compression completes in < 10 seconds
- ✅ User can choose quality level

---

## Implementation Timeline

### Week 1

**Days 1-3: Video Trimming & Editing**
- Day 1: Setup video_editor package, create editor screen
- Day 2: Implement timeline, trim handles, preview
- Day 3: FFmpeg integration, export functionality, testing

**Days 4-5: Music Selection (Part 1)**
- Day 4: Create music library service, data models
- Day 5: Build music picker UI, search functionality

### Week 2

**Days 6-7: Music Selection (Part 2)**
- Day 6: Audio trimming, volume adjustment
- Day 7: Audio mixing with video, testing

**Days 8-9: Recording Enhancements**
- Day 8: Flash, timer, grid overlay
- Day 9: Camera switch, quality selector

**Day 10: Video Compression**
- Implement compression service
- Add quality selector UI
- Integration and testing

---

## Dependencies & Packages

```yaml
dependencies:
  # Video editing
  video_editor: ^3.0.0
  
  # Audio/video processing
  ffmpeg_kit_flutter: ^6.0.3
  
  # Audio playback
  just_audio: ^0.9.36
  
  # File handling
  path_provider: ^2.1.1
  
  # Permissions
  permission_handler: ^11.0.1
```

---

## Testing Strategy

### Unit Tests
- Video trimming logic
- Audio mixing calculations
- Compression quality presets
- File size estimations

### Integration Tests
- End-to-end video editing flow
- Music selection and mixing
- Recording with enhancements
- Compression and upload

### Manual Testing
- Test on multiple devices (low/mid/high end)
- Test with various video formats
- Test with different network conditions
- Verify audio sync
- Check video quality after compression

---

## Risk Mitigation

### Performance Risks

**Risk**: Video processing is slow on low-end devices  
**Mitigation**: 
- Show progress indicators
- Allow background processing
- Optimize FFmpeg commands
- Provide quality presets

**Risk**: Large file sizes cause upload failures  
**Mitigation**:
- Auto-compress by default
- Show estimated upload time
- Implement chunked uploads
- Add retry logic

### UX Risks

**Risk**: Too many features overwhelm users  
**Mitigation**:
- Progressive disclosure (hide advanced features)
- Onboarding tooltips
- Smart defaults
- Optional features

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Video Edit Usage | 60% | % of uploads using trim feature |
| Music Addition | 70% | % of uploads with music |
| Compression Adoption | 80% | % of uploads compressed |
| Upload Success Rate | 95% | % of uploads completing |
| Average Upload Time | < 30s | Time from upload start to completion |

---

## Future Enhancements (Phase 3)

- AR filters & effects
- Text overlays and stickers
- Transition effects
- Speed adjustment (0.5x, 2x)
- Green screen effects
- Collaborative reels
- Templates & presets

---

## Conclusion

Phase 2 will transform the create reel screen into a professional content creation tool. By adding video editing, music selection, and recording enhancements, we'll significantly improve user engagement and content quality.

**Key Deliverables**:
- ✅ Video trimming & editing
- ✅ Music selection & mixing
- ✅ Recording enhancements
- ✅ Video compression

**Expected Impact**:
- +50% content quality
- +30% user engagement
- +25% upload completion rate
- Better retention and virality
