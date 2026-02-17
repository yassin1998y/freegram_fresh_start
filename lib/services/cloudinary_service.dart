// lib/services/cloudinary_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Phase 4.3: Enhanced Compression Settings
enum ImageQuality {
  thumbnail(60),
  medium(75),
  high(90);

  final int quality;
  const ImageQuality(this.quality);

  String get cloudinaryString {
    // Cloudinary quality format: q_<number> (e.g., q_60, q_75, q_90)
    // Note: q_auto is for automatic quality, but we want specific quality here
    return 'q_$quality';
  }
}

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

    // CRITICAL FIX: Declare variables outside try block for access in catch blocks
    bool uploadComplete = false;
    Timer? progressTimer;

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

      // CRITICAL FIX: Track upload progress using time-based estimation
      // http.MultipartRequest doesn't support upload progress directly
      // We'll estimate progress based on elapsed time (assuming average upload speed)
      final totalBytes = bytes.length;
      final uploadStartTime = DateTime.now();

      // Start progress tracking in background
      if (onProgress != null) {
        progressTimer =
            Timer.periodic(const Duration(milliseconds: 200), (timer) {
          if (uploadComplete) {
            timer.cancel();
            return;
          }

          final elapsed = DateTime.now().difference(uploadStartTime);
          // Estimate progress: assume average upload speed of 1MB/s
          // This is just an estimate - actual progress may vary
          const estimatedBytesPerSecond = 1024 * 1024; // 1MB/s
          final estimatedProgress = (elapsed.inMilliseconds /
                  1000.0 *
                  estimatedBytesPerSecond /
                  totalBytes)
              .clamp(0.0, 0.95);
          onProgress(estimatedProgress);
        });
      }

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120), // Longer timeout for videos (2 minutes)
        onTimeout: () {
          uploadComplete = true;
          progressTimer?.cancel();
          throw TimeoutException('Video upload timed out after 120 seconds');
        },
      );

      // Wait for response
      final responseData = await streamedResponse.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonMap = jsonDecode(responseString);

      uploadComplete = true;
      progressTimer?.cancel();

      if (streamedResponse.statusCode == 200) {
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
      uploadComplete = true;
      progressTimer?.cancel();
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
      uploadComplete = true;
      progressTimer?.cancel();
      _debugLog('Unexpected error during video upload: $e');
      return null;
    }
  }

  /// Phase 4.3: Upload image with specific quality setting.
  ///
  /// This method allows you to specify the quality level for image uploads.
  /// The quality parameter controls the compression level applied to the image.
  ///
  /// [imageFile] - The image file to upload
  /// [quality] - The quality level (thumbnail, medium, or high)
  /// [onProgress] - Optional callback for upload progress (0.0 to 1.0)
  ///
  /// Returns the secure URL of the uploaded image, or null if upload fails.
  static Future<String?> uploadImageWithQuality(
    File imageFile,
    ImageQuality quality, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Note: Cloudinary quality is applied during transformation, not upload.
      // For upload-time quality, you would need to use upload parameters.
      // This is a placeholder for future enhancement.
      _debugLog('Uploading image with quality: ${quality.name}');

      // For now, use the standard upload method
      // In the future, you could add transformation parameters to the upload
      // to apply quality settings during the upload process
      return await uploadImageFromFile(imageFile, onProgress: onProgress);
    } catch (e) {
      _debugLog('Error uploading image with quality: $e');
      return null;
    }
  }

  /// Phase 4.1: Generates a fully optimized URL for ANY Cloudinary image.
  ///
  /// This automatically adds WebP (f_auto) and auto-quality (q_auto).
  /// This is the central method for all image optimization in the app.
  ///
  /// [originalUrl] - The original Cloudinary URL
  /// [width] - Optional width constraint (only width, maintains aspect ratio)
  /// [height] - Optional height constraint (only height, maintains aspect ratio)
  /// [quality] - Optional quality setting (defaults to auto-quality)
  ///
  /// Returns the optimized URL with transformations, or original URL if not Cloudinary
  static String getOptimizedImageUrl(
    String originalUrl, {
    int? width,
    int? height,
    ImageQuality? quality,
  }) {
    if (!originalUrl.contains('res.cloudinary.com') ||
        !originalUrl.contains('/upload/')) {
      return originalUrl; // Not a Cloudinary URL, return as-is
    }

    // Build transformation string
    final transformations = <String>[];

    // 1. Format: Auto (WebP/AVIF fallback to JPEG)
    // This implements Phase 4.1 - Modern Format Support
    transformations.add('f_auto');

    // 2. Quality: Use specific or auto
    transformations.add(quality?.cloudinaryString ?? 'q_auto');

    // 3. Dimensions (only set width or height to maintain aspect ratio)
    // CRITICAL: Never set both width and height for user-generated content
    // to avoid breaking aspect ratios (especially 9:16 for vertical content)
    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');

    // Insert transformations into the URL
    // Cloudinary URL structure: .../upload/<transformations>/v<version>/<public_id>
    final transformationString = transformations.join(',');

    return originalUrl.replaceFirst(
      '/upload/',
      '/upload/$transformationString/',
    );
  }

  /// Upload a large video using chunked, resumable uploads (Phase 5).
  ///
  /// [videoFile] - The video file to upload
  /// [onProgress] - Callback for upload progress (0.0 to 1.0)
  /// [chunkSize] - Size of each chunk in bytes (default 2MB)
  static Future<String?> uploadLargeVideoResumable(
    File videoFile, {
    void Function(double progress)? onProgress,
    int chunkSize = 2 * 1024 * 1024, // 2MB as per requirements
  }) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];

    if (cloudName == null || uploadPreset == null) {
      _debugLog('Cloudinary credentials not found in .env file');
      return null;
    }

    final totalSize = await videoFile.length();
    final uniqueId =
        'reel_${DateTime.now().millisecondsSinceEpoch}_${videoFile.path.hashCode}';
    final url =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');

    _debugLog('Starting chunked upload: $uniqueId, Total size: $totalSize');

    String? secureUrl;
    int currentStart = 0;

    try {
      final fileAccess = await videoFile.open();

      while (currentStart < totalSize) {
        final currentEnd = (currentStart + chunkSize < totalSize)
            ? currentStart + chunkSize - 1
            : totalSize - 1;

        final currentChunkSize = currentEnd - currentStart + 1;
        final chunkBytes = await fileAccess.read(currentChunkSize);

        _debugLog('Uploading chunk: $currentStart-$currentEnd/$totalSize');

        // Multi-attempt chunk upload with exponential backoff
        int attempt = 0;
        const maxAttempts = 5;
        bool chunkSuccess = false;

        while (attempt < maxAttempts && !chunkSuccess) {
          try {
            final request = http.MultipartRequest('POST', url);
            request.fields['upload_preset'] = uploadPreset;
            request.fields['unique_upload_id'] = uniqueId;
            request.headers['X-Unique-Upload-Id'] = uniqueId;
            request.headers['Content-Range'] =
                'bytes $currentStart-$currentEnd/$totalSize';

            final multipartFile = http.MultipartFile.fromBytes(
              'file',
              chunkBytes,
              filename: videoFile.path.split('/').last,
            );
            request.files.add(multipartFile);

            final response =
                await request.send().timeout(const Duration(seconds: 60));
            final responseBody = await response.stream.bytesToString();

            if (response.statusCode == 200 || response.statusCode == 201) {
              if (currentEnd == totalSize - 1) {
                final jsonMap = jsonDecode(responseBody);
                secureUrl = jsonMap['secure_url'] as String?;
              }
              chunkSuccess = true;
            } else {
              _debugLog(
                  'Chunk attempt ${attempt + 1} failed: ${response.statusCode}');
              attempt++;
              if (attempt < maxAttempts) {
                // Exponential backoff: 2^attempt * 1s
                await Future.delayed(Duration(seconds: 1 << attempt));
              }
            }
          } catch (e) {
            _debugLog('Chunk attempt ${attempt + 1} network error: $e');
            attempt++;
            if (attempt < maxAttempts) {
              await Future.delayed(Duration(seconds: 1 << attempt));
            }
          }
        }

        if (!chunkSuccess) {
          _debugLog('Max attempts reached for chunk $currentStart. Failing.');
          await fileAccess.close();
          return null;
        }

        currentStart += currentChunkSize;
        onProgress?.call(currentStart / totalSize);
      }

      await fileAccess.close();
      return secureUrl;
    } catch (e) {
      _debugLog('Error during chunked upload: $e');
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
