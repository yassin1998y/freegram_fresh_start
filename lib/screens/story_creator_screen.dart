// lib/screens/story_creator_screen.dart

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
import 'package:freegram/repositories/story_repository.dart';
import 'package:freegram/models/text_overlay_model.dart';
import 'package:freegram/models/drawing_path_model.dart';
import 'package:freegram/models/sticker_overlay_model.dart';
import 'package:freegram/widgets/story_widgets/drawing_canvas.dart';
import 'package:freegram/widgets/story_widgets/drawing_toolbar.dart';
import 'package:freegram/widgets/story_widgets/sticker_picker_sheet.dart';
import 'package:freegram/widgets/story_widgets/draggable_sticker_widget.dart';
import 'package:freegram/widgets/story_widgets/draggable_text_widget.dart';

class StoryCreatorScreen extends StatefulWidget {
  const StoryCreatorScreen({Key? key}) : super(key: key);

  @override
  State<StoryCreatorScreen> createState() => _StoryCreatorScreenState();
}

class _StoryCreatorScreenState extends State<StoryCreatorScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final StoryRepository _storyRepository = locator<StoryRepository>();

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
  String _activeTool = 'none'; // 'none', 'text', 'draw', 'stickers'
  List<TextOverlay> _textOverlays = [];
  List<DrawingPath> _drawings = [];
  List<String> _stickerIds = []; // Legacy
  List<StickerOverlay> _stickerOverlays =
      []; // New with position/scale/rotation

  // Drawing tool state
  Color _drawingColor = Colors.white;
  double _drawingStrokeWidth = 5.0;

  @override
  void initState() {
    super.initState();
    // Note: Media picker will be shown via StoryCreatorTypeScreen modal
    // This screen should only be shown when media is already selected
    // For backward compatibility, we keep the picker call but it can be removed in future
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedMedia == null && _selectedMediaBytes == null) {
        _showMediaPicker();
      }
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _videoPreviewController?.dispose();
    super.dispose();
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

      // Auto-stop after 15 seconds (max duration)
      Future.delayed(const Duration(seconds: 15), () {
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

      // Check video duration (max 15 seconds)
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      final duration = controller.value.duration;

      if (duration.inSeconds > 15) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video too long. Maximum 15 seconds allowed.'),
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
              leading:
                  Icon(Icons.camera_alt, color: theme.colorScheme.onSurface),
              title: Text('Camera', style: theme.textTheme.bodyMedium),
              onTap: () => Navigator.of(context).pop({
                'source': ImageSource.camera,
                'type': 'image',
              }),
            ),
            ListTile(
              leading:
                  Icon(Icons.photo_library, color: theme.colorScheme.onSurface),
              title:
                  Text('Photo from Gallery', style: theme.textTheme.bodyMedium),
              onTap: () => Navigator.of(context).pop({
                'source': ImageSource.gallery,
                'type': 'image',
              }),
            ),
            if (!kIsWeb)
              ListTile(
                leading: Icon(Icons.video_library,
                    color: theme.colorScheme.onSurface),
                title: Text('Video from Gallery',
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
      final type = result['type'] as String? ?? 'image';

      if (source == ImageSource.camera) {
        // Initialize camera instead of showing picker
        await _initializeCamera();
      } else {
        await _pickMedia(source, mediaType: type);
      }
    } else {
      // User cancelled, go back
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _pickMedia(ImageSource source,
      {String mediaType = 'image'}) async {
    try {
      if (source == ImageSource.camera) {
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
      }

      XFile? pickedFile;

      if (mediaType == 'video') {
        // Pick video (max 15 seconds)
        pickedFile = await _imagePicker
            .pickVideo(
              source: source,
              maxDuration: const Duration(seconds: 15),
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
              maxWidth: 1080,
              maxHeight: 1920,
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

        if (mounted) {
          if (kIsWeb && mediaType == 'image') {
            // For web, read file as bytes (images only)
            final bytes = await pickedFile.readAsBytes();
            setState(() {
              _selectedMediaBytes = bytes;
              _mediaType = 'image';
            });
          } else if (!kIsWeb) {
            final file = File(pickedFile.path);

            if (mediaType == 'video') {
              // Initialize video preview
              _videoPreviewController = VideoPlayerController.file(file);
              await _videoPreviewController!.initialize();
              await _videoPreviewController!.play();

              setState(() {
                _selectedMedia = file;
                _mediaType = 'video';
              });
            } else {
              setState(() {
                _selectedMedia = file;
                _mediaType = 'image';
              });
            }
          }
        }
      } else {
        // User cancelled
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

    setState(() {
      _isUploading = true;
    });

    try {
      if (kIsWeb && _selectedMediaBytes != null) {
        // For web, upload directly from bytes
        await _storyRepository.createStoryFromBytes(
          userId: currentUser.uid,
          mediaBytes: _selectedMediaBytes!,
          mediaType: _mediaType,
          textOverlays: _textOverlays.isNotEmpty ? _textOverlays : null,
          drawings: _drawings.isNotEmpty ? _drawings : null,
          stickerIds: _stickerIds.isNotEmpty ? _stickerIds : null,
          stickerOverlays:
              _stickerOverlays.isNotEmpty ? _stickerOverlays : null,
        );
      } else if (!kIsWeb && _selectedMedia != null) {
        await _storyRepository.createStory(
          userId: currentUser.uid,
          mediaFile: _selectedMedia!,
          mediaType: _mediaType,
          textOverlays: _textOverlays.isNotEmpty ? _textOverlays : null,
          drawings: _drawings.isNotEmpty ? _drawings : null,
          stickerIds: _stickerIds.isNotEmpty ? _stickerIds : null,
          stickerOverlays:
              _stickerOverlays.isNotEmpty ? _stickerOverlays : null,
        );
      } else {
        throw Exception('No media available');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story shared successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Ask if user wants to post another story
        final postAnother = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Story Posted!',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Would you like to post another story?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child:
                    const Text('Done', style: TextStyle(color: Colors.white70)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Post Another',
                  style: TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

        if (postAnother == true) {
          // Reset state for new story
          setState(() {
            _selectedMedia = null;
            _selectedMediaBytes = null;
            _videoPreviewController?.dispose();
            _videoPreviewController = null;
            _textOverlays = [];
            _drawings = [];
            _stickerIds = [];
            _stickerOverlays = [];
            _activeTool = 'none';
            _drawingColor = Colors.white;
            _drawingStrokeWidth = 5.0;
          });
          // Show media picker again
          _showMediaPicker();
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('Error sharing story: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing story: $e')),
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
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // Show camera preview if camera is initialized and no media selected
    if (_isCameraInitialized &&
        _selectedMedia == null &&
        _cameraController != null) {
      return Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),
          // Top controls (camera switch, close)
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                if (_cameras != null && _cameras!.length > 1)
                  IconButton(
                    icon:
                        const Icon(Icons.flip_camera_ios, color: Colors.white),
                    onPressed: _switchCamera,
                  ),
              ],
            ),
          ),
          // Bottom controls (capture buttons)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Photo capture button
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: Colors.transparent,
                    ),
                    child:
                        const Icon(Icons.camera, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(width: 40),
                // Video record button (long press)
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
          // Recording indicator
          if (_isRecordingVideo)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Recording...',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    }

    // Show media preview if media is selected
    if (_selectedMedia != null || _selectedMediaBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Media preview - fill screen
          Positioned.fill(
            child: _mediaType == 'image'
                ? kIsWeb && _selectedMediaBytes != null
                    ? Image.memory(
                        _selectedMediaBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : !kIsWeb && _selectedMedia != null
                        ? Image.file(
                            _selectedMedia!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          )
                : _videoPreviewController != null &&
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
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
          ),

          // Drawing canvas (only when drawing tool is active)
          if (_activeTool == 'draw')
            Positioned.fill(
              child: DrawingCanvas(
                drawings: _drawings,
                onDrawingsChanged: (drawings) {
                  setState(() {
                    _drawings = drawings;
                  });
                },
                currentColor: _drawingColor,
                currentStrokeWidth: _drawingStrokeWidth,
                isDrawingEnabled: _activeTool == 'draw',
              ),
            ),

          // Draggable text overlays
          ..._textOverlays.asMap().entries.map((entry) {
            final index = entry.key;
            final overlay = entry.value;
            return DraggableTextWidget(
              key: ValueKey('text_$index'),
              overlay: overlay,
              onOverlayChanged: (updated) {
                setState(() {
                  _textOverlays[index] = updated;
                });
              },
              onEdit: () => _editTextOverlay(index),
              onDelete: () {
                setState(() {
                  _textOverlays.removeAt(index);
                });
              },
            );
          }),

          // Draggable stickers
          ..._stickerOverlays.asMap().entries.map((entry) {
            final index = entry.key;
            final sticker = entry.value;
            return DraggableStickerWidget(
              key: ValueKey('sticker_$index'),
              stickerId: sticker.stickerId,
              initialX: sticker.x,
              initialY: sticker.y,
              initialScale: sticker.scale,
              initialRotation: sticker.rotation,
              onPositionChanged: (x, y, scale, rotation) {
                setState(() {
                  _stickerOverlays[index] = sticker.copyWith(
                    x: x,
                    y: y,
                    scale: scale,
                    rotation: rotation,
                  );
                });
              },
              onDelete: () {
                setState(() {
                  _stickerOverlays.removeAt(index);
                });
              },
            );
          }),

          // Drawing toolbar (when drawing tool is active)
          if (_activeTool == 'draw')
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: DrawingToolbar(
                  selectedColor: _drawingColor,
                  selectedStrokeWidth: _drawingStrokeWidth,
                  onColorSelected: (color) {
                    setState(() {
                      _drawingColor = color;
                    });
                  },
                  onStrokeWidthSelected: (width) {
                    setState(() {
                      _drawingStrokeWidth = width;
                    });
                  },
                ),
              ),
            ),

          // Top-right toolbar (Text, Draw, Stickers)
          if (_selectedMedia != null || _selectedMediaBytes != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToolButton(
                      theme: theme,
                      icon: Icons.text_fields,
                      isActive: _activeTool == 'text',
                      onTap: () {
                        setState(() {
                          _activeTool = _activeTool == 'text' ? 'none' : 'text';
                        });
                        if (_activeTool == 'text') {
                          _addTextOverlay();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildToolButton(
                      theme: theme,
                      icon: Icons.edit,
                      isActive: _activeTool == 'draw',
                      onTap: () {
                        setState(() {
                          _activeTool = _activeTool == 'draw' ? 'none' : 'draw';
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildToolButton(
                      theme: theme,
                      icon: Icons.emoji_emotions,
                      isActive: _activeTool == 'stickers',
                      onTap: () {
                        if (_activeTool == 'stickers') {
                          setState(() {
                            _activeTool = 'none';
                          });
                        } else {
                          setState(() {
                            _activeTool = 'stickers';
                          });
                          _showStickerPicker();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Bottom-right Share button
          if (_selectedMedia != null || _selectedMediaBytes != null)
            Positioned(
              bottom: 24,
              right: 24,
              child: _isUploading
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _shareStory,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.send, size: 18),
                      label: Text(
                        'Share',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
            ),
        ],
      );
    }

    // Show loading or picker
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _buildToolButton({
    required ThemeData theme,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color:
            isActive ? theme.colorScheme.primary : theme.colorScheme.onPrimary,
        size: 24,
      ),
      style: IconButton.styleFrom(
        backgroundColor: isActive
            ? theme.colorScheme.primary.withOpacity(0.2)
            : Colors.transparent,
      ),
    );
  }

  void _addTextOverlay() {
    // Add a new text overlay at center
    setState(() {
      _textOverlays.add(
        const TextOverlay(
          text: 'Tap to edit',
          x: 0.5,
          y: 0.5,
          fontSize: 24,
          color: '#FFFFFF',
          style: 'bold',
        ),
      );
    });

    // Show text editor dialog
    _editTextOverlay(_textOverlays.length - 1);
  }

  void _editTextOverlay(int index) {
    if (index < 0 || index >= _textOverlays.length) return;

    final overlay = _textOverlays[index];
    final textController = TextEditingController(text: overlay.text);
    String selectedColor = overlay.color;
    String selectedStyle = overlay.style;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Edit Text',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Enter text',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 16),
                // Color picker
                const Text(
                  'Color:',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Colors.white,
                    Colors.black,
                    Colors.red,
                    Colors.blue,
                    Colors.green,
                    Colors.yellow,
                    Colors.purple,
                    Colors.orange,
                  ].map((color) {
                    final hexColor =
                        '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                    final isSelected = hexColor == selectedColor;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedColor = hexColor;
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isSelected ? Colors.white : Colors.transparent,
                            width: isSelected ? 3 : 0,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Style picker
                const Text(
                  'Style:',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['bold', 'outline', 'neon'].map((style) {
                    final isSelected = style == selectedStyle;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedStyle = style;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          style.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    _textOverlays[index] = overlay.copyWith(
                      text: text,
                      color: selectedColor,
                      style: selectedStyle,
                    );
                  });
                }
                Navigator.of(context).pop();
              },
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StickerPickerSheet(
        onStickerSelected: (stickerId) {
          setState(() {
            _stickerOverlays.add(
              StickerOverlay(
                stickerId: stickerId,
                x: 0.5,
                y: 0.5,
                scale: 1.0,
                rotation: 0.0,
              ),
            );
          });
        },
      ),
    );
  }
}
