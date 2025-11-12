// lib/services/story_upload_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/repositories/story_repository.dart';
import 'package:freegram/models/upload_progress_model.dart';
import 'package:freegram/models/text_overlay_model.dart';
import 'package:freegram/models/drawing_path_model.dart';
import 'package:freegram/models/sticker_overlay_model.dart';
import 'package:freegram/services/upload_progress_service.dart';
import 'package:freegram/services/upload_notification_service.dart';
import 'package:freegram/services/cloudinary_service.dart';
import 'package:freegram/services/video_upload_service.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service for uploading stories
/// Handles media upload, progress tracking, and story creation
class StoryUploadService {
  final StoryRepository _storyRepository;
  final UploadProgressService _uploadProgressService;
  final UploadNotificationService _uploadNotificationService;
  final VideoUploadService _videoUploadService;

  StoryUploadService({
    required StoryRepository storyRepository,
    required UploadProgressService uploadProgressService,
    required UploadNotificationService uploadNotificationService,
    required VideoUploadService videoUploadService,
  })  : _storyRepository = storyRepository,
        _uploadProgressService = uploadProgressService,
        _uploadNotificationService = uploadNotificationService,
        _videoUploadService = videoUploadService;

  /// Upload story with progress tracking
  Future<void> uploadStory({
    required String userId,
    required String mediaType,
    required File? mediaFile,
    required Uint8List? mediaBytes,
    double? videoDuration,
    List<TextOverlay>? textOverlays,
    List<DrawingPath>? drawings,
    List<StickerOverlay>? stickerOverlays,
    required Function(double progress, String step) onProgress,
    required Function(String error) onError,
    required Function() onSuccess,
  }) async {
    final uploadId = _uploadProgressService.startUpload(
      currentStep: 'Preparing media...',
    );

    try {
      // Step 1: Upload media to Cloudinary
      onProgress(0.5, 'Uploading to server...');
      _uploadProgressService.updateProgress(
        uploadId: uploadId,
        state: UploadState.uploading,
        progress: 0.5,
        currentStep: 'Uploading to server...',
      );
      _uploadNotificationService.showUploadProgress(
        uploadId: uploadId,
        progress: 0.5,
        currentStep: 'Uploading...',
      );

      String? mediaUrl;
      String? thumbnailUrl;
      Map<String, String>? videoQualities;

      if (kIsWeb && mediaBytes != null) {
        // Web upload
        mediaUrl = await CloudinaryService.uploadImageFromBytes(
              mediaBytes,
              filename: 'story_${DateTime.now().millisecondsSinceEpoch}.jpg',
              onProgress: (progress) {
                final totalProgress = 0.5 + (progress * 0.4); // 50-90%
                onProgress(totalProgress, 'Uploading to server...');
                _uploadProgressService.updateProgress(
                  uploadId: uploadId,
                  progress: totalProgress,
                  currentStep: 'Uploading to server...',
                );
                _uploadNotificationService.updateUploadProgress(
                  uploadId: uploadId,
                  progress: totalProgress,
                  currentStep: 'Uploading...',
                );
              },
            ) ??
            '';

        if (mediaUrl.isEmpty) {
          throw Exception('Failed to upload image to Cloudinary');
        }
      } else if (!kIsWeb && mediaFile != null) {
        // Mobile upload
        if (mediaType == 'video') {
          // Get video duration if not provided
          if (videoDuration == null) {
            final controller = VideoPlayerController.file(mediaFile);
            await controller.initialize();
            videoDuration = controller.value.duration.inSeconds.toDouble();
            await controller.dispose();
          }

          // Upload video with multiple qualities
          videoQualities =
              await _videoUploadService.uploadVideoWithMultipleQualities(
            mediaFile,
            onProgress: (progress) {
              final totalProgress = 0.5 + (progress * 0.4); // 50-90%
              onProgress(totalProgress, 'Uploading to server...');
              _uploadProgressService.updateProgress(
                uploadId: uploadId,
                progress: totalProgress,
                currentStep: 'Uploading to server...',
              );
              _uploadNotificationService.updateUploadProgress(
                uploadId: uploadId,
                progress: totalProgress,
                currentStep: 'Uploading...',
              );
            },
          );

          if (videoQualities == null || videoQualities['videoUrl'] == null) {
            throw Exception('Failed to upload video to Cloudinary');
          }
          mediaUrl = videoQualities['videoUrl']!;

          // Generate thumbnail
          try {
            final thumbnailData =
                await video_thumbnail.VideoThumbnail.thumbnailData(
              video: mediaFile.path,
              imageFormat: video_thumbnail.ImageFormat.JPEG,
              maxWidth: 400,
              quality: 75,
            );
            if (thumbnailData != null) {
              final tempDir = await getTemporaryDirectory();
              final thumbnailFile = File(path.join(
                tempDir.path,
                'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
              ));
              await thumbnailFile.writeAsBytes(thumbnailData);
              thumbnailUrl =
                  await CloudinaryService.uploadImageFromFile(thumbnailFile);
              await thumbnailFile.delete();
            }
          } catch (e) {
            debugPrint('StoryUploadService: Error generating thumbnail: $e');
          }
        } else {
          // Upload image
          mediaUrl = await CloudinaryService.uploadImageFromFile(
                mediaFile,
                onProgress: (progress) {
                  final totalProgress = 0.5 + (progress * 0.4); // 50-90%
                  onProgress(totalProgress, 'Uploading to server...');
                  _uploadProgressService.updateProgress(
                    uploadId: uploadId,
                    progress: totalProgress,
                    currentStep: 'Uploading to server...',
                  );
                  _uploadNotificationService.updateUploadProgress(
                    uploadId: uploadId,
                    progress: totalProgress,
                    currentStep: 'Uploading...',
                  );
                },
              ) ??
              '';

          if (mediaUrl.isEmpty) {
            throw Exception('Failed to upload media to Cloudinary');
          }
        }
      } else {
        throw Exception('No media available');
      }

      // Step 2: Create story in Firestore
      onProgress(0.9, 'Finalizing...');
      _uploadProgressService.updateProgress(
        uploadId: uploadId,
        state: UploadState.finalizing,
        progress: 0.9,
        currentStep: 'Finalizing...',
      );

      if (kIsWeb && mediaBytes != null) {
        await _storyRepository.createStoryFromBytes(
          userId: userId,
          mediaBytes: mediaBytes,
          mediaType: mediaType,
          textOverlays: textOverlays,
          drawings: drawings,
          stickerOverlays: stickerOverlays,
        );
      } else if (!kIsWeb) {
        await _storyRepository.createStory(
          userId: userId,
          mediaType: mediaType,
          videoDuration: videoDuration,
          textOverlays: textOverlays,
          drawings: drawings,
          stickerOverlays: stickerOverlays,
          preUploadedMediaUrl: mediaUrl,
          preUploadedVideoQualities: videoQualities,
          preUploadedThumbnailUrl: thumbnailUrl,
        );
      }

      // Complete upload
      _uploadProgressService.completeUpload(uploadId);
      _uploadNotificationService.showUploadComplete(uploadId: uploadId);
      onProgress(1.0, 'Complete');
      onSuccess();
    } catch (e) {
      _uploadProgressService.failUpload(uploadId, e.toString());
      _uploadNotificationService.showUploadFailed(
        uploadId: uploadId,
        errorMessage: e.toString(),
      );
      onError(e.toString());
      rethrow;
    }
  }
}
