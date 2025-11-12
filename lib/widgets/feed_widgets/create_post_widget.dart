// lib/widgets/feed_widgets/create_post_widget.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/utils/image_url_validator.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/page_repository.dart';
import 'package:freegram/models/page_model.dart';
import 'package:freegram/models/media_item_model.dart';
import 'package:freegram/services/cloudinary_service.dart';
import 'package:freegram/services/video_upload_service.dart';
import 'package:freegram/blocs/unified_feed_bloc.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:shimmer/shimmer.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/common/media_header.dart';

class CreatePostWidget extends StatefulWidget {
  const CreatePostWidget({Key? key}) : super(key: key);

  @override
  State<CreatePostWidget> createState() => _CreatePostWidgetState();
}

class _CreatePostWidgetState extends State<CreatePostWidget> {
  bool _isExpanded = false;
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  final PostRepository _postRepository = locator<PostRepository>();
  final PageRepository _pageRepository = locator<PageRepository>();
  final VideoUploadService _videoUploadService = VideoUploadService();

  final List<MediaItem> _mediaItems = [];
  final Map<int, TextEditingController> _captionControllers = {};
  final Map<int, bool> _uploadingMedia =
      {}; // Track upload state per media item
  final Map<int, double> _uploadProgress =
      {}; // Track upload progress per media item (0.0 to 1.0)
  final Map<int, String?> _localThumbnails =
      {}; // Track local thumbnail paths for videos during upload
  final Map<int, bool> _cancelledUploads =
      {}; // Track cancelled uploads to prevent state updates
  final Map<int, String> _uploadFileNames =
      {}; // Track file names for upload progress display
  final Map<int, int> _uploadFileSizes =
      {}; // Track file sizes in bytes for upload progress display
  final Map<int, DateTime> _uploadStartTimes =
      {}; // Track upload start time for speed calculation
  bool _isLocationEnabled = false;
  String _visibility = 'public'; // 'public', 'friends', 'nearby'
  String? _selectedPageId;
  List<PageModel> _userPages = [];
  bool _isPosting = false;
  GeoPoint? _location;
  String? _locationAddress;

  @override
  void initState() {
    super.initState();
    _loadUserPages();
    // Listen to focus changes to scroll into view when keyboard appears
    _textFieldFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_textFieldFocusNode.hasFocus && _isExpanded) {
      // Scroll to the TextField when it gains focus
      // Use a small delay to ensure the widget is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _textFieldFocusNode.hasFocus) {
          // Find the RenderObject and scroll to it
          final context = _textFieldFocusNode.context;
          if (context != null) {
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              alignment: 0.1, // Show slightly above center
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _textFieldFocusNode.removeListener(_onFocusChange);
    _contentController.dispose();
    _textFieldFocusNode.dispose();
    for (var controller in _captionControllers.values) {
      controller.dispose();
    }
    _captionControllers.clear();
    super.dispose();
  }

  Future<void> _loadUserPages() async {
    if (!mounted) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final pages = await _pageRepository.getUserPages(currentUser.uid);
      if (mounted) {
        setState(() {
          _userPages = pages;
        });
      }
    } catch (e) {
      debugPrint('CreatePostWidget: Error loading user pages: $e');
    }
  }

  void _expand() {
    if (mounted) {
      setState(() {
        _isExpanded = true;
      });
      // Auto-focus TextField after expansion animation
      Future.delayed(AnimationTokens.normal, () {
        if (mounted) {
          _textFieldFocusNode.requestFocus();
        }
      });
    }
  }

  void _collapse() {
    if (mounted) {
      setState(() {
        _isExpanded = false;
        _contentController.clear();
        _mediaItems.clear();
        for (var controller in _captionControllers.values) {
          controller.dispose();
        }
        _captionControllers.clear();
        _uploadingMedia.clear();
        _uploadProgress.clear();
        _localThumbnails.clear();
        _cancelledUploads.clear();
        _uploadFileNames.clear();
        _uploadFileSizes.clear();
        _uploadStartTimes.clear();
        _isLocationEnabled = false;
        _location = null;
        _locationAddress = null;
      });
    }
  }

  void _handleInputFieldTap() {
    // Expand directly to typing
    _expand();
  }

  void _handleMediaButtonTap() {
    // Expand widget and show media picker
    if (!_isExpanded) {
      _expand();
    }
    // Show media picker after a brief delay to allow expansion animation
    Future.delayed(AnimationTokens.normal, () {
      if (mounted) {
        _showMediaPicker();
      }
    });
  }

