// lib/services/video_upload_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:freegram/services/cloudinary_service.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class VideoUploadService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Compress and upload video, then create Firestore entry
  /// Returns the created ReelModel on success
  Future<ReelModel?> uploadReel({
    required File videoFile,
    String? caption,
    List<String>? hashtags,
    List<String>? mentions,
    required Function(double progress) onProgress,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Step 1: Compress video (with progress tracking)
      debugPrint('VideoUploadService: Starting video compression...');
      onProgress(0.1);

      final compressedVideo = await _compressVideo(
        videoFile,
        onCompressionProgress: (progress) {
          // Compression takes ~30% of total progress
          onProgress(0.1 + (progress * 0.3));
        },
      );

      if (compressedVideo == null) {
        throw Exception('Video compression failed');
      }

      onProgress(0.4);

      // Step 2: Generate thumbnail
      debugPrint('VideoUploadService: Generating thumbnail...');
      final thumbnailFile = await _generateThumbnail(compressedVideo);
      onProgress(0.5);

      // Step 3: Upload video to Cloudinary with multiple qualities (40% of progress)
      debugPrint(
          'VideoUploadService: Uploading video to Cloudinary with multiple qualities...');
      final videoQualities = await uploadVideoWithMultipleQualities(
        compressedVideo,
        onProgress: (progress) {
          onProgress(0.5 + (progress * 0.4));
        },
      );

      if (videoQualities == null ||
          videoQualities['videoUrl'] == null ||
          videoQualities['videoUrl']!.isEmpty) {
        throw Exception('Video upload failed');
      }

      final videoUrl = videoQualities['videoUrl']!;

      onProgress(0.9);

      // Step 4: Upload thumbnail
      debugPrint('VideoUploadService: Uploading thumbnail...');
      final thumbnailUrl = thumbnailFile != null
          ? await CloudinaryService.uploadImageFromFile(thumbnailFile)
          : null;

      // Step 5: Get video duration
      final duration = await _getVideoDuration(compressedVideo);

      // Step 6: Get user info
      final userDoc = await _db.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};
      final username = userData['username'] ?? 'Unknown';
      final avatarUrl = userData['photoUrl'] ?? '';

      // Step 7: Create Firestore document
      debugPrint('VideoUploadService: Creating Firestore entry...');
      final reelRef = _db.collection('reels').doc();

      final reelData = {
        'reelId': reelRef.id,
        'uploaderId': currentUser.uid,
        'uploaderUsername': username,
        'uploaderAvatarUrl': avatarUrl,
        'videoUrl': videoUrl,
        // Multi-quality video URLs (Phase 2.2 - Adaptive Bitrate Streaming)
        if (videoQualities['videoUrl360p'] != null)
          'videoUrl360p': videoQualities['videoUrl360p'],
        if (videoQualities['videoUrl720p'] != null)
          'videoUrl720p': videoQualities['videoUrl720p'],
        if (videoQualities['videoUrl1080p'] != null)
          'videoUrl1080p': videoQualities['videoUrl1080p'],
        'thumbnailUrl': thumbnailUrl ?? '',
        'duration': duration,
        'caption': caption,
        'hashtags': hashtags ?? [],
        'mentions': mentions ?? [],
        'likeCount': 0,
        'commentCount': 0,
        'shareCount': 0,
        'viewCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await reelRef.set(reelData);

      // Clean up compressed file
      try {
        await compressedVideo.delete();
      } catch (e) {
        debugPrint('VideoUploadService: Error deleting compressed file: $e');
      }

      if (thumbnailFile != null) {
        try {
          await thumbnailFile.delete();
        } catch (e) {
          debugPrint('VideoUploadService: Error deleting thumbnail: $e');
        }
      }

      onProgress(1.0);

      debugPrint('VideoUploadService: Reel uploaded successfully!');
      return ReelModel.fromDoc(await reelRef.get());
    } catch (e) {
      debugPrint('VideoUploadService: Error uploading reel: $e');
      rethrow;
    }
  }

  Future<File?> _compressVideo(
    File videoFile, {
    required Function(double progress) onCompressionProgress,
  }) async {
    try {
      // Add timeout to prevent infinite loops during compression
      // The transcoder can get stuck processing audio segments
      final mediaInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality, // Adjust based on needs
        deleteOrigin: false,
        includeAudio: true,
      ).timeout(
        const Duration(minutes: 5), // 5 minute timeout for compression
        onTimeout: () {
          debugPrint('VideoUploadService: Compression timeout after 5 minutes');
          throw TimeoutException(
            'Video compression timed out after 5 minutes',
          );
        },
      );

      if (mediaInfo == null ||
          mediaInfo.path == null ||
          mediaInfo.path!.isEmpty) {
        debugPrint('VideoUploadService: Compression returned null or empty path');
        return null;
      }

      onCompressionProgress(1.0);
      return File(mediaInfo.path!);
    } on TimeoutException catch (e) {
      debugPrint('VideoUploadService: Compression timeout: $e');
      // If compression times out, return original file
      onCompressionProgress(1.0);
      return videoFile;
    } catch (e) {
      debugPrint('VideoUploadService: Compression error: $e');
      // If compression fails, return original file
      onCompressionProgress(1.0);
      return videoFile;
    }
  }

  Future<File?> _generateThumbnail(File videoFile) async {
    try {
      final thumbnailData = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 85,
      );

      if (thumbnailData == null) {
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final thumbnailFile = File(
        path.join(
          tempDir.path,
          'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      await thumbnailFile.writeAsBytes(thumbnailData);
      return thumbnailFile;
    } catch (e) {
      debugPrint('VideoUploadService: Thumbnail generation error: $e');
      return null;
    }
  }

  Future<double> _getVideoDuration(File videoFile) async {
    try {
      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      final duration = controller.value.duration.inSeconds.toDouble();
      await controller.dispose();
      return duration;
    } catch (e) {
      debugPrint('VideoUploadService: Error getting duration: $e');
      return 0.0;
    }
  }

  /// Uploads a video and returns a map of all quality URLs.
  ///
  /// This method implements Phase 2.2 of the Fast Media Loading Implementation Plan.
  /// It uploads the original video and then generates transformed URLs for different
  /// quality levels (360p, 720p, 1080p) using Cloudinary transformations.
  ///
  /// CRITICAL ASPECT RATIO FIX: Only the width parameter is set in transformations
  /// to ensure the original 9:16 (vertical) aspect ratio of Reels is maintained.
  ///
  /// Returns a map containing:
  /// - 'videoUrl': Original uploaded video URL
  /// - 'videoUrl360p': Low quality (360p width) URL
  /// - 'videoUrl720p': Medium quality (720p width) URL
  /// - 'videoUrl1080p': High quality (1080p width) URL
  Future<Map<String, String>?> uploadVideoWithMultipleQualities(
    File videoFile, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Step 1: Upload the original video first
      debugPrint('VideoUploadService: Uploading original video...');
      final originalVideoUrl = await CloudinaryService.uploadVideoFromFile(
        videoFile,
        onProgress: (progress) {
          // Upload takes 50% of the total progress
          onProgress?.call(progress * 0.5);
        },
      );

      if (originalVideoUrl == null || originalVideoUrl.isEmpty) {
        throw Exception('Original video upload failed');
      }

      debugPrint(
          'VideoUploadService: Original video uploaded: $originalVideoUrl');

      // Step 2: Get the base public ID from the returned URL
      final String? basePublicId = _extractPublicId(originalVideoUrl);

      if (basePublicId == null) {
        debugPrint(
            'VideoUploadService: Could not extract public ID, using original URL only');
        // Fallback: return only the original URL
        return {
          'videoUrl': originalVideoUrl,
        };
      }

      debugPrint('VideoUploadService: Extracted public ID: $basePublicId');

      // Step 3: Generate the transformed URLs using helper
      // CRITICAL: Only set width to maintain aspect ratio (9:16 for vertical videos)
      debugPrint('VideoUploadService: Generating quality URLs...');
      onProgress?.call(0.6);

      // 360p-width (e.g., 360x640 for a 9:16 video)
      final String videoUrl360p = _generateCloudinaryUrl(
        originalVideoUrl,
        basePublicId,
        transformation:
            'q_auto:low,w_360,f_auto', // f_auto = auto-select format (HEVC/H.265)
      );

      onProgress?.call(0.7);

      // 720p-width (e.g., 720x1280 for a 9:16 video)
      final String videoUrl720p = _generateCloudinaryUrl(
        originalVideoUrl,
        basePublicId,
        transformation: 'q_auto:good,w_720,f_auto',
      );

      onProgress?.call(0.8);

      // 1080p-width (e.g., 1080x1920 for a 9:16 video)
      final String videoUrl1080p = _generateCloudinaryUrl(
        originalVideoUrl,
        basePublicId,
        transformation: 'q_auto:best,w_1080,f_auto',
      );

      onProgress?.call(1.0);

      debugPrint('VideoUploadService: Quality URLs generated successfully');

      // Step 4: Return the map, ready to be saved to Firestore
      return {
        'videoUrl': originalVideoUrl,
        'videoUrl360p': videoUrl360p,
        'videoUrl720p': videoUrl720p,
        'videoUrl1080p': videoUrl1080p,
      };
    } catch (e) {
      debugPrint(
          'VideoUploadService: Error in uploadVideoWithMultipleQualities: $e');
      rethrow;
    }
  }

  /// Generates a Cloudinary URL with transformations inserted.
  ///
  /// Cloudinary URL structure:
  /// https://res.cloudinary.com/<cloud_name>/video/upload/v<version>/<public_id>
  ///
  /// With transformations:
  /// https://res.cloudinary.com/<cloud_name>/video/upload/<transformations>/v<version>/<public_id>
  ///
  /// [originalUrl] - The original Cloudinary URL
  /// [publicId] - The public ID extracted from the URL
  /// [transformation] - The transformation string (e.g., 'q_auto:low,w_360,f_auto')
  String _generateCloudinaryUrl(
    String originalUrl,
    String publicId, {
    required String transformation,
  }) {
    try {
      final uri = Uri.parse(originalUrl);
      final pathSegments = uri.pathSegments;

      // Find the index of 'upload' in the path
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex >= pathSegments.length - 1) {
        debugPrint(
            'VideoUploadService: Invalid Cloudinary URL structure: $originalUrl');
        return originalUrl; // Fallback to original URL
      }

      // Reconstruct the URL with transformations
      // Structure: /video/upload/<transformations>/v<version>/<public_id>
      final newPathSegments = [
        ...pathSegments.sublist(
            0, uploadIndex + 1), // Everything up to and including 'upload'
        transformation, // Insert transformation
        ...pathSegments.sublist(
            uploadIndex + 1), // Rest of the path (v<version>/<public_id>)
      ];

      // Reconstruct the URL
      final newUri = uri.replace(pathSegments: newPathSegments);
      return newUri.toString();
    } catch (e) {
      debugPrint('VideoUploadService: Error generating Cloudinary URL: $e');
      return originalUrl; // Fallback to original URL on error
    }
  }

  /// Extracts the public ID from a Cloudinary URL.
  ///
  /// Cloudinary URL structure:
  /// https://res.cloudinary.com/<cloud_name>/video/upload/v<version>/<public_id>
  ///
  /// Returns the public ID part (everything after 'upload/v<version>/')
  /// or null if the URL structure is invalid.
  String? _extractPublicId(String cloudinaryUrl) {
    try {
      final uri = Uri.parse(cloudinaryUrl);
      final pathSegments = uri.pathSegments;

      // Find the index of 'upload' in the path
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex >= pathSegments.length - 1) {
        debugPrint(
            'VideoUploadService: Invalid Cloudinary URL structure: $cloudinaryUrl');
        return null;
      }

      // The public ID is everything after 'upload'
      // Usually: ['upload', 'v<version>', '<public_id>', ...]
      // We want everything after 'upload' joined together
      final publicIdSegments = pathSegments.sublist(uploadIndex + 1);
      if (publicIdSegments.isEmpty) {
        return null;
      }

      // Join all segments after 'upload' to get the full public ID
      // This handles cases where public_id contains slashes
      return publicIdSegments.join('/');
    } catch (e) {
      debugPrint('VideoUploadService: Error extracting public ID: $e');
      return null;
    }
  }
}
