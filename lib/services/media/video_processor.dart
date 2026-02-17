// lib/services/media/video_processor.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as thumbnail_gen;

/// Service for handling video processing (compression, transcoding) in a background isolate.
/// This ensures the Main UI thread remains responsive during heavy operations.
class VideoProcessor {
  VideoProcessor._();

  /// Compresses a video for Reel standards (1080p, ~5Mbps target)
  static Future<File?> compressForReel(
    File videoFile, {
    void Function(double progress)? onProgress,
    VideoQuality quality = VideoQuality.Res1920x1080Quality,
  }) async {
    try {
      debugPrint('VideoProcessor: Transcoding for Reel (1080p)...');
      final mediaInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
      );
      return mediaInfo?.path != null ? File(mediaInfo!.path!) : null;
    } catch (e) {
      debugPrint('VideoProcessor: Reel compression error: $e');
      return null;
    }
  }

  /// Compresses a video for Story standards (720p, ~2Mbps target)
  static Future<File?> compressForStory(
    File videoFile, {
    void Function(double progress)? onProgress,
    VideoQuality quality = VideoQuality.Res1280x720Quality,
  }) async {
    try {
      debugPrint('VideoProcessor: Transcoding for Story (720p)...');
      final mediaInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
      );
      return mediaInfo?.path != null ? File(mediaInfo!.path!) : null;
    } catch (e) {
      debugPrint('VideoProcessor: Story compression error: $e');
      return null;
    }
  }

  /// Generates a Low Quality Image Placeholder (LQIP)
  /// Returns a base64 string under 5KB
  static Future<String?> generateLQIP(File videoFile) async {
    try {
      final uint8list = await thumbnail_gen.VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: thumbnail_gen.ImageFormat.JPEG,
        maxWidth: 100, // Ultra small
        quality: 20, // Ultra compressed
      );

      if (uint8list == null) return null;

      // Convert to base64
      return base64Encode(uint8list);
    } catch (e) {
      debugPrint('VideoProcessor: LQIP generation error: $e');
      return null;
    }
  }

  /// Compresses a video file with default settings.
  static Future<File?> compressVideo(
    File videoFile, {
    void Function(double progress)? onProgress,
  }) async {
    return compressForStory(videoFile, onProgress: onProgress);
  }

  /// Cleans up temporary compression files.
  static Future<void> dispose() async {
    await VideoCompress.deleteAllCache();
  }
}
