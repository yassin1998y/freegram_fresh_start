// lib/screens/story_creator_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/text_overlay_model.dart';
import 'package:freegram/models/drawing_path_model.dart';
import 'package:freegram/models/sticker_overlay_model.dart';
import 'package:freegram/widgets/story_widgets/editor/story_editor_toolbar.dart';
import 'package:freegram/widgets/story_widgets/editor/story_sticker_picker.dart';
import 'package:freegram/widgets/story_widgets/creator/story_camera_widget.dart';
import 'package:freegram/widgets/story_widgets/creator/story_media_preview_widget.dart';
import 'package:freegram/widgets/story_widgets/creator/story_media_picker_dialog.dart';
import 'package:freegram/widgets/story_widgets/creator/story_text_editor_dialog.dart';
import 'package:freegram/widgets/story_widgets/creator/story_share_button.dart';
import 'package:freegram/widgets/story_widgets/creator/story_editing_overlays_widget.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/utils/story_constants.dart';
// Audio features temporarily disabled - FFmpegKit packages have compatibility issues
// import 'package:freegram/widgets/story_widgets/audio_import_modal.dart';
// import 'package:freegram/widgets/story_widgets/audio_trimmer_widget.dart';
import 'package:freegram/widgets/story_widgets/video_trimmer_screen.dart';
// import 'package:freegram/models/audio_segment_model.dart';
// import 'package:freegram/services/audio_merger_service.dart';
// import 'package:freegram/services/audio_trimmer_service.dart';
import 'package:freegram/services/story_upload_service.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/services/gallery_service.dart';
import 'package:freegram/services/draft_persistence_service.dart';
import 'package:freegram/widgets/island_popup.dart';
import 'package:freegram/utils/haptic_helper.dart';

class StoryCreatorScreen extends StatefulWidget {
  final File? preSelectedMedia;
  final String? mediaType; // 'image' or 'video'
  final bool? openCamera;

  const StoryCreatorScreen({
    Key? key,
    this.preSelectedMedia,
    this.mediaType,
    this.openCamera,
  }) : super(key: key);

  @override
  State<StoryCreatorScreen> createState() => _StoryCreatorScreenState();
}

