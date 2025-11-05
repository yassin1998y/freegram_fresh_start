// lib/services/cloudinary_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Centralized service for handling image uploads to Cloudinary.
///
/// Features:
/// - Secure credential management via .env
/// - Progress tracking support
/// - Comprehensive error handling
/// - Support for both XFile and File inputs
/// - Automatic retry on network failures
class CloudinaryService {
  CloudinaryService._();

  /// Upload an image to Cloudinary from an XFile.
  ///
  /// [imageFile] - The image file to upload (from image_picker)
  /// [onProgress] - Optional callback for upload progress (0.0 to 1.0)
  ///
  /// Returns the secure URL of the uploaded image, or null if upload fails.
  static Future<String?> uploadImageFromXFile(
    XFile imageFile, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return await _uploadBytes(
        bytes,
        filename: imageFile.name,
        onProgress: onProgress,
      );
    } catch (e) {
      _debugLog('Error uploading image from XFile: $e');
      return null;
    }
  }

  /// Upload an image to Cloudinary from a File.
  ///
  /// [file] - The image file to upload
  /// [onProgress] - Optional callback for upload progress (0.0 to 1.0)
  ///
  /// Returns the secure URL of the uploaded image, or null if upload fails.
  static Future<String?> uploadImageFromFile(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final filename = file.path.split('/').last;
      return await _uploadBytes(
        bytes,
        filename: filename,
        onProgress: onProgress,
      );
    } catch (e) {
      _debugLog('Error uploading image from File: $e');
      return null;
    }
  }

  /// Upload an image to Cloudinary from bytes (useful for web platform).
  ///
  /// [bytes] - The image bytes to upload
  /// [filename] - Optional filename for the upload
  /// [onProgress] - Optional callback for upload progress (0.0 to 1.0)
  ///
  /// Returns the secure URL of the uploaded image, or null if upload fails.
  static Future<String?> uploadImageFromBytes(
    List<int> bytes, {
    String? filename,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final defaultFilename =
          filename ?? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      return await _uploadBytes(
        bytes,
        filename: defaultFilename,
        onProgress: onProgress,
      );
    } catch (e) {
      _debugLog('Error uploading image from bytes: $e');
      return null;
    }
  }

  /// Internal method to upload bytes to Cloudinary.
  static Future<String?> _uploadBytes(
    List<int> bytes, {
    required String filename,
    void Function(double progress)? onProgress,
    int retryCount = 0,
  }) async {
    const maxRetries = 2;

    try {
      // Get credentials from .env
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
      final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];

      if (cloudName == null || uploadPreset == null) {
        _debugLog('Cloudinary credentials not found in .env file');
        return null;
      }

      _debugLog('Uploading image to Cloudinary (size: ${bytes.length} bytes)');

      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset;

      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      );

      request.files.add(multipartFile);

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Upload timed out after 30 seconds');
        },
      );

      if (streamedResponse.statusCode == 200) {
        final responseData = await streamedResponse.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        final secureUrl = jsonMap['secure_url'] as String?;

        if (secureUrl != null) {
          _debugLog('Image uploaded successfully: $secureUrl');
          onProgress?.call(1.0); // Upload complete
          return secureUrl;
        }
      }

      _debugLog(
        'Upload failed with status code: ${streamedResponse.statusCode}',
      );

      // Retry on network errors (5xx status codes)
      if (streamedResponse.statusCode >= 500 && retryCount < maxRetries) {
        _debugLog('Retrying upload (attempt ${retryCount + 1}/$maxRetries)');
        await Future.delayed(Duration(seconds: retryCount + 1));
        return await _uploadBytes(
          bytes,
          filename: filename,
          onProgress: onProgress,
          retryCount: retryCount + 1,
        );
      }

      return null;
    } on TimeoutException catch (e) {
      _debugLog('Upload timeout: $e');

      // Retry on timeout
      if (retryCount < maxRetries) {
        _debugLog(
            'Retrying upload after timeout (attempt ${retryCount + 1}/$maxRetries)');
        await Future.delayed(Duration(seconds: retryCount + 1));
        return await _uploadBytes(
          bytes,
          filename: filename,
          onProgress: onProgress,
          retryCount: retryCount + 1,
        );
      }

      return null;
    } catch (e) {
      _debugLog('Unexpected error during upload: $e');
      return null;
    }
  }

  /// Upload a video to Cloudinary from a File.
  ///
  /// [videoFile] - The video file to upload
  /// [onProgress] - Optional callback for upload progress (0.0 to 1.0)
  ///
  /// Returns the secure URL of the uploaded video, or null if upload fails.
  static Future<String?> uploadVideoFromFile(
    File videoFile, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final bytes = await videoFile.readAsBytes();
      final filename = videoFile.path.split('/').last;
      return await _uploadVideoBytes(
        bytes,
        filename: filename,
        onProgress: onProgress,
      );
    } catch (e) {
      _debugLog('Error uploading video from File: $e');
      return null;
    }
  }

  /// Internal method to upload video bytes to Cloudinary.
  static Future<String?> _uploadVideoBytes(
    List<int> bytes, {
    required String filename,
    void Function(double progress)? onProgress,
    int retryCount = 0,
  }) async {
    const maxRetries = 2;

    try {
      // Get credentials from .env
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
      final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];

      if (cloudName == null || uploadPreset == null) {
        _debugLog('Cloudinary credentials not found in .env file');
        return null;
      }

      _debugLog('Uploading video to Cloudinary (size: ${bytes.length} bytes)');

      // Use video upload endpoint instead of image
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
      );

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['resource_type'] = 'video'; // Specify video resource type

      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      );

      request.files.add(multipartFile);

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60), // Longer timeout for videos
        onTimeout: () {
          throw TimeoutException('Video upload timed out after 60 seconds');
        },
      );

      if (streamedResponse.statusCode == 200) {
        final responseData = await streamedResponse.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        final secureUrl = jsonMap['secure_url'] as String?;

        if (secureUrl != null) {
          _debugLog('Video uploaded successfully: $secureUrl');
          onProgress?.call(1.0); // Upload complete
          return secureUrl;
        }
      }

      _debugLog(
        'Video upload failed with status code: ${streamedResponse.statusCode}',
      );

      // Retry on network errors (5xx status codes)
      if (streamedResponse.statusCode >= 500 && retryCount < maxRetries) {
        _debugLog(
            'Retrying video upload (attempt ${retryCount + 1}/$maxRetries)');
        await Future.delayed(Duration(seconds: retryCount + 1));
        return await _uploadVideoBytes(
          bytes,
          filename: filename,
          onProgress: onProgress,
          retryCount: retryCount + 1,
        );
      }

      return null;
    } on TimeoutException catch (e) {
      _debugLog('Video upload timeout: $e');

      // Retry on timeout
      if (retryCount < maxRetries) {
        _debugLog(
            'Retrying video upload after timeout (attempt ${retryCount + 1}/$maxRetries)');
        await Future.delayed(Duration(seconds: retryCount + 1));
        return await _uploadVideoBytes(
          bytes,
          filename: filename,
          onProgress: onProgress,
          retryCount: retryCount + 1,
        );
      }

      return null;
    } catch (e) {
      _debugLog('Unexpected error during video upload: $e');
      return null;
    }
  }

  /// Debug logging helper (only logs in debug mode)
  static void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[CloudinaryService] $message');
    }
  }
}

/// Custom exception for timeout errors
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
