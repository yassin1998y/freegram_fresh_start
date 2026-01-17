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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/reel_upload/reel_upload_bloc.dart';
import 'package:freegram/widgets/reels/reel_media_picker_dialog.dart';
import 'package:freegram/widgets/reels/reel_camera_preview_widget.dart';
import 'package:freegram/widgets/reels/reel_video_preview_widget.dart';
import 'package:freegram/widgets/reels/reel_upload_progress_overlay.dart';
import 'package:freegram/widgets/reels/enhanced_reel_caption_input_widget.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/utils/reel_constants.dart';
import 'package:freegram/services/reel_draft_service.dart';

class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({Key? key}) : super(key: key);

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();
  StreamSubscription<ReelUploadState>? _uploadStateSubscription;

  File? _selectedVideo;

  // Camera state
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isRecordingVideo = false;
  final int _selectedCameraIndex = 0;
  VideoPlayerController? _videoPreviewController;
  int _recordingDuration = 0; // in seconds
  Timer? _recordingTimer; // Track timer to prevent memory leak
  bool _isOperationInProgress = false; // Prevent race conditions

  // Draft saving
  final ReelDraftService _draftService = ReelDraftService();
  Timer? _autoSaveTimer;
  String? _currentDraftId;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: create_reel_screen.dart');

    // Listen to upload state changes
    _uploadStateSubscription = context.read<ReelUploadBloc>().stream.listen(
      (state) {
        if (state is ReelUploadSuccess) {
          // Upload completed successfully
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Reel uploaded successfully!'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                duration: const Duration(seconds: 2),
              ),
            );
            Navigator.of(context).pop(true);
          }
        } else if (state is ReelUploadFailed) {
          // Upload failed
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: ${state.error}'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      },
    );

    // Use post-frame callback to ensure widget tree is built before showing picker
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkForDrafts();
      }
    });
  }

  /// Check if there are existing drafts and offer to resume
  Future<void> _checkForDrafts() async {
    final hasDrafts = await _draftService.hasDrafts();
    if (!hasDrafts || !mounted) {
      _showMediaPicker();
      return;
    }

    // Show dialog to resume draft or start new
    final shouldResume = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resume Draft?'),
        content: const Text(
            'You have an unfinished reel. Would you like to continue editing it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Start New'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resume'),
          ),
        ],
      ),
    );

    if (shouldResume == true && mounted) {
      await _loadMostRecentDraft();
    } else if (mounted) {
      _showMediaPicker();
    }
  }

  /// Load the most recent draft
  Future<void> _loadMostRecentDraft() async {
    try {
      final drafts = await _draftService.getDrafts();
      if (drafts.isEmpty) {
        _showMediaPicker();
        return;
      }

      // Get most recent draft
      drafts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final draft = drafts.first;

      // Check if video file exists
      final videoExists = await draft.videoExists();
      if (!videoExists) {
        await _draftService.deleteDraft(draft.id);
        _showMediaPicker();
        return;
      }

      // Load draft
      _currentDraftId = draft.id;
      final file = File(draft.videoPath);
      _captionController.text = draft.caption ?? '';

      // Initialize video preview
      _videoPreviewController = VideoPlayerController.file(file);
      await _videoPreviewController!.initialize();
      await _videoPreviewController!.play();

      if (mounted) {
        setState(() {
          _selectedVideo = file;
        });
      }

      // Start auto-save
      _startAutoSave();
    } catch (e) {
      debugPrint('Error loading draft: $e');
      _showMediaPicker();
    }
  }

  /// Start auto-save timer
  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveDraft();
    });
  }

  /// Save current state as draft
  Future<void> _saveDraft() async {
    if (_selectedVideo == null) return;

    try {
      final caption = _captionController.text.trim();
      final hashtagRegex = RegExp(r'#(\w+)');
      final hashtags = hashtagRegex
          .allMatches(caption)
          .map((match) => match.group(1)!)
          .toList();
      final mentionRegex = RegExp(r'@(\w+)');
      final mentions = mentionRegex
          .allMatches(caption)
          .map((match) => match.group(1)!)
          .toList();

      if (_currentDraftId != null) {
        // Update existing draft
        await _draftService.updateDraft(
          id: _currentDraftId!,
          caption: caption.isEmpty ? null : caption,
          hashtags: hashtags.isEmpty ? null : hashtags,
          mentions: mentions.isEmpty ? null : mentions,
        );
      } else {
        // Create new draft
        _currentDraftId = await _draftService.saveDraft(
          videoPath: _selectedVideo!.path,
          caption: caption.isEmpty ? null : caption,
          hashtags: hashtags.isEmpty ? null : hashtags,
          mentions: mentions.isEmpty ? null : mentions,
        );
      }

      debugPrint('Draft auto-saved: $_currentDraftId');
    } catch (e) {
      debugPrint('Error auto-saving draft: $e');
    }
  }

  @override
  void dispose() {
    // CRITICAL: Cancel upload state subscription first
    _uploadStateSubscription?.cancel();
    // CRITICAL: Cancel recording timer to prevent memory leak
    _recordingTimer?.cancel();
    _recordingTimer = null;
    // CRITICAL: Cancel auto-save timer
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    // CRITICAL: Dispose all media controllers to release resources
    _cameraController?.dispose();
    _cameraController = null;
    _videoPreviewController?.dispose();
    _videoPreviewController = null;
    // CRITICAL: Clear video file reference (File will be garbage collected)
    _selectedVideo = null;
    // Dispose text controller
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
      if (mounted) Navigator.of(context).pop();
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
    if (_isOperationInProgress) return; // Prevent race conditions
    _isOperationInProgress = true;

    VideoPlayerController? tempController;
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

        // Check video duration - ensure disposal on error
        tempController = VideoPlayerController.file(file);
        await tempController.initialize();
        final duration = tempController.value.duration;

        if (duration.inSeconds > ReelConstants.maxVideoDurationSeconds) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Video too long. Maximum ${ReelConstants.maxVideoDurationSeconds} seconds allowed.',
                ),
              ),
            );
          }
          await tempController.dispose();
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
        await tempController.dispose();

        // Start auto-save after video is selected
        _startAutoSave();
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
      // Ensure controller is disposed even on error
      await tempController?.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      _isOperationInProgress = false;
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

      // Timer to update recording duration - track to prevent memory leak
      _recordingTimer?.cancel(); // Cancel any existing timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isRecordingVideo || !mounted) {
          timer.cancel();
          _recordingTimer = null;
          return;
        }
        if (mounted) {
          setState(() {
            _recordingDuration++;
          });
        }
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

      // Start auto-save after recording
      _startAutoSave();
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

    // Trigger upload via BLoC
    context.read<ReelUploadBloc>().add(
          StartReelUpload(
            videoPath: _selectedVideo!.path,
            caption: caption.isEmpty ? null : caption,
            hashtags: hashtags.isEmpty ? null : hashtags,
            mentions: mentions.isEmpty ? null : mentions,
          ),
        );

    // Delete draft after successful upload trigger
    if (_currentDraftId != null) {
      await _draftService.deleteDraft(_currentDraftId!);
      _currentDraftId = null;
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
          BlocBuilder<ReelUploadBloc, ReelUploadState>(
            builder: (context, uploadState) {
              final isUploading = uploadState is ReelUploadInProgress;
              if (_selectedVideo != null && !isUploading) {
                return TextButton(
                  onPressed: _uploadReel,
                  child: Text(
                    'Share',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: SonarPulseTheme.primaryAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
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
      return BlocBuilder<ReelUploadBloc, ReelUploadState>(
        builder: (context, uploadState) {
          final isUploading = uploadState is ReelUploadInProgress;
          final uploadProgress =
              uploadState is ReelUploadInProgress ? uploadState.progress : 0.0;

          return ReelVideoPreviewWidget(
            videoController: _videoPreviewController,
            isUploading: isUploading,
            uploadProgress: uploadProgress,
            uploadProgressOverlay: isUploading
                ? ReelUploadProgressOverlay(uploadProgress: uploadProgress)
                : null,
            captionInput: !isUploading
                ? EnhancedReelCaptionInputWidget(
                    captionController: _captionController,
                  )
                : null,
          );
        },
      );
    }

    // Default: show loading
    return const Center(
      child: AppProgressIndicator(),
    );
  }
}