class _StoryCreatorScreenState extends State<StoryCreatorScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final _draftService = locator<DraftPersistenceService>();
  Timer? _autoSaveTimer;

  File? _selectedMedia;
  Uint8List? _selectedMediaBytes; // For web platform
  String _mediaType = 'image'; // 'image' or 'video'
  bool _isUploading = false;

  // Camera state
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isRecordingVideo = false;
  int _selectedCameraIndex = 0;
  VideoPlayerController? _videoPreviewController;

  // Editing state
  String _activeTool = 'none'; // 'none', 'text', 'draw', 'stickers', 'music'
  List<TextOverlay> _textOverlays = [];
  List<DrawingPath> _drawings = [];
  List<StickerOverlay> _stickerOverlays = [];

  // Drawing tool state
  Color _drawingColor = Colors.white; // Will be replaced with theme color
  double _drawingStrokeWidth = DesignTokens.spaceXS; // ~5.0

  // Audio import state (temporarily disabled - FFmpegKit compatibility issues)
  // String? _selectedAudioPath;
  // double? _audioStartTime;
  // double? _audioDuration;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: story_creator_screen.dart');

    // Handle pre-selected media or camera option
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (widget.preSelectedMedia != null) {
          // Pre-selected media file
          _handlePreSelectedMedia(widget.preSelectedMedia!);
        } else if (widget.openCamera == true) {
          // Open camera directly
          _initializeCamera();
        } else if (_selectedMedia == null && _selectedMediaBytes == null) {
          // Fallback: show media picker (for backward compatibility)
          _showMediaPicker();
        }
      }
    });
  }

  Future<void> _handlePreSelectedMedia(File file) async {
    try {
      // CRITICAL FIX: Verify file exists before processing
      if (!await file.exists()) {
        debugPrint('StoryCreatorScreen: File does not exist: ${file.path}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected file not found')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      if (widget.mediaType == 'video') {
        // Initialize video preview with error handling
        try {
          debugPrint(
              'StoryCreatorScreen: Initializing video preview for: ${file.path}');
          _videoPreviewController = VideoPlayerController.file(file);
          await _videoPreviewController!.initialize();

          // Verify video is valid
          if (!_videoPreviewController!.value.isInitialized) {
            throw Exception('Video failed to initialize');
          }

          await _videoPreviewController!.play();

          if (mounted) {
            setState(() {
              _selectedMedia = file;
              _mediaType = 'video';
            });
            debugPrint(
                'StoryCreatorScreen: Video preview initialized successfully');
          }
          if (mounted) {
            _checkAndRestoreDraft(file.path);
          }
        } catch (e) {
          debugPrint(
              'StoryCreatorScreen: Error initializing video preview: $e');
          _videoPreviewController?.dispose();
          _videoPreviewController = null;

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading video: $e')),
            );
            Navigator.of(context).pop();
          }
        }
      } else {
        // Image - verify it's a valid image file
        try {
          debugPrint('StoryCreatorScreen: Loading image: ${file.path}');
          // Try to read the file to verify it's valid
          final bytes = await file.readAsBytes();
          if (bytes.isEmpty) {
            throw Exception('Image file is empty');
          }

          // Dispose video controller if switching from video to image
          _videoPreviewController?.dispose();
          _videoPreviewController = null;

          if (mounted) {
            setState(() {
              _selectedMedia = file;
              _mediaType = 'image';
            });
            debugPrint('StoryCreatorScreen: Image loaded successfully');
            _checkAndRestoreDraft(file.path);
          }
        } catch (e) {
          debugPrint('StoryCreatorScreen: Error loading image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading image: $e')),
            );
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      debugPrint('StoryCreatorScreen: Error handling pre-selected media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _videoPreviewController?.dispose();
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  void _onEditorChanged() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveDraft();
    });
  }

  Future<void> _saveDraft() async {
    final mediaPath =
        _selectedMedia?.path ?? 'bytes_${_selectedMediaBytes?.length}';
    if (mediaPath.isEmpty) return;

    await _draftService.saveStoryDraft(
      mediaPath: mediaPath,
      mediaType: _mediaType,
      textOverlays: _textOverlays,
      stickerOverlays: _stickerOverlays,
      drawings: _drawings,
    );

    HapticHelper.lightImpact();
    debugPrint('[StoryCreator] Auto-save complete');
  }

  Future<void> _checkAndRestoreDraft(String mediaPath) async {
    final draft = await _draftService.getStoryDraft(mediaPath);
    if (draft != null && mounted) {
      showIslandPopup(
        context: context,
        message: 'Draft restored. Tap to clear.',
        icon: Icons.restore,
        onTap: () async {
          await _draftService.deleteStoryDraft(mediaPath);
          if (mounted) {
            setState(() {
              _textOverlays = [];
              _stickerOverlays = [];
              _drawings = [];
            });
          }
        },
      );

      setState(() {
        if (draft['textOverlays'] != null) {
          _textOverlays = (draft['textOverlays'] as List)
              .map((t) => TextOverlay.fromMap(t as Map<String, dynamic>))
              .toList();
        }
        if (draft['stickerOverlays'] != null) {
          _stickerOverlays = (draft['stickerOverlays'] as List)
              .map((s) => StickerOverlay.fromMap(s as Map<String, dynamic>))
              .toList();
        }
        if (draft['drawings'] != null) {
          _drawings = (draft['drawings'] as List).map((d) {
            final data = d as Map<String, dynamic>;
            return DrawingPath.fromCompressed(
              List<double>.from(data['points'] as List),
              data['color'] as String,
              (data['strokeWidth'] as num).toDouble(),
            );
          }).toList();
        }
      });
      HapticHelper.mediumImpact();
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

      // Check camera permission
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
        ResolutionPreset.medium,
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

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    await _cameraController?.dispose();
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;

    _cameraController = CameraController(
      _cameras![_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: true,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _cameraController == null) return;

    try {
      final XFile picture = await _cameraController!.takePicture();
      final file = File(picture.path);

      // Dispose camera to save resources
      await _cameraController!.dispose();
      _cameraController = null;

      if (mounted) {
        setState(() {
          _selectedMedia = file;
          _mediaType = 'image';
          _isCameraInitialized = false;
        });
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: $e')),
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
        });
      }

      // Auto-stop after max duration (StoryConstants.maxVideoDurationSeconds)
      Future.delayed(
        const Duration(seconds: StoryConstants.maxVideoDurationSeconds),
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

      // Check video duration
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      final duration = controller.value.duration;

      if (duration.inSeconds > StoryConstants.maxVideoDurationSeconds) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Video too long. Maximum ${StoryConstants.maxVideoDurationSeconds} seconds allowed.',
              ),
            ),
          );
        }
        await controller.dispose();
        return;
      }

      // Dispose camera and preview video
      await _cameraController!.dispose();
      _cameraController = null;

      // Show video preview
      _videoPreviewController = VideoPlayerController.file(file);
      await _videoPreviewController!.initialize();
      await _videoPreviewController!.play();

      if (mounted) {
        setState(() {
          _selectedMedia = file;
          _mediaType = 'video';
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

  Future<void> _showMediaPicker() async {
    final result = await StoryMediaPickerDialog.show(context);

    if (!context.mounted) return;

    if (result != null) {
      final source = result['source'] as ImageSource;
      final type = result['type'] as String? ?? 'image';

      if (source == ImageSource.camera) {
        // Initialize camera instead of showing picker
        await _initializeCamera();
      } else {
        await _pickMedia(source, mediaType: type);
      }
    } else {
      // User cancelled, go back
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _pickMedia(ImageSource source,
      {String mediaType = 'image'}) async {
    try {
      debugPrint(
          'StoryCreatorScreen: _pickMedia called with source: $source, type: $mediaType');

      // CRITICAL FIX: Only request camera permission manually
      // ImagePicker handles gallery permissions internally, requesting them manually causes conflicts
      if (source == ImageSource.camera) {
        debugPrint('StoryCreatorScreen: Requesting camera permission...');
        final permissionStatus = await Permission.camera.status;
        if (!permissionStatus.isGranted) {
          final permission = await Permission.camera.request();
          if (!permission.isGranted) {
            debugPrint('StoryCreatorScreen: Camera permission denied');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Camera permission required')),
              );
              Navigator.of(context).pop();
            }
            return;
          }
        }
        debugPrint('StoryCreatorScreen: Camera permission granted');
      }

      XFile? pickedFile;

      if (mediaType == 'video') {
        // Pick video (max 20 seconds)
        pickedFile = await _imagePicker
            .pickVideo(
              source: source,
              maxDuration: const Duration(seconds: 20),
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => null,
            );
      } else {
        // Pick image
        pickedFile = await _imagePicker
            .pickImage(
              source: source,
              imageQuality: 85,
              maxWidth: StoryConstants.storyWidth,
              maxHeight: StoryConstants.storyHeight,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => null,
            );
      }

      if (pickedFile != null) {
        final fileSize = await pickedFile.length();
        if (fileSize > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File too large. Max 10MB.')),
            );
          }
          return;
        }

        // CRITICAL FIX: Verify file exists and is accessible
        final file = File(pickedFile.path);
        if (!await file.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Selected file not found')),
            );
          }
          return;
        }

        if (mounted) {
          if (kIsWeb && mediaType == 'image') {
            // For web, read file as bytes (images only)
            try {
              final bytes = await pickedFile.readAsBytes();
              if (bytes.isEmpty) {
                throw Exception('Image file is empty');
              }
              // Dispose video controller if switching from video to image
              _videoPreviewController?.dispose();
              _videoPreviewController = null;

              setState(() {
                _selectedMediaBytes = bytes;
                _mediaType = 'image';
              });
              debugPrint(
                  'StoryCreatorScreen: Image selected successfully (web)');
            } catch (e) {
              debugPrint('StoryCreatorScreen: Error reading image bytes: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error loading image: $e')),
                );
              }
            }
          } else if (!kIsWeb) {
            if (mediaType == 'video') {
              // Initialize video preview with error handling
              try {
                debugPrint(
                    'StoryCreatorScreen: Initializing video preview for: ${file.path}');
                _videoPreviewController = VideoPlayerController.file(file);
                await _videoPreviewController!.initialize();

                // Verify video is valid
                if (!_videoPreviewController!.value.isInitialized) {
                  throw Exception('Video failed to initialize');
                }

                await _videoPreviewController!.play();

                setState(() {
                  _selectedMedia = file;
                  _mediaType = 'video';
                });
                debugPrint('StoryCreatorScreen: Video selected successfully');
              } catch (e) {
                debugPrint('StoryCreatorScreen: Error initializing video: $e');
                _videoPreviewController?.dispose();
                _videoPreviewController = null;

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error loading video: $e')),
                  );
                }
              }
            } else {
              // Image - verify it's a valid image file
              try {
                debugPrint('StoryCreatorScreen: Loading image: ${file.path}');
                // Try to read the file to verify it's valid
                final bytes = await file.readAsBytes();
                if (bytes.isEmpty) {
                  throw Exception('Image file is empty');
                }

                // Dispose video controller if switching from video to image
                _videoPreviewController?.dispose();
                _videoPreviewController = null;

                setState(() {
                  _selectedMedia = file;
                  _mediaType = 'image';
                });
                debugPrint('StoryCreatorScreen: Image selected successfully');
              } catch (e) {
                debugPrint('StoryCreatorScreen: Error loading image: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error loading image: $e')),
                  );
                }
              }
            }
          }
        }
      } else {
        // User cancelled
        debugPrint('StoryCreatorScreen: User cancelled media selection');
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('Error picking media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _shareStory() async {
    if (_selectedMedia == null && _selectedMediaBytes == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to share a story')),
      );
      return;
    }

    // Check if video needs trimming (> 20 seconds)
    File? mediaFileToUpload = _selectedMedia;
    if (!kIsWeb && _selectedMedia != null && _mediaType == 'video') {
      try {
        final controller = VideoPlayerController.file(_selectedMedia!);
        await controller.initialize();
        final videoDuration = controller.value.duration.inSeconds.toDouble();
        await controller.dispose();

        if (videoDuration > StoryConstants.maxVideoDurationSeconds) {
          // Show video trimmer
          final trimmedVideo = await Navigator.of(context).push<File>(
            MaterialPageRoute(
              builder: (context) => VideoTrimmerScreen(
                videoFile: _selectedMedia!,
              ),
            ),
          );

          if (trimmedVideo != null) {
            mediaFileToUpload = trimmedVideo;
            // Update preview
            _videoPreviewController?.dispose();
            _videoPreviewController = VideoPlayerController.file(trimmedVideo);
            await _videoPreviewController!.initialize();
            await _videoPreviewController!.play();
            if (mounted) {
              setState(() {
                _selectedMedia = trimmedVideo;
              });
            }
          } else {
            // User cancelled trimming
            return;
          }
        }
      } catch (e) {
        debugPrint('StoryCreatorScreen: Error checking video duration: $e');
      }
    }

    // Use StoryUploadService for coordinated upload
    final storyUploadService = locator<StoryUploadService>();

    setState(() {
      _isUploading = true;
    });

    try {
      await storyUploadService.uploadStory(
        userId: currentUser.uid,
        mediaType: _mediaType,
        mediaFile: mediaFileToUpload,
        mediaBytes: _selectedMediaBytes,
        videoDuration: null, // Service handles it
        textOverlays: _textOverlays.isNotEmpty ? _textOverlays : null,
        drawings: _drawings.isNotEmpty ? _drawings : null,
        stickerOverlays: _stickerOverlays.isNotEmpty ? _stickerOverlays : null,
        onProgress: (progress, step) {
          // Progress is handled by underlying services
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $error')),
            );
          }
        },
        onSuccess: () async {
          // Clear draft on success
          final mediaPath =
              _selectedMedia?.path ?? 'bytes_${_selectedMediaBytes?.length}';
          await _draftService.deleteStoryDraft(mediaPath);

          if (mounted) {
            HapticHelper.success();
            final bool? postAnother = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Story Shared!'),
                content: const Text('Your story has been shared successfully.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSurface.withValues(
                                  alpha: DesignTokens.opacityHigh,
                                ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'Post Another',
                      style: TextStyle(
                        color: SonarPulseTheme.primaryAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );

            if (mounted) {
              if (postAnother == true) {
                setState(() {
                  _selectedMedia = null;
                  _selectedMediaBytes = null;
                  _videoPreviewController?.dispose();
                  _videoPreviewController = null;
                  _textOverlays = [];
                  _drawings = [];
                  _stickerOverlays = [];
                  _activeTool = 'none';
                  _drawingColor = Colors.white;
                  _drawingStrokeWidth = DesignTokens.spaceXS;
                });
                _showMediaPicker();
              } else {
                Navigator.of(context).pop();
              }
            }
          }
        },
      );
    } catch (e) {
      debugPrint('Error sharing story: $e');
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
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // Show camera preview if camera is initialized and no media selected
    if (_isCameraInitialized &&
        _selectedMedia == null &&
        _cameraController != null &&
        _cameras != null) {
      return StoryCameraWidget(
        controller: _cameraController!,
        cameras: _cameras!,
        isRecordingVideo: _isRecordingVideo,
        onClose: () => Navigator.of(context).pop(),
        onSwitchCamera: _cameras!.length > 1 ? _switchCamera : null,
        onTakePicture: _takePicture,
        onStartVideoRecording: _startVideoRecording,
        onStopVideoRecording: _stopVideoRecording,
      );
    }

    // Show media preview if media is selected
    if (_selectedMedia != null || _selectedMediaBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Media preview - fill screen
          Positioned.fill(
            child: StoryMediaPreviewWidget(
              mediaType: _mediaType,
              mediaFile: _selectedMedia,
              mediaBytes: _selectedMediaBytes,
              videoController: _videoPreviewController,
            ),
          ),

          // Editing overlays (text, drawings, stickers)
          StoryEditingOverlaysWidget(
            activeTool: _activeTool,
            textOverlays: _textOverlays,
            drawings: _drawings,
            stickerOverlays: _stickerOverlays,
            drawingColor: _drawingColor,
            drawingStrokeWidth: _drawingStrokeWidth,
            onDrawingsChanged: (drawings) {
              setState(() {
                _drawings = drawings;
              });
              _onEditorChanged();
            },
            onTextOverlayChanged: (index, overlay) {
              setState(() {
                _textOverlays[index] = overlay;
              });
              _onEditorChanged();
            },
            onEditTextOverlay: _editTextOverlay,
            onDeleteTextOverlay: (index) {
              setState(() {
                _textOverlays.removeAt(index);
              });
              _onEditorChanged();
            },
            onStickerOverlayChanged: (index, sticker) {
              setState(() {
                _stickerOverlays[index] = sticker;
              });
              _onEditorChanged();
            },
            onDeleteStickerOverlay: (index) {
              setState(() {
                _stickerOverlays.removeAt(index);
              });
              _onEditorChanged();
            },
            onDrawingColorChanged: (color) {
              setState(() {
                _drawingColor = color;
              });
            },
            onDrawingStrokeWidthChanged: (width) {
              setState(() {
                _drawingStrokeWidth = width;
              });
            },
          ),

          // Top-right toolbar (Text, Draw, Stickers)
          StoryEditorToolbar(
            activeTool: _activeTool,
            onToolChanged: (tool) {
              setState(() {
                _activeTool = tool;
              });
              if (tool == 'text') {
                _addTextOverlay();
              } else if (tool == 'stickers') {
                _showStickerPicker();
              } else if (tool == 'save') {
                _saveToGallery();
              }
            },
          ),

          // Bottom-right Share button
          StoryShareButton(
            isUploading: _isUploading,
            onShare: _shareStory,
          ),
        ],
      );
    }

    // Show loading
    return Center(
      child: AppProgressIndicator(
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  void _addTextOverlay() async {
    // Add a new text overlay at center
    const initialOverlay = TextOverlay(
      text: 'Tap to edit',
      x: 0.5,
      y: 0.5,
      fontSize: DesignTokens.fontSizeXXXL,
      color: '#FFFFFF',
      style: 'bold',
    );

    final editedOverlay = await StoryTextEditorDialog.show(
      context,
      initialOverlay: initialOverlay,
    );

    if (editedOverlay != null && mounted && context.mounted) {
      setState(() {
        _textOverlays.add(editedOverlay);
      });
      _onEditorChanged();
    }
  }

  void _editTextOverlay(int index) async {
    if (index < 0 || index >= _textOverlays.length) return;

    final overlay = _textOverlays[index];
    final editedOverlay = await StoryTextEditorDialog.show(
      context,
      initialOverlay: overlay,
    );

    if (editedOverlay != null && mounted) {
      setState(() {
        _textOverlays[index] = editedOverlay;
      });
      _onEditorChanged();
    }
  }

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StoryStickerPicker(
        onStickerSelected: (stickerId) {
          Navigator.of(context).pop();
          setState(() {
            _stickerOverlays.add(
              StickerOverlay(
                stickerId: stickerId,
                x: 0.5, // Center horizontally (normalized 0-1)
                y: 0.5, // Center vertically (normalized 0-1)
                scale: 1.0, // Default scale
                rotation: 0.0, // No rotation
              ),
            );
            _activeTool = 'none';
          });
          _onEditorChanged();
        },
      ),
    );
  }

  void _saveToGallery() async {
    final galleryService = locator<GalleryService>();
    bool success = false;

    try {
      if (_mediaType == 'video' && _selectedMedia != null) {
        final result = await galleryService.saveVideo(_selectedMedia!);
        success = result != null;
      } else if (_mediaType == 'image') {
        if (_selectedMediaBytes != null) {
          final result = await galleryService.saveImage(_selectedMediaBytes!);
          success = result != null;
        } else if (_selectedMedia != null) {
          final bytes = await _selectedMedia!.readAsBytes();
          final result = await galleryService.saveImage(bytes);
          success = result != null;
        }
      }

      if (mounted) {
        if (success) {
          HapticHelper.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved to Gallery')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save to gallery')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }

    // Reset active tool
    setState(() {
      _activeTool = 'none';
    });
  }

  // Audio import feature temporarily disabled - FFmpegKit compatibility issues
  // Method kept for future re-implementation but currently unused
  // ignore: unused_element
  Future<void> _showAudioImport() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Audio import feature is temporarily unavailable. Video trimming is still available.'),
          duration: AnimationTokens.slow,
        ),
      );
    }
  }

  // Audio merging feature temporarily disabled - FFmpegKit compatibility issues
  // Method kept for future re-implementation but currently unused
  // ignore: unused_element
  Future<File?> _mergeAudioWithMedia(File mediaFile) async {
    // Feature disabled - return original file without merging
    debugPrint(
        'StoryCreatorScreen: Audio merging disabled - returning original media file');
    return mediaFile;
  }
}
