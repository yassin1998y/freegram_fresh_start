// lib/utils/image_save_util.dart
// Utility for saving and sharing images from chat

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageSaveUtil {
  /// Save image to device storage
  /// Returns the file path if successful, null otherwise
  static Future<String?> saveImageToDevice(String imageUrl) async {
    try {
      // Request storage permission on Android
      if (Platform.isAndroid) {
        // For Android 10+ (API 29+), use Permission.photos
        // For older versions, use Permission.storage
        Permission permission;
        try {
          // Try to use photos permission (Android 10+)
          permission = Permission.photos;
          final photosStatus = await permission.status;
          if (!photosStatus.isGranted) {
            final result = await permission.request();
            if (!result.isGranted) {
              // Fallback to storage permission for older Android versions
              permission = Permission.storage;
              final storageStatus = await permission.status;
              if (!storageStatus.isGranted) {
                final storageResult = await permission.request();
                if (!storageResult.isGranted) {
                  debugPrint('ImageSaveUtil: Storage permission denied');
                  return null;
                }
              }
            }
          }
        } catch (e) {
          // If photos permission is not available, fallback to storage
          debugPrint(
              'ImageSaveUtil: Photos permission not available, using storage: $e');
          permission = Permission.storage;
          final status = await permission.status;
          if (!status.isGranted) {
            final result = await permission.request();
            if (!result.isGranted) {
              debugPrint('ImageSaveUtil: Storage permission denied');
              return null;
            }
          }
        }
      }

      // Download image
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        debugPrint(
            'ImageSaveUtil: Failed to download image: ${response.statusCode}');
        return null;
      }

      // Get directory for saving
      Directory? directory;
      if (Platform.isAndroid) {
        // For Android 10+ (API 29+), use scoped storage
        // Try to save to Pictures directory first (works with scoped storage)
        try {
          directory = await getExternalStorageDirectory();
          if (directory != null) {
            // Navigate to Pictures directory
            // For Android 10+, this works with scoped storage
            final picturesDir =
                Directory('${directory.path}/Pictures/Freegram');
            if (!await picturesDir.exists()) {
              await picturesDir.create(recursive: true);
            }
            directory = picturesDir;
          }
        } catch (e) {
          debugPrint('ImageSaveUtil: Error accessing Pictures directory: $e');
          // Fallback to app's external files directory
          directory = await getExternalStorageDirectory();
        }

        // If still null, use app documents directory as last resort
        directory ??= await getApplicationDocumentsDirectory();
      } else {
        // iOS: Use app documents directory
        directory = await getApplicationDocumentsDirectory();
      }

      // Generate filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'freegram_$timestamp.jpg';
      final file = File('${directory.path}/$filename');

      // Save file
      await file.writeAsBytes(response.bodyBytes);

      // Verify file was saved
      if (!await file.exists()) {
        debugPrint('ImageSaveUtil: File was not created');
        return null;
      }

      debugPrint('ImageSaveUtil: Image saved to ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('ImageSaveUtil: Error saving image: $e');
      return null;
    }
  }

  /// Share image (can also save to gallery on some platforms)
  static Future<bool> shareImage(String imageUrl) async {
    try {
      // Download image to temporary file
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File('${tempDir.path}/share_$timestamp.jpg');
      await tempFile.writeAsBytes(response.bodyBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Shared from Freegram',
      );

      // Clean up temp file after a delay
      Future.delayed(const Duration(seconds: 5), () {
        try {
          if (tempFile.existsSync()) {
            tempFile.deleteSync();
          }
        } catch (_) {}
      });

      return true;
    } catch (e) {
      debugPrint('ImageSaveUtil: Error sharing image: $e');
      return false;
    }
  }
}
