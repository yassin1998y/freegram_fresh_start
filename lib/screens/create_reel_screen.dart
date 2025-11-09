// lib/screens/create_reel_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:freegram/services/video_upload_service.dart';
import 'package:freegram/services/reel_upload_service.dart';
import 'package:freegram/widgets/common/keyboard_safe_area.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({Key? key}) : super(key: key);

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final VideoUploadService _uploadService = VideoUploadService();
  final ReelUploadService _reelUploadService = ReelUploadService();
  final TextEditingController _captionController = TextEditingController();

  File? _selectedVideo;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Camera state
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isRecordingVideo = false;
  final int _selectedCameraIndex = 0;
  VideoPlayerController? _videoPreviewController;
  int _recordingDuration = 0; // in seconds

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: create_reel_screen.dart');
    // Use post-frame callback to ensure widget tree is built before showing picker
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showMediaPicker();
      }
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _videoPreviewController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _showMediaPicker() async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.videocam, color: theme.colorScheme.primary),
              title: Text('Record Video', style: theme.textTheme.bodyMedium),
              onTap: () => Navigator.of(context).pop({
                'source': ImageSource.camera,
                'type': 'video',
              }),
            ),
            if (!kIsWeb)
              ListTile(
                leading:
                    Icon(Icons.video_library, color: theme.colorScheme.primary),
                title: Text('Choose from Gallery',
                    style: theme.textTheme.bodyMedium),
                onTap: () => Navigator.of(context).pop({
                  'source': ImageSource.gallery,
                  'type': 'video',
                }),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (result != null) {
      final source = result['source'] as ImageSource;

      if (source == ImageSource.camera) {
        await _initializeCamera();
      } else {
        await _pickVideo(source);
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras available')),
          );
        }
        return;
      }

      final permissionStatus = await Permission.camera.status;
      if (!permissionStatus.isGranted) {
        final permission = await Permission.camera.request();
        if (!permission.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Camera permission required')),
            );
            Navigator.of(context).pop();
          }
          return;
        }
      }

      _cameraController = CameraController(
        _cameras![_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker
          .pickVideo(
            source: source,
            maxDuration:
                const Duration(seconds: 60), // Max 60 seconds for reels
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => null,
          );

      if (pickedFile != null && !kIsWeb) {
        final file = File(pickedFile.path);

        // Check video duration
        final controller = VideoPlayerController.file(file);
        await controller.initialize();
        final duration = controller.value.duration;

        if (duration.inSeconds > 60) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video too long. Maximum 60 seconds allowed.'),
              ),
            );
          }
          await controller.dispose();
          return;
        }

        // Show video preview
        _videoPreviewController = VideoPlayerController.file(file);
        await _videoPreviewController!.initialize();
        await _videoPreviewController!.play();

        if (mounted) {
          setState(() {
            _selectedVideo = file;
          });
        }
        await controller.dispose();
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _startVideoRecording() async {
    if (!_isCameraInitialized || _cameraController == null) return;

    try {
      await _cameraController!.startVideoRecording();
      if (mounted) {
        setState(() {
          _isRecordingVideo = true;
          _recordingDuration = 0;
        });
      }

      // Timer to update recording duration
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isRecordingVideo || !mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordingDuration++;
        });
      });

      // Auto-stop after 60 seconds (max duration)
      Future.delayed(const Duration(seconds: 60), () {
        if (_isRecordingVideo && mounted) {
          _stopVideoRecording();
        }
      });
    } catch (e) {
      debugPrint('Error starting video recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
      }
    }
  }

  Future<void> _stopVideoRecording() async {
    if (!_isRecordingVideo || _cameraController == null) return;

    try {
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      final file = File(videoFile.path);

      // Dispose camera
      await _cameraController!.dispose();
      _cameraController = null;

      // Show video preview
      _videoPreviewController = VideoPlayerController.file(file);
      await _videoPreviewController!.initialize();
      await _videoPreviewController!.play();

      if (mounted) {
        setState(() {
          _selectedVideo = file;
          _isCameraInitialized = false;
          _isRecordingVideo = false;
        });
      }
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e')),
        );
      }
    }
  }

  Future<void> _uploadReel() async {
    if (_selectedVideo == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to upload a reel')),
      );
      return;
    }

    final caption = _captionController.text.trim();

    // Start tracking upload globally
    _reelUploadService.startUpload(caption: caption.isEmpty ? null : caption);

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Extract hashtags from caption
      final hashtagRegex = RegExp(r'#(\w+)');
      final hashtags = hashtagRegex
          .allMatches(caption)
          .map((match) => match.group(1)!)
          .toList();

      // Extract mentions from caption
      final mentionRegex = RegExp(r'@(\w+)');
      final mentions = mentionRegex
          .allMatches(caption)
          .map((match) => match.group(1)!)
          .toList();

      await _uploadService.uploadReel(
        videoFile: _selectedVideo!,
        caption: caption.isEmpty ? null : caption,
        hashtags: hashtags.isEmpty ? null : hashtags,
        mentions: mentions.isEmpty ? null : mentions,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
            // Update global upload service
            _reelUploadService.updateProgress(progress);
          }
        },
      );

      // Complete upload tracking
      _reelUploadService.completeUpload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reel uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      debugPrint('Error uploading reel: $e');
      // Cancel upload tracking on error
      _reelUploadService.cancelUpload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading reel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Create Reel',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
          ),
        ),
        actions: [
          if (_selectedVideo != null && !_isUploading)
            TextButton(
              onPressed: _uploadReel,
              child: Text(
                'Share',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: SonarPulseTheme.primaryAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // Show camera preview if camera is initialized and no video selected
    if (_isCameraInitialized &&
        _selectedVideo == null &&
        _cameraController != null) {
      return Stack(
        children: [
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),
          // Recording indicator
          if (_isRecordingVideo)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_recordingDuration}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Bottom controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onLongPressStart: (_) => _startVideoRecording(),
                  onLongPressEnd: (_) => _stopVideoRecording(),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isRecordingVideo ? Colors.red : Colors.white,
                        width: 4,
                      ),
                      color: _isRecordingVideo
                          ? Colors.red.withOpacity(0.3)
                          : Colors.transparent,
                    ),
                    child: Icon(
                      Icons.videocam,
                      color: _isRecordingVideo ? Colors.red : Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Show video preview if video is selected
    if (_selectedVideo != null || _videoPreviewController != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Video preview
          Positioned.fill(
            child: _videoPreviewController != null &&
                    _videoPreviewController!.value.isInitialized
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoPreviewController!.value.size.width,
                        height: _videoPreviewController!.value.size.height,
                        child: VideoPlayer(_videoPreviewController!),
                      ),
                    ),
                  )
                : const Center(
                    child: AppProgressIndicator(color: Colors.white),
                  ),
          ),
          // Upload progress overlay (minimal - user can navigate away)
          if (_isUploading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMD,
                  vertical: DesignTokens.spaceSM,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                ),
                child: Row(
                  children: [
                    AppProgressIndicator(
                      size: 16,
                      value: _uploadProgress,
                      strokeWidth: 2,
                      color: SonarPulseTheme.primaryAccent,
                      backgroundColor: Colors.white24,
                    ),
                    const SizedBox(width: DesignTokens.spaceSM),
                    Expanded(
                      child: Text(
                        'Uploading ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Bottom section: Caption input
          if (!_isUploading)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: KeyboardAwareInput(
                  child: SafeArea(
                    child: TextField(
                      controller: _captionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Write a caption...',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.5)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusMD),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.all(DesignTokens.spaceMD),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // Default: show loading
    return const Center(
      child: AppProgressIndicator(color: Colors.white),
    );
  }
}