  void _showMediaPicker() {
    if (!mounted) return;

    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusXL),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: DesignTokens.spaceSM),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
              child: Text(
                'Add Media',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLG),
            // Options - Simplified to single unified picker
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: theme.colorScheme.primary,
                size: DesignTokens.iconLG,
              ),
              title: Text(
                'Take Photo or Video',
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                'Capture with camera',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: theme.colorScheme.primary,
                size: DesignTokens.iconLG,
              ),
              title: Text(
                'Choose from Gallery',
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                'Select images and videos',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickFromGalleryUnified();
              },
            ),
            const SizedBox(height: DesignTokens.spaceMD),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    if (!mounted) return;

    final theme = Theme.of(context);

    // Simplified: Show options in a cleaner way
    final cameraChoice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusXL),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: DesignTokens.spaceSM),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
              child: Text(
                'Capture Media',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            ListTile(
              leading: Icon(
                Icons.photo_camera,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: Icon(
                Icons.videocam,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Record Video'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
            const SizedBox(height: DesignTokens.spaceMD),
          ],
        ),
      ),
    );

    if (cameraChoice == null || !mounted) return;

    try {
      XFile? file;
      if (cameraChoice == 'video') {
        file = await _imagePicker.pickVideo(source: ImageSource.camera);
      } else {
        file = await _imagePicker.pickImage(source: ImageSource.camera);
      }

      if (file != null && mounted) {
        await _uploadAndAddMedia(
            file, cameraChoice == 'video' ? 'video' : 'image');
        _expand();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Unified gallery picker - allows selecting both images and videos
  /// Shows a simplified interface that lets users pick multiple media items
  Future<void> _pickFromGalleryUnified() async {
    if (!mounted) return;

    final theme = Theme.of(context);

    try {
      // Show simplified options - pick images or videos
      final mediaChoice = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radiusXL),
          ),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: DesignTokens.spaceSM),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMD),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMD),
                child: Text(
                  'Select Media',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMD),
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Photos'),
                subtitle: const Text('Select multiple images'),
                onTap: () => Navigator.pop(context, 'photos'),
              ),
              ListTile(
                leading: Icon(
                  Icons.video_library,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Videos'),
                subtitle: const Text('Select a video'),
                onTap: () => Navigator.pop(context, 'video'),
              ),
              const SizedBox(height: DesignTokens.spaceMD),
            ],
          ),
        ),
      );

      if (mediaChoice == null || !mounted) return;

      if (mediaChoice == 'photos') {
        // Pick multiple images
        final List<XFile> images = await _imagePicker.pickMultiImage();
        if (images.isNotEmpty && mounted) {
          for (final file in images) {
            await _uploadAndAddMedia(file, 'image');
          }
          _expand();
        }
      } else if (mediaChoice == 'video') {
        // Pick video
        final XFile? video = await _imagePicker.pickVideo(
          source: ImageSource.gallery,
        );
        if (video != null && mounted) {
          await _uploadAndAddMedia(video, 'video');
          _expand();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking from gallery: $e')),
        );
      }
    }
  }

  Future<void> _uploadAndAddMedia(XFile file, String type) async {
    if (!mounted) return;

    final newIndex = _mediaItems.length;
    final fileSize = await file.length();
    final fileName = file.name;
    final uploadStartTime = DateTime.now();

    // Add placeholder item immediately with loading state
    setState(() {
      _uploadingMedia[newIndex] = true;
      _uploadProgress[newIndex] = 0.0;
      _uploadFileNames[newIndex] = fileName;
      _uploadFileSizes[newIndex] = fileSize;
      _uploadStartTimes[newIndex] = uploadStartTime;
      _mediaItems.add(MediaItem(url: '', type: type)); // Placeholder
      _cancelledUploads[newIndex] = false;
    });

    try {
      if (type == 'video') {
        // For video, use VideoUploadService to upload with multiple qualities
        final videoFile = File(file.path);

        // Upload video with multiple qualities
        debugPrint(
            'CreatePostWidget: Starting video upload for: ${videoFile.path}');
        debugPrint(
            'CreatePostWidget: Video file exists: ${await videoFile.exists()}');

        if (!await videoFile.exists()) {
          throw Exception(
              'Video file does not exist at path: ${videoFile.path}');
        }

        final fileSize = await videoFile.length();
        debugPrint('CreatePostWidget: Video file size: $fileSize bytes');

        if (fileSize == 0) {
          throw Exception('Video file is empty');
        }

        // Generate thumbnail immediately for preview during upload
        String? localThumbnailPath;
        try {
          final thumbnailData = await VideoThumbnail.thumbnailData(
            video: videoFile.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 200, // Smaller for preview
            quality: 85,
          );

          if (thumbnailData != null &&
              mounted &&
              !(_cancelledUploads[newIndex] ?? false)) {
            final tempDir = await getTemporaryDirectory();
            final thumbnailFile = File(
              path.join(
                tempDir.path,
                'thumb_${DateTime.now().millisecondsSinceEpoch}_$newIndex.jpg',
              ),
            );
            await thumbnailFile.writeAsBytes(thumbnailData);
            localThumbnailPath = thumbnailFile.path;

            setState(() {
              _localThumbnails[newIndex] = localThumbnailPath;
            });
          }
        } catch (e) {
          debugPrint(
              'CreatePostWidget: Error generating preview thumbnail: $e');
          // Continue without thumbnail preview
        }

        // Check if upload was cancelled before starting
        if (_cancelledUploads[newIndex] ?? false) {
          return;
        }

        final videoQualities =
            await _videoUploadService.uploadVideoWithMultipleQualities(
          videoFile,
          onProgress: (progress) {
            // Update progress state to show in UI (only if not cancelled)
            if (mounted && !(_cancelledUploads[newIndex] ?? false)) {
              setState(() {
                _uploadProgress[newIndex] = progress;
              });
            }
            debugPrint(
                'Video upload progress: ${(progress * 100).toStringAsFixed(1)}%');
          },
        );

        // Check if upload was cancelled after completion
        if (_cancelledUploads[newIndex] ?? false) {
          return;
        }

        debugPrint('CreatePostWidget: Video upload result: $videoQualities');

        if (videoQualities == null ||
            videoQualities['videoUrl'] == null ||
            videoQualities['videoUrl']!.isEmpty) {
          debugPrint(
              'CreatePostWidget: Video upload failed - videoQualities: $videoQualities');
          throw Exception(
              'Video upload failed: ${videoQualities == null ? "null result" : "empty videoUrl"}');
        }

        debugPrint(
            'CreatePostWidget: Video URLs - main: ${videoQualities['videoUrl']}, 360p: ${videoQualities['videoUrl360p']}, 720p: ${videoQualities['videoUrl720p']}, 1080p: ${videoQualities['videoUrl1080p']}');

        // Validate that we have at least one valid video URL
        final mainVideoUrl = videoQualities['videoUrl'] ?? '';
        if (mainVideoUrl.isEmpty) {
          throw Exception('Video upload failed: main videoUrl is empty');
        }

        // Generate thumbnail
        File? thumbnailFile;
        try {
          final thumbnailData = await VideoThumbnail.thumbnailData(
            video: videoFile.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 720,
            quality: 85,
          );

          if (thumbnailData != null) {
            // Upload thumbnail to Cloudinary
            final tempDir = await getTemporaryDirectory();
            thumbnailFile = File(
              path.join(
                tempDir.path,
                'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
              ),
            );
            await thumbnailFile.writeAsBytes(thumbnailData);
            final thumbnailUrl =
                await CloudinaryService.uploadImageFromFile(thumbnailFile);

            // Clean up temp thumbnail file
            try {
              await thumbnailFile.delete();
            } catch (e) {
              debugPrint('Error deleting temp thumbnail: $e');
            }

            if (mounted) {
              final captionController = TextEditingController();
              _captionControllers[newIndex] = captionController;

              // Extract video URLs, ensuring they're not empty strings
              final videoUrl360p = videoQualities['videoUrl360p'];
              final videoUrl720p = videoQualities['videoUrl720p'];
              final videoUrl1080p = videoQualities['videoUrl1080p'];

              final mediaItem = MediaItem(
                url: mainVideoUrl,
                type: 'video',
                thumbnailUrl: thumbnailUrl,
                videoUrl360p: (videoUrl360p != null && videoUrl360p.isNotEmpty)
                    ? videoUrl360p
                    : null,
                videoUrl720p: (videoUrl720p != null && videoUrl720p.isNotEmpty)
                    ? videoUrl720p
                    : null,
                videoUrl1080p:
                    (videoUrl1080p != null && videoUrl1080p.isNotEmpty)
                        ? videoUrl1080p
                        : null,
              );

              debugPrint(
                  'CreatePostWidget: Created MediaItem: ${mediaItem.toMap()}');
              debugPrint(
                  'CreatePostWidget: MediaItem.toMap() result: ${mediaItem.toMap()}');

              setState(() {
                _mediaItems[newIndex] = mediaItem;
                _uploadingMedia.remove(newIndex);
                _uploadProgress.remove(newIndex);
                _localThumbnails.remove(newIndex);
                _cancelledUploads.remove(newIndex);
                _uploadFileNames.remove(newIndex);
                _uploadFileSizes.remove(newIndex);
                _uploadStartTimes.remove(newIndex);
              });

              // Clean up local thumbnail file
              if (localThumbnailPath != null) {
                try {
                  final thumbFile = File(localThumbnailPath);
                  if (await thumbFile.exists()) {
                    await thumbFile.delete();
                  }
                } catch (e) {
                  debugPrint('Error deleting local thumbnail: $e');
                }
              }
            }
          } else {
            // Thumbnail generation failed, but continue with video upload
            if (mounted) {
              final captionController = TextEditingController();
              _captionControllers[newIndex] = captionController;

              // Extract video URLs, ensuring they're not empty strings
              final videoUrl360p = videoQualities['videoUrl360p'];
              final videoUrl720p = videoQualities['videoUrl720p'];
              final videoUrl1080p = videoQualities['videoUrl1080p'];

              final mediaItem = MediaItem(
                url: mainVideoUrl,
                type: 'video',
                videoUrl360p: (videoUrl360p != null && videoUrl360p.isNotEmpty)
                    ? videoUrl360p
                    : null,
                videoUrl720p: (videoUrl720p != null && videoUrl720p.isNotEmpty)
                    ? videoUrl720p
                    : null,
                videoUrl1080p:
                    (videoUrl1080p != null && videoUrl1080p.isNotEmpty)
                        ? videoUrl1080p
                        : null,
              );

              debugPrint(
                  'CreatePostWidget: Created MediaItem (no thumbnail): ${mediaItem.toMap()}');

              setState(() {
                _mediaItems[newIndex] = mediaItem;
                _uploadingMedia.remove(newIndex);
                _uploadProgress.remove(newIndex);
                _localThumbnails.remove(newIndex);
                _cancelledUploads.remove(newIndex);
                _uploadFileNames.remove(newIndex);
                _uploadFileSizes.remove(newIndex);
                _uploadStartTimes.remove(newIndex);
              });

              // Clean up local thumbnail file
              if (localThumbnailPath != null) {
                try {
                  final thumbFile = File(localThumbnailPath);
                  if (await thumbFile.exists()) {
                    await thumbFile.delete();
                  }
                } catch (e) {
                  debugPrint('Error deleting local thumbnail: $e');
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error generating thumbnail: $e');
          // Continue without thumbnail
          if (mounted) {
            final captionController = TextEditingController();
            _captionControllers[newIndex] = captionController;

            // Extract video URLs, ensuring they're not empty strings
            final videoUrl360p = videoQualities['videoUrl360p'];
            final videoUrl720p = videoQualities['videoUrl720p'];
            final videoUrl1080p = videoQualities['videoUrl1080p'];

            final mediaItem = MediaItem(
              url: mainVideoUrl,
              type: 'video',
              videoUrl360p: (videoUrl360p != null && videoUrl360p.isNotEmpty)
                  ? videoUrl360p
                  : null,
              videoUrl720p: (videoUrl720p != null && videoUrl720p.isNotEmpty)
                  ? videoUrl720p
                  : null,
              videoUrl1080p: (videoUrl1080p != null && videoUrl1080p.isNotEmpty)
                  ? videoUrl1080p
                  : null,
            );

            debugPrint(
                'CreatePostWidget: Created MediaItem (thumbnail error): ${mediaItem.toMap()}');

            setState(() {
              _mediaItems[newIndex] = mediaItem;
              _uploadingMedia.remove(newIndex);
            });
          }
        }
      } else {
        // For images, use the existing image upload logic with progress tracking
        final url = await CloudinaryService.uploadImageFromXFile(
          file,
          onProgress: (progress) {
            // Update progress state to show in UI (only if not cancelled)
            if (mounted && !(_cancelledUploads[newIndex] ?? false)) {
              setState(() {
                _uploadProgress[newIndex] = progress;
              });
            }
          },
        );

        // Check if upload was cancelled after completion
        if (_cancelledUploads[newIndex] ?? false) {
          return;
        }

        if (url != null && mounted) {
          final captionController = TextEditingController();
          _captionControllers[newIndex] = captionController;

          setState(() {
            _mediaItems[newIndex] = MediaItem(url: url, type: 'image');
            _uploadingMedia.remove(newIndex);
            _uploadProgress.remove(newIndex);
            _uploadFileNames.remove(newIndex);
            _uploadFileSizes.remove(newIndex);
            _uploadStartTimes.remove(newIndex);
          });
        } else if (mounted) {
          setState(() {
            _mediaItems.removeAt(newIndex);
            _uploadingMedia.remove(newIndex);
            _uploadProgress.remove(newIndex);
            _uploadFileNames.remove(newIndex);
            _uploadFileSizes.remove(newIndex);
            _uploadStartTimes.remove(newIndex);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload media')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading media: $e');
      if (mounted && !(_cancelledUploads[newIndex] ?? false)) {
        final localThumb = _localThumbnails[newIndex];

        setState(() {
          if (_mediaItems.length > newIndex) {
            _mediaItems.removeAt(newIndex);
          }
          _uploadingMedia.remove(newIndex);
          _uploadProgress.remove(newIndex);
          _localThumbnails.remove(newIndex);
          _cancelledUploads.remove(newIndex);
          _uploadFileNames.remove(newIndex);
          _uploadFileSizes.remove(newIndex);
          _uploadStartTimes.remove(newIndex);
        });

        // Clean up local thumbnail file
        if (localThumb != null) {
          try {
            final thumbFile = File(localThumb);
            if (await thumbFile.exists()) {
              await thumbFile.delete();
            }
          } catch (e) {
            debugPrint('Error deleting local thumbnail on error: $e');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading: $e')),
        );
      }
    }
  }

  void _cancelUpload(int index) async {
    if (!mounted) return;

    // Mark upload as cancelled
    setState(() {
      _cancelledUploads[index] = true;
      _uploadingMedia.remove(index);
      _uploadProgress.remove(index);
      _uploadFileNames.remove(index);
      _uploadFileSizes.remove(index);
      _uploadStartTimes.remove(index);
    });

    // Remove the media item
    _removeMedia(index);
  }

  void _removeMedia(int index) async {
    if (!mounted) return;

    // Cancel upload if in progress
    if (_uploadingMedia[index] == true) {
      _cancelledUploads[index] = true;
    }

    // Dispose the controller for this index
    _captionControllers[index]?.dispose();
    _captionControllers.remove(index);

    // Clean up local thumbnail if exists
    final localThumb = _localThumbnails[index];
    if (localThumb != null) {
      try {
        final thumbFile = File(localThumb);
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      } catch (e) {
        debugPrint('Error deleting local thumbnail on remove: $e');
      }
    }

    // Reindex all controllers after the removed index
    final newControllers = <int, TextEditingController>{};
    final newThumbnails = <int, String?>{};
    final newUploading = <int, bool>{};
    final newProgress = <int, double>{};
    final newCancelled = <int, bool>{};
    final newFileNames = <int, String>{};
    final newFileSizes = <int, int>{};
    final newStartTimes = <int, DateTime>{};

    for (int i = 0; i < _mediaItems.length; i++) {
      if (i < index) {
        // Keep items before the removed index
        if (_captionControllers.containsKey(i)) {
          newControllers[i] = _captionControllers[i]!;
        }
        if (_localThumbnails.containsKey(i)) {
          newThumbnails[i] = _localThumbnails[i];
        }
        if (_uploadingMedia.containsKey(i)) {
          newUploading[i] = _uploadingMedia[i]!;
        }
        if (_uploadProgress.containsKey(i)) {
          newProgress[i] = _uploadProgress[i]!;
        }
        if (_cancelledUploads.containsKey(i)) {
          newCancelled[i] = _cancelledUploads[i]!;
        }
        if (_uploadFileNames.containsKey(i)) {
          newFileNames[i] = _uploadFileNames[i]!;
        }
        if (_uploadFileSizes.containsKey(i)) {
          newFileSizes[i] = _uploadFileSizes[i]!;
        }
        if (_uploadStartTimes.containsKey(i)) {
          newStartTimes[i] = _uploadStartTimes[i]!;
        }
      } else if (i > index) {
        // Shift items after the removed index
        if (_captionControllers.containsKey(i)) {
          newControllers[i - 1] = _captionControllers[i]!;
        }
        if (_localThumbnails.containsKey(i)) {
          newThumbnails[i - 1] = _localThumbnails[i];
        }
        if (_uploadingMedia.containsKey(i)) {
          newUploading[i - 1] = _uploadingMedia[i]!;
        }
        if (_uploadProgress.containsKey(i)) {
          newProgress[i - 1] = _uploadProgress[i]!;
        }
        if (_cancelledUploads.containsKey(i)) {
          newCancelled[i - 1] = _cancelledUploads[i]!;
        }
        if (_uploadFileNames.containsKey(i)) {
          newFileNames[i - 1] = _uploadFileNames[i]!;
        }
        if (_uploadFileSizes.containsKey(i)) {
          newFileSizes[i - 1] = _uploadFileSizes[i]!;
        }
        if (_uploadStartTimes.containsKey(i)) {
          newStartTimes[i - 1] = _uploadStartTimes[i]!;
        }
      }
    }

    setState(() {
      _mediaItems.removeAt(index);
      _captionControllers.clear();
      _captionControllers.addAll(newControllers);
      _localThumbnails.clear();
      _localThumbnails.addAll(newThumbnails);
      _uploadingMedia.clear();
      _uploadingMedia.addAll(newUploading);
      _uploadProgress.clear();
      _uploadProgress.addAll(newProgress);
      _cancelledUploads.clear();
      _cancelledUploads.addAll(newCancelled);
      _uploadFileNames.clear();
      _uploadFileNames.addAll(newFileNames);
      _uploadFileSizes.clear();
      _uploadFileSizes.addAll(newFileSizes);
      _uploadStartTimes.clear();
      _uploadStartTimes.addAll(newStartTimes);
    });
  }

  Future<void> _enableLocation() async {
    if (!mounted) return;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Location permissions are permanently denied')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          final address =
              '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}'
                  .replaceAll(RegExp(r'^,\s*|,\s*$'), '');
          setState(() {
            _locationAddress = address;
          });
        }
      } catch (e) {
        debugPrint('CreatePostWidget: Error getting address: $e');
      }

      if (mounted) {
        setState(() {
          _location = GeoPoint(position.latitude, position.longitude);
          _isLocationEnabled = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  void _removeLocation() {
    if (mounted) {
      setState(() {
        _isLocationEnabled = false;
        _location = null;
        _locationAddress = null;
      });
    }
  }

  void _showPageSelection() {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusXL),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              child: Text(
                'Post as',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            // Current user option
            ListTile(
              leading: CircleAvatar(
                backgroundImage: (user.photoURL != null &&
                        ImageUrlValidator.isValidUrl(user.photoURL))
                    ? CachedNetworkImageProvider(user.photoURL!)
                    : null,
                child: (user.photoURL == null ||
                        !ImageUrlValidator.isValidUrl(user.photoURL))
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(user.displayName ?? 'You'),
              subtitle: const Text('Your personal account'),
              onTap: () {
                if (mounted) {
                  setState(() {
                    _selectedPageId = null;
                  });
                  Navigator.pop(context);
                }
              },
            ),
            // User pages
            ..._userPages.map((page) => ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (page.profileImageUrl.isNotEmpty &&
                            ImageUrlValidator.isValidUrl(page.profileImageUrl))
                        ? CachedNetworkImageProvider(page.profileImageUrl)
                        : null,
                    child: (page.profileImageUrl.isEmpty ||
                            !ImageUrlValidator.isValidUrl(page.profileImageUrl))
                        ? const Icon(Icons.business)
                        : null,
                  ),
                  title: Text(page.pageName),
                  subtitle: Text(page.category),
                  onTap: () {
                    if (mounted) {
                      setState(() {
                        _selectedPageId = page.pageId;
                      });
                      Navigator.pop(context);
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _createPost() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to post')),
        );
      }
      return;
    }

    if (_contentController.text.trim().isEmpty && _mediaItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add content or media')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isPosting = true;
      });
    }

    try {
      // Build MediaItem list with captions
      final mediaItemsWithCaptions = <MediaItem>[];
      for (int i = 0; i < _mediaItems.length; i++) {
        final caption = _captionControllers[i]?.text.trim();
        final mediaItem = _mediaItems[i].copyWith(caption: caption);
        mediaItemsWithCaptions.add(mediaItem);

        // Debug log each MediaItem before sending to Firestore
        debugPrint(
            'CreatePostWidget: MediaItem[$i] before createPost: ${mediaItem.toMap()}');
      }

      debugPrint(
          'CreatePostWidget: Sending ${mediaItemsWithCaptions.length} mediaItems to createPost');

      await _postRepository.createPost(
        userId: user.uid,
        content: _contentController.text.trim(),
        mediaItems:
            mediaItemsWithCaptions.isNotEmpty ? mediaItemsWithCaptions : null,
        location: _isLocationEnabled ? _location : null,
        locationAddress: _isLocationEnabled ? _locationAddress : null,
        visibility: _visibility,
        pageId: _selectedPageId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );

        // Phase 4: Refresh feeds to show new post immediately
        if (context.mounted) {
          try {
            // Refresh UnifiedFeedBloc (for For You feed)
            context.read<UnifiedFeedBloc>().add(
                  LoadUnifiedFeedEvent(
                    userId: user.uid,
                    refresh: true,
                  ),
                );
          } catch (e) {
            debugPrint(
                'CreatePostWidget: Could not refresh UnifiedFeedBloc: $e');
          }
        }

        _collapse();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final username = user?.displayName ?? 'User';

    // Get selected page or user
    PageModel? selectedPage;
    if (_selectedPageId != null && _userPages.isNotEmpty) {
      try {
        selectedPage = _userPages.firstWhere(
          (p) => p.pageId == _selectedPageId,
        );
      } catch (e) {
        selectedPage = null;
      }
    }
    final displayName = selectedPage?.pageName ?? username;
    final displayPhotoUrl = selectedPage?.profileImageUrl ?? user?.photoURL;

    return AnimatedContainer(
      duration: AnimationTokens.normal,
      curve: AnimationTokens.easeInOut,
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMD,
        vertical: DesignTokens.spaceSM,
      ),
      child: Card(
        elevation: 0,
        color: theme.cardTheme.color,
        shape: theme.cardTheme.shape,
        margin: EdgeInsets.zero,
        child: _isExpanded
            ? _buildExpandedState(
                context, theme, user, displayName, displayPhotoUrl)
            : _buildCollapsedState(
                context, theme, user, displayName, displayPhotoUrl),
      ),
    );
  }

  Widget _buildCollapsedState(
    BuildContext context,
    ThemeData theme,
    User? user,
    String displayName,
    String? displayPhotoUrl,
  ) {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      child: Row(
        children: [
          // User Avatar (tappable)
          GestureDetector(
            onTap: _showPageSelection,
            child: CircleAvatar(
              radius: DesignTokens.avatarSize / 2,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: (displayPhotoUrl != null &&
                      ImageUrlValidator.isValidUrl(displayPhotoUrl))
                  ? CachedNetworkImageProvider(displayPhotoUrl)
                  : null,
              child: (displayPhotoUrl == null ||
                      !ImageUrlValidator.isValidUrl(displayPhotoUrl))
                  ? Icon(
                      Icons.person,
                      size: DesignTokens.iconMD,
                      color: theme.colorScheme.onSurface,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: DesignTokens.spaceMD),
          // Text Input Field (tappable)
          Expanded(
            child: GestureDetector(
              onTap: _handleInputFieldTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMD,
                  vertical: DesignTokens.spaceSM,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Quoi de neuf, $displayName ?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: DesignTokens.opacityMedium),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.spaceSM),
          // Media Button (tappable)
          IconButton(
            icon: Icon(
              Icons.photo_library,
              size: DesignTokens.iconLG,
              color: theme.colorScheme.primary,
            ),
            onPressed: _handleMediaButtonTap,
            tooltip: 'Add media',
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedState(
    BuildContext context,
    ThemeData theme,
    User? user,
    String displayName,
    String? displayPhotoUrl,
  ) {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with collapse button
          MediaHeader(
            avatarUrl: (displayPhotoUrl != null &&
                    ImageUrlValidator.isValidUrl(displayPhotoUrl))
                ? displayPhotoUrl
                : null,
            username: displayName,
            onAvatarTap: _showPageSelection,
            onUsernameTap: _showPageSelection,
            padding: EdgeInsets.zero,
            showMenu: false,
            closeButton: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _collapse,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          // Media Preview
          if (_mediaItems.isNotEmpty)
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _mediaItems.length,
                itemBuilder: (context, index) {
                  final mediaItem = _mediaItems[index];
                  final isUploading = _uploadingMedia[index] == true;
                  final uploadProgress = _uploadProgress[index] ?? 0.0;
                  final localThumbnail = _localThumbnails[index];

                  return Padding(
                    padding: const EdgeInsets.only(right: DesignTokens.spaceSM),
                    child: Stack(
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusMD),
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusMD),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Background: thumbnail, image, or placeholder
                                if (isUploading && localThumbnail != null)
                                  // Show local thumbnail during video upload
                                  Image.file(
                                    File(localThumbnail),
                                    fit: BoxFit.cover,
                                  )
                                else if (isUploading &&
                                    mediaItem.type == 'image')
                                  // Show image preview during upload if available
                                  (mediaItem.url.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: mediaItem.url,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              _buildShimmerLoader(theme),
                                        )
                                      : _buildShimmerLoader(theme))
                                else if (!isUploading &&
                                    mediaItem.url.isNotEmpty)
                                  // Show uploaded image
                                  (mediaItem.type == 'image'
                                      ? CachedNetworkImage(
                                          imageUrl: mediaItem.url,
                                          fit: BoxFit.cover,
                                        )
                                      : (mediaItem.thumbnailUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: mediaItem.thumbnailUrl!,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: theme.colorScheme
                                                  .surfaceContainerHighest,
                                            )))
                                else
                                  // Placeholder
                                  Container(
                                    color: theme
                                        .colorScheme.surfaceContainerHighest,
                                  ),

                                // Progress overlay during upload with detailed info
                                if (isUploading)
                                  _buildUploadProgressOverlay(
                                    theme,
                                    index,
                                    uploadProgress,
                                    mediaItem.type,
                                  ),

                                // Play icon for uploaded videos
                                if (!isUploading &&
                                    mediaItem.type == 'video' &&
                                    mediaItem.url.isNotEmpty)
                                  const Center(
                                    child: Icon(
                                      Icons.play_circle_filled,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Cancel/Remove button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            icon: Icon(
                              isUploading ? Icons.close : Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.5),
                              padding: const EdgeInsets.all(4),
                              minimumSize: const Size(32, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => isUploading
                                ? _cancelUpload(index)
                                : _removeMedia(index),
                            tooltip: isUploading ? 'Cancel upload' : 'Remove',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (_mediaItems.isNotEmpty)
            const SizedBox(height: DesignTokens.spaceMD),
          // Text Input - with keyboard awareness
          TextField(
            controller: _contentController,
            focusNode: _textFieldFocusNode,
            maxLines: null,
            minLines: 3,
            onChanged: (_) {
              // Trigger rebuild to update post button state
              if (mounted) {
                setState(() {});
              }
            },
            decoration: InputDecoration(
              hintText: 'Quoi de neuf, $displayName ?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          // Footer Toolbar - stays above keyboard
          Row(
            children: [
              // Add media button
              IconButton(
                icon: const Icon(Icons.add_photo_alternate),
                onPressed: _showMediaPicker,
                tooltip: 'Add media',
              ),
              // Location toggle
              IconButton(
                icon: Icon(
                  _isLocationEnabled ? Icons.location_on : Icons.location_off,
                  color: _isLocationEnabled ? theme.colorScheme.primary : null,
                ),
                onPressed:
                    _isLocationEnabled ? _removeLocation : _enableLocation,
                tooltip: 'Location',
              ),
              // Visibility selector
              _buildVisibilityChip(theme),
              const Spacer(),
              // Post button - Enable if there's text OR media, and no uploads in progress
              FilledButton(
                onPressed: (_isPosting ||
                        _uploadingMedia.isNotEmpty ||
                        (_contentController.text.trim().isEmpty &&
                            _mediaItems.isEmpty))
                    ? null
                    : _createPost,
                child: _isPosting
                    ? AppProgressIndicator(
                        size: 20,
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      )
                    : const Text('Post'),
              ),
            ],
          ),
          // Location chip if enabled
          if (_isLocationEnabled) ...[
            const SizedBox(height: DesignTokens.spaceSM),
            Chip(
              avatar: const Icon(Icons.location_on, size: 18),
              label: Text(_locationAddress ?? 'Current Location'),
              onDeleted: _removeLocation,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisibilityChip(ThemeData theme) {
    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(DesignTokens.radiusXL),
            ),
          ),
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(DesignTokens.spaceMD),
                  child: Text(
                    'Who can see this?',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.public,
                    color: _visibility == 'public'
                        ? theme.colorScheme.primary
                        : null,
                  ),
                  title: const Text('Public'),
                  trailing: _visibility == 'public'
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () {
                    if (mounted) {
                      setState(() {
                        _visibility = 'public';
                      });
                      Navigator.pop(context);
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.people,
                    color: _visibility == 'friends'
                        ? theme.colorScheme.primary
                        : null,
                  ),
                  title: const Text('Friends'),
                  trailing: _visibility == 'friends'
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () {
                    if (mounted) {
                      setState(() {
                        _visibility = 'friends';
                      });
                      Navigator.pop(context);
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.near_me,
                    color: _visibility == 'nearby'
                        ? theme.colorScheme.primary
                        : null,
                  ),
                  title: const Text('Nearby'),
                  trailing: _visibility == 'nearby'
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () {
                    if (mounted) {
                      setState(() {
                        _visibility = 'nearby';
                      });
                      Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(height: DesignTokens.spaceMD),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceSM,
          vertical: DesignTokens.spaceXS,
        ),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _visibility == 'public'
                  ? Icons.public
                  : _visibility == 'friends'
                      ? Icons.people
                      : Icons.near_me,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: DesignTokens.spaceXS),
            Text(
              _visibility.toUpperCase(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoader(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      period: const Duration(milliseconds: 1200),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        ),
      ),
    );
  }

  /// Build detailed upload progress overlay with file info, speed, and ETA
  Widget _buildUploadProgressOverlay(
    ThemeData theme,
    int index,
    double progress,
    String mediaType,
  ) {
    final fileName = _uploadFileNames[index] ?? 'Unknown file';
    final fileSize = _uploadFileSizes[index] ?? 0;
    final startTime = _uploadStartTimes[index];

    // Calculate upload speed and ETA
    String speedText = '';
    String etaText = '';
    String fileSizeText = _formatFileSize(fileSize);

    if (startTime != null && progress > 0) {
      final elapsed = DateTime.now().difference(startTime).inSeconds;
      if (elapsed > 0) {
        final uploadedBytes = (fileSize * progress).round();
        final speedBytesPerSecond = uploadedBytes / elapsed;
        speedText = '${_formatFileSize(speedBytesPerSecond.round())}/s';

        if (progress < 1.0 && speedBytesPerSecond > 0) {
          final remainingBytes = fileSize - uploadedBytes;
          final etaSeconds = (remainingBytes / speedBytesPerSecond).round();
          if (etaSeconds < 60) {
            etaText = '${etaSeconds}s remaining';
          } else {
            final etaMinutes = (etaSeconds / 60).round();
            etaText = '~$etaMinutes min remaining';
          }
        }
      }
    }

    // Truncate file name if too long
    final displayFileName =
        fileName.length > 20 ? '${fileName.substring(0, 17)}...' : fileName;

    return Container(
      color: Colors.black.withOpacity(0.75),
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Progress indicator
          AppProgressIndicator(
            color: Colors.white,
            size: 48,
            strokeWidth: 4,
            value: progress > 0 ? progress : null,
          ),
          const SizedBox(height: DesignTokens.spaceSM),

          // Progress percentage
          Text(
            progress > 0
                ? '${(progress * 100).toStringAsFixed(1)}%'
                : 'Starting...',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXS),

          // File name
          Text(
            displayFileName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: DesignTokens.spaceXS),

          // File size and type
          Text(
            '$fileSizeText • ${mediaType == 'video' ? 'Video' : 'Image'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white60,
              fontSize: 10,
            ),
          ),

          // Upload speed and ETA
          if (speedText.isNotEmpty || etaText.isNotEmpty) ...[
            const SizedBox(height: DesignTokens.spaceXS),
            if (speedText.isNotEmpty)
              Text(
                speedText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (etaText.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                etaText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Format file size in bytes to human-readable format
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
