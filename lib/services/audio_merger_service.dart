// lib/services/audio_merger_service.dart
//
// TEMPORARILY DISABLED - FFmpegKit compatibility issues
// This service is stubbed out until an alternative audio processing solution is implemented

import 'package:flutter/foundation.dart';

/// Service for merging audio with video or creating video from photo with audio
/// 
/// NOTE: This service is currently disabled due to FFmpegKit being discontinued.
/// All methods return null to indicate the feature is unavailable.
class AudioMergerService {
  /// Merge audio with photo to create a 20-second video
  /// 
  /// [photoPath] - Path to the photo file
  /// [audioPath] - Path to the audio file (should be 20 seconds or less)
  /// Returns the path to the merged video file, or null if merging fails
  /// 
  /// CURRENTLY DISABLED - Returns null
  static Future<String?> mergePhotoWithAudio({
    required String photoPath,
    required String audioPath,
    double duration = 20.0,
  }) async {
    debugPrint('AudioMergerService: Photo+audio merging is currently disabled (FFmpegKit unavailable)');
    return null;
  }

  /// Replace audio track in video (for videos < 20s)
  /// 
  /// [videoPath] - Path to the video file
  /// [audioPath] - Path to the audio file
  /// Returns the path to the merged video file, or null if merging fails
  /// 
  /// CURRENTLY DISABLED - Returns null
  static Future<String?> replaceAudioInVideo({
    required String videoPath,
    required String audioPath,
  }) async {
    debugPrint('AudioMergerService: Audio replacement in video is currently disabled (FFmpegKit unavailable)');
    return null;
  }

  /// Trim video to 20 seconds and replace audio
  /// 
  /// [videoPath] - Path to the video file (should be > 20 seconds)
  /// [audioPath] - Path to the audio file (should be 20 seconds)
  /// [startTime] - Start time for video trim in seconds
  /// Returns the path to the merged video file, or null if merging fails
  /// 
  /// CURRENTLY DISABLED - Returns null
  static Future<String?> trimVideoAndReplaceAudio({
    required String videoPath,
    required String audioPath,
    required double startTime,
    double duration = 20.0,
  }) async {
    debugPrint('AudioMergerService: Video trimming+audio replacement is currently disabled (FFmpegKit unavailable)');
    return null;
  }
}
