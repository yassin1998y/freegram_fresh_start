// lib/services/gallery_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// Service for loading recent gallery photos
class GalleryService {
  /// Get recent photos from gallery (last 20)
  Future<List<AssetEntity>> getRecentPhotos({int limit = 20}) async {
    try {
      // Request permission using PhotoManager
      final PermissionState permissionState =
          await PhotoManager.requestPermissionExtend();

      if (!permissionState.isAuth) {
        debugPrint('GalleryService: Photos permission denied');
        return [];
      }

      // Load recent photos
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
        onlyAll: true,
      );

      if (albums.isEmpty) {
        debugPrint('GalleryService: No photo albums found');
        return [];
      }

      // Get the first album (usually "Recent" or "All Photos")
      final recentAlbum = albums.first;
      final photos = await recentAlbum.getAssetListRange(
        start: 0,
        end: limit,
      );

      return photos;
    } catch (e) {
      debugPrint('GalleryService: Error loading recent photos: $e');
      return [];
    }
  }

  /// Get recent videos from gallery (last 20)
  Future<List<AssetEntity>> getRecentVideos({int limit = 20}) async {
    try {
      // Request permission using PhotoManager
      final PermissionState permissionState =
          await PhotoManager.requestPermissionExtend();

      if (!permissionState.isAuth) {
        debugPrint('GalleryService: Videos permission denied');
        return [];
      }

      // Load recent videos
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        hasAll: true,
        onlyAll: true,
      );

      if (albums.isEmpty) {
        debugPrint('GalleryService: No video albums found');
        return [];
      }

      // Get the first album (usually "Recent" or "All Videos")
      final recentAlbum = albums.first;
      final videos = await recentAlbum.getAssetListRange(
        start: 0,
        end: limit,
      );

      return videos;
    } catch (e) {
      debugPrint('GalleryService: Error loading recent videos: $e');
      return [];
    }
  }

  /// Get file from AssetEntity
  /// CRITICAL FIX: Enhanced error handling and file verification
  /// Handles Android scoped storage by loading bytes if file access fails
  Future<File?> getFileFromAsset(AssetEntity asset) async {
    try {
      debugPrint(
          'GalleryService: Getting file from asset: ${asset.id}, type: ${asset.type}');

      File? file;

      // Try to get file directly first
      try {
        file = await asset.file;
        if (file != null && await file.exists()) {
          debugPrint('GalleryService: File loaded directly: ${file.path}');
          return file;
        }
      } catch (e) {
        debugPrint(
            'GalleryService: Error getting file directly: $e, trying bytes method');
      }

      // If direct file access fails (e.g., Android scoped storage), load as bytes
      try {
        debugPrint('GalleryService: Loading asset as bytes...');
        final bytes = await asset.originBytes;
        if (bytes == null || bytes.isEmpty) {
          debugPrint('GalleryService: Asset bytes are null or empty');
          return null;
        }

        // Save to temporary directory
        final tempDir = Directory.systemTemp;
        final extension = asset.type == AssetType.video ? 'mp4' : 'jpg';
        final tempFile = File(
            '${tempDir.path}/story_${DateTime.now().millisecondsSinceEpoch}_${asset.id}.$extension');
        await tempFile.writeAsBytes(bytes);

        // Verify the written file
        if (!await tempFile.exists()) {
          debugPrint('GalleryService: Failed to write temp file');
          return null;
        }

        final fileSize = await tempFile.length();
        if (fileSize == 0) {
          debugPrint('GalleryService: Temp file is empty');
          await tempFile.delete();
          return null;
        }

        debugPrint(
            'GalleryService: File copied to temp location: ${tempFile.path} (size: $fileSize bytes)');
        return tempFile;
      } catch (e) {
        debugPrint('GalleryService: Error loading asset as bytes: $e');
        return null;
      }
    } catch (e) {
      debugPrint('GalleryService: Error getting file from asset: $e');
      return null;
    }
  }

  /// Check if photos permission is granted
  Future<bool> hasPhotosPermission() async {
    try {
      final PermissionState state =
          await PhotoManager.requestPermissionExtend();
      return state.isAuth;
    } catch (e) {
      debugPrint('GalleryService: Error checking permission: $e');
      return false;
    }
  }

  /// Request photos permission
  Future<bool> requestPhotosPermission() async {
    try {
      final PermissionState state =
          await PhotoManager.requestPermissionExtend();
      return state.isAuth;
    } catch (e) {
      debugPrint('GalleryService: Error requesting permission: $e');
      return false;
    }
  }

  /// Save image to gallery
  Future<AssetEntity?> saveImage(Uint8List bytes, {String? title}) async {
    try {
      final String filename =
          'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final AssetEntity? image = await PhotoManager.editor.saveImage(
        bytes,
        title: title ?? 'Story Image',
        filename: filename,
      );
      return image;
    } catch (e) {
      debugPrint('GalleryService: Error saving image: $e');
      return null;
    }
  }

  /// Save video to gallery
  Future<AssetEntity?> saveVideo(File file, {String? title}) async {
    try {
      final AssetEntity? video = await PhotoManager.editor.saveVideo(
        file,
        title: title ?? 'Story Video',
      );
      return video;
    } catch (e) {
      debugPrint('GalleryService: Error saving video: $e');
      return null;
    }
  }
}
