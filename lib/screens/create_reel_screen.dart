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
import 'package:freegram/widgets/reels/reel_media_picker_dialog.dart';
import 'package:freegram/widgets/reels/reel_camera_preview_widget.dart';
import 'package:freegram/widgets/reels/reel_video_preview_widget.dart';
import 'package:freegram/widgets/reels/reel_upload_progress_overlay.dart';
import 'package:freegram/widgets/reels/reel_caption_input_widget.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/utils/reel_constants.dart';

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
    final result = await ReelMediaPickerDialog.show(context);

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
            maxDuration: const Duration(
              seconds: ReelConstants.maxVideoDurationSeconds,
            ),
          )
          .timeout(
            const Duration(seconds: ReelConstants.videoPickTimeoutSeconds),
            onTimeout: () => null,
          );

      if (pickedFile != null && !kIsWeb) {
        final file = File(pickedFile.path);

        // Check video duration
        final controller = VideoPlayerController.file(file);
        await controller.initialize();
        final duration = controller.value.duration;

        if (duration.inSeconds > ReelConstants.maxVideoDurationSeconds) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Video too long. Maximum ${ReelConstants.maxVideoDurationSeconds} seconds allowed.',
                ),
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

      // Auto-stop after max duration
      Future.delayed(
        const Duration(seconds: ReelConstants.maxVideoDurationSeconds),
        () {
          if (_isRecordingVideo && mounted) {
            _stopVideoRecording();
          }
        },
      );
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
          SnackBar(
            content: const Text('Reel uploaded successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
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
            backgroundColor: Theme.of(context).colorScheme.error,
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
          icon: const Icon(Icons.close, color: Colors.white),
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
      return ReelCameraPreviewWidget(
        cameraController: _cameraController!,
        isRecording: _isRecordingVideo,
        recordingDuration: _recordingDuration,
        onStartRecording: _startVideoRecording,
        onStopRecording: _stopVideoRecording,
      );
    }

    // Show video preview if video is selected
    if (_selectedVideo != null || _videoPreviewController != null) {
      return ReelVideoPreviewWidget(
        videoController: _videoPreviewController,
        isUploading: _isUploading,
        uploadProgress: _uploadProgress,
        uploadProgressOverlay: _isUploading
            ? ReelUploadProgressOverlay(uploadProgress: _uploadProgress)
            : null,
        captionInput: !_isUploading
            ? ReelCaptionInputWidget(
                captionController: _captionController,
              )
            : null,
      );
    }

    // Default: show loading
    return const Center(
      child: AppProgressIndicator(),
    );
  }
}
