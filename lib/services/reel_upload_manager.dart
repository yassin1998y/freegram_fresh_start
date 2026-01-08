// lib/services/reel_upload_manager.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:freegram/services/video_upload_service.dart';
import 'package:freegram/models/reel_model.dart';

/// Upload progress data
class UploadProgress {
  final double progress; // 0.0 to 1.0
  final String? statusText;

  const UploadProgress({
    required this.progress,
    this.statusText,
  });
}

/// Background upload manager for reels
///
/// Features:
/// - Queue management (supports multiple uploads)
/// - Progress streaming
/// - Background processing
/// - Error handling with retry support
class ReelUploadManager {
  final VideoUploadService _uploadService = VideoUploadService();

  // Active uploads map: uploadId -> StreamController
  final Map<String, StreamController<UploadProgress>> _activeUploads = {};
  final Map<String, Future<ReelModel?>> _uploadFutures = {};
  // Completed uploads: uploadId -> ReelModel
  final Map<String, ReelModel> _completedUploads = {};

  /// Start an upload and return a stream of progress updates
  Stream<UploadProgress> startUpload({
    required String uploadId,
    required String videoPath,
    String? caption,
    List<String> hashtags = const [],
    List<String> mentions = const [],
  }) {
    // Create stream controller for this upload
    final controller = StreamController<UploadProgress>.broadcast();
    _activeUploads[uploadId] = controller;

    // Start upload in background
    _uploadFutures[uploadId] = _performUpload(
      uploadId: uploadId,
      videoPath: videoPath,
      caption: caption,
      hashtags: hashtags,
      mentions: mentions,
      progressController: controller,
    );

    // Handle completion/error
    _uploadFutures[uploadId]!.then((reel) {
      if (reel != null) {
        // Store completed reel for retrieval
        _completedUploads[uploadId] = reel;
        controller
            .add(const UploadProgress(progress: 1.0, statusText: 'Complete'));
        controller.close();
      } else {
        controller.addError('Upload failed');
        controller.close();
      }
      _cleanup(uploadId);
    }).catchError((error) {
      controller.addError(error);
      controller.close();
      _cleanup(uploadId);
    });

    return controller.stream;
  }

  /// Perform the actual upload
  Future<ReelModel?> _performUpload({
    required String uploadId,
    required String videoPath,
    String? caption,
    required List<String> hashtags,
    required List<String> mentions,
    required StreamController<UploadProgress> progressController,
  }) async {
    try {
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        throw Exception('Video file not found: $videoPath');
      }

      // Upload using existing service
      final reel = await _uploadService.uploadReel(
        videoFile: videoFile,
        caption: caption,
        hashtags: hashtags.isEmpty ? null : hashtags,
        mentions: mentions.isEmpty ? null : mentions,
        onProgress: (progress) {
          // Map progress to status text
          String? statusText;
          if (progress < 0.1) {
            statusText = 'Preparing...';
          } else if (progress < 0.4) {
            statusText = 'Compressing...';
          } else if (progress < 0.5) {
            statusText = 'Generating thumbnail...';
          } else if (progress < 0.9) {
            statusText = 'Uploading...';
          } else if (progress < 1.0) {
            statusText = 'Finalizing...';
          } else {
            statusText = 'Complete';
          }

          // Emit progress update
          if (!progressController.isClosed) {
            progressController.add(UploadProgress(
              progress: progress,
              statusText: statusText,
            ));
          }
        },
      );

      return reel;
    } catch (e) {
      debugPrint('[ReelUploadManager] Upload error: $e');
      rethrow;
    }
  }

  /// Cancel an upload
  Future<void> cancelUpload(String uploadId) async {
    debugPrint('[ReelUploadManager] Cancelling upload: $uploadId');

    // Close progress stream
    _activeUploads[uploadId]?.close();
    _cleanup(uploadId);
  }

  /// Clean up resources for an upload
  void _cleanup(String uploadId) {
    _activeUploads.remove(uploadId);
    _uploadFutures.remove(uploadId);
    // Keep completed uploads for a short time (5 minutes) for retrieval
    Future.delayed(const Duration(minutes: 5), () {
      _completedUploads.remove(uploadId);
    });
  }

  /// Get completed reel for an upload ID
  ReelModel? getCompletedReel(String uploadId) {
    return _completedUploads[uploadId];
  }

  /// Check if an upload is in progress
  bool isUploading(String uploadId) {
    return _activeUploads.containsKey(uploadId);
  }

  /// Get all active upload IDs
  List<String> getActiveUploadIds() {
    return _activeUploads.keys.toList();
  }

  /// Dispose all resources
  void dispose() {
    for (final controller in _activeUploads.values) {
      controller.close();
    }
    _activeUploads.clear();
    _uploadFutures.clear();
  }
}
