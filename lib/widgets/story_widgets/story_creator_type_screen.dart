// lib/widgets/story_widgets/story_creator_type_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:photo_manager/photo_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:freegram/screens/story_creator_screen.dart';
import 'package:freegram/screens/text_story_creator_screen.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/gallery_service.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/utils/story_constants.dart';

class StoryCreatorTypeScreen extends StatefulWidget {
  const StoryCreatorTypeScreen({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const StoryCreatorTypeScreen(),
    );
  }

  @override
  State<StoryCreatorTypeScreen> createState() => _StoryCreatorTypeScreenState();
}

class _StoryCreatorTypeScreenState extends State<StoryCreatorTypeScreen> {
  final GalleryService _galleryService = locator<GalleryService>();
  final NavigationService _navigationService = locator<NavigationService>();

  List<AssetEntity> _recentPhotos = [];
  List<AssetEntity> _recentVideos = [];
  bool _isLoadingPhotos = false;
  bool _isLoadingVideos = false;
  bool _hasPhotosPermission = false;
  String? _loadingError;
  String? _videoLoadingError;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: story_creator_type_screen.dart');
    _loadRecentPhotos();
    _loadRecentVideos();
  }

  Future<void> _loadRecentPhotos() async {
    if (kIsWeb) {
      // Web doesn't support photo_manager
      return;
    }

    setState(() {
      _isLoadingPhotos = true;
      _loadingError = null;
    });

    try {
      // Check permission first
      _hasPhotosPermission = await _galleryService.hasPhotosPermission();

      if (!_hasPhotosPermission) {
        _hasPhotosPermission = await _galleryService.requestPhotosPermission();
      }

      if (_hasPhotosPermission) {
        final photos = await _galleryService.getRecentPhotos(limit: 10);
        if (mounted) {
          setState(() {
            _recentPhotos = photos;
            _isLoadingPhotos = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingPhotos = false;
            _loadingError = 'Photos permission denied';
          });
        }
      }
    } catch (e) {
      debugPrint('StoryCreatorTypeScreen: Error loading photos: $e');
      if (mounted) {
        setState(() {
          _isLoadingPhotos = false;
          _loadingError = 'Failed to load photos';
        });
      }
    }
  }

  Future<void> _loadRecentVideos() async {
    if (kIsWeb) {
      // Web doesn't support photo_manager
      return;
    }

    setState(() {
      _isLoadingVideos = true;
      _videoLoadingError = null;
    });

    try {
      // Check permission first
      _hasPhotosPermission = await _galleryService.hasPhotosPermission();

      if (!_hasPhotosPermission) {
        _hasPhotosPermission = await _galleryService.requestPhotosPermission();
      }

      if (_hasPhotosPermission) {
        final videos = await _galleryService.getRecentVideos(limit: 10);
        if (mounted) {
          setState(() {
            _recentVideos = videos;
            _isLoadingVideos = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingVideos = false;
            _videoLoadingError = 'Videos permission denied';
          });
        }
      }
    } catch (e) {
      debugPrint('StoryCreatorTypeScreen: Error loading videos: $e');
      if (mounted) {
        setState(() {
          _isLoadingVideos = false;
          _videoLoadingError = 'Failed to load videos';
        });
      }
    }
  }

  Future<void> _handlePhotoTap(AssetEntity asset) async {
    HapticFeedback.lightImpact();

    try {
      // CRITICAL FIX: Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Loading photo...'),
            duration: AnimationTokens.fast,
          ),
        );
      }

      debugPrint(
          'StoryCreatorTypeScreen: Loading photo from asset: ${asset.id}');
      final file = await _galleryService.getFileFromAsset(asset);

      if (file == null) {
        debugPrint('StoryCreatorTypeScreen: Failed to get file from asset');
        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to load photo. Please try again.'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
        return;
      }

      // CRITICAL FIX: Verify file exists before navigating
      if (!await file.exists()) {
        debugPrint('StoryCreatorTypeScreen: File does not exist: ${file.path}');
        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('Photo file not found. Please try another photo.'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
        return;
      }

      debugPrint(
          'StoryCreatorScreen: Photo file loaded successfully: ${file.path}');

      if (mounted) {
        Navigator.of(context).pop(); // Close the type selection screen
        // Navigate to story creator with selected photo
        _navigationService.navigateTo(
          StoryCreatorScreen(
            preSelectedMedia: file,
            mediaType: 'image',
          ),
        );
      }
    } catch (e) {
      debugPrint('StoryCreatorTypeScreen: Error handling photo tap: $e');
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading photo: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleVideoTap(AssetEntity asset) async {
    HapticFeedback.lightImpact();

    try {
      // CRITICAL FIX: Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Loading video...'),
            duration: AnimationTokens.fast,
          ),
        );
      }

      debugPrint(
          'StoryCreatorTypeScreen: Loading video from asset: ${asset.id}');
      final file = await _galleryService.getFileFromAsset(asset);

      if (file == null) {
        debugPrint('StoryCreatorTypeScreen: Failed to get file from asset');
        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to load video. Please try again.'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
        return;
      }

      // CRITICAL FIX: Verify file exists before navigating
      if (!await file.exists()) {
        debugPrint('StoryCreatorTypeScreen: File does not exist: ${file.path}');
        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('Video file not found. Please try another video.'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
        return;
      }

      debugPrint(
          'StoryCreatorScreen: Video file loaded successfully: ${file.path}');

      if (mounted) {
        Navigator.of(context).pop(); // Close the type selection screen
        // Navigate to story creator with selected video
        _navigationService.navigateTo(
          StoryCreatorScreen(
            preSelectedMedia: file,
            mediaType: 'video',
          ),
        );
      }
    } catch (e) {
      debugPrint('StoryCreatorTypeScreen: Error handling video tap: $e');
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleOptionTap({
    required VoidCallback onTap,
  }) async {
    HapticFeedback.mediumImpact();

    // CRITICAL FIX: Get root context before closing bottom sheet
    final rootContext = _navigationService.navigatorKey.currentContext;
    if (rootContext == null) {
      debugPrint(
          'StoryCreatorTypeScreen: Root context is null, cannot proceed');
      return;
    }

    // Close bottom sheet first
    Navigator.of(context).pop();

    // Wait for bottom sheet to close
    await Future.delayed(AnimationTokens.fast);

    // Execute callback after sheet is closed
    if (rootContext.mounted) {
      onTap();
    } else {
      debugPrint(
          'StoryCreatorTypeScreen: Root context no longer mounted after closing sheet');
    }
  }

  List<Widget> _buildVideoOptionCards(BuildContext context, ThemeData theme) {
    if (kIsWeb) return [];

    return [
      _buildOptionCard(
        context: context,
        theme: theme,
        icon: Icons.video_library,
        label: 'Choose Video',
        subtitle: 'Select a video from your gallery',
        onTap: () async {
          debugPrint('StoryCreatorTypeScreen: Choose Video tapped');
          HapticFeedback.mediumImpact();

          // CRITICAL FIX: Get root context before closing bottom sheet
          final rootContext = _navigationService.navigatorKey.currentContext;
          if (rootContext == null) {
            debugPrint(
                'StoryCreatorTypeScreen: Root context is null, cannot proceed');
            return;
          }

          // Close bottom sheet first
          Navigator.of(context).pop();

          // Wait for bottom sheet to close
          await Future.delayed(AnimationTokens.fast);

          if (!rootContext.mounted) {
            debugPrint(
                'StoryCreatorTypeScreen: Root context no longer mounted');
            return;
          }

          try {
            // CRITICAL FIX: Let ImagePicker handle permissions internally
            // Don't request permissions manually as it conflicts with ImagePicker
            final ImagePicker picker = ImagePicker();

            debugPrint('StoryCreatorTypeScreen: Opening video picker...');
            final XFile? video = await picker
                .pickVideo(
              source: ImageSource.gallery,
              maxDuration:
                  Duration(seconds: StoryConstants.maxVideoDurationSeconds),
            )
                .timeout(
              const Duration(seconds: 30), // Standard timeout
              onTimeout: () {
                debugPrint('StoryCreatorTypeScreen: Video picker timed out');
                return null;
              },
            );

            debugPrint(
                'StoryCreatorTypeScreen: Video picker returned: ${video != null ? video.path : "null"}');

            if (video != null) {
              try {
                final file = File(video.path);
                debugPrint(
                    'StoryCreatorTypeScreen: Verifying file exists: ${file.path}');

                // CRITICAL FIX: Verify file exists
                if (await file.exists()) {
                  final fileSize = await file.length();
                  debugPrint(
                      'StoryCreatorTypeScreen: File exists, size: $fileSize bytes');

                  if (fileSize > 0) {
                    debugPrint(
                        'StoryCreatorTypeScreen: Navigating to StoryCreatorScreen with video');
                    // Use root context for navigation
                    if (rootContext.mounted) {
                      await _navigationService.navigateTo(
                        StoryCreatorScreen(
                          preSelectedMedia: file,
                          mediaType: 'video',
                        ),
                      );
                      debugPrint(
                          'StoryCreatorTypeScreen: Navigation completed');
                    } else {
                      debugPrint(
                          'StoryCreatorTypeScreen: Root context no longer mounted');
                    }
                  } else {
                    debugPrint('StoryCreatorTypeScreen: File is empty');
                    if (rootContext.mounted) {
                      final theme = Theme.of(rootContext);
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        SnackBar(
                          content: const Text('Selected video is empty'),
                          backgroundColor: theme.colorScheme.error,
                        ),
                      );
                    }
                  }
                } else {
                  debugPrint('StoryCreatorTypeScreen: File does not exist');
                  if (rootContext.mounted) {
                    final theme = Theme.of(rootContext);
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      SnackBar(
                        content: const Text(
                            'Selected video not found. Please try again.'),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                  }
                }
              } catch (e, stackTrace) {
                debugPrint(
                    'StoryCreatorTypeScreen: Error handling video picker: $e');
                debugPrint('StoryCreatorTypeScreen: Stack trace: $stackTrace');
                if (rootContext.mounted) {
                  final theme = Theme.of(rootContext);
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content: Text('Error loading video: $e'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              }
            } else {
              debugPrint(
                  'StoryCreatorTypeScreen: User cancelled or picker returned null');
              // User cancelled - no need to show error
            }
          } catch (e, stackTrace) {
            debugPrint('StoryCreatorTypeScreen: Error in Choose Video: $e');
            debugPrint('StoryCreatorTypeScreen: Stack trace: $stackTrace');
            if (rootContext.mounted) {
              final theme = Theme.of(rootContext);
              ScaffoldMessenger.of(rootContext).showSnackBar(
                SnackBar(
                  content: Text('Failed to open gallery: $e'),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            }
          }
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DesignTokens.radiusXL),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: DesignTokens.spaceXL,
                height: DesignTokens.spaceXS,
                margin:
                    const EdgeInsets.symmetric(vertical: DesignTokens.spaceSM),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface
                      .withOpacity(DesignTokens.opacityMedium),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMD,
                  vertical: DesignTokens.spaceSM,
                ),
                child: Row(
                  children: [
                    Text(
                      'Create Story',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Semantics(
                      label: 'Close story creator',
                      button: true,
                      child: IconButton(
                        icon: Icon(
                          Icons.close,
                          color: theme.colorScheme.onSurface,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: DesignTokens.elevation1,
                color: theme.dividerColor,
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                      vertical: DesignTokens.spaceMD),
                  children: [
                    // Camera option (prominent)
                    _buildPrimaryOptionCard(
                      context: context,
                      theme: theme,
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      subtitle: 'Take a photo or record a video',
                      gradient: const LinearGradient(
                        colors: [
                          SonarPulseTheme.primaryAccent,
                          SonarPulseTheme.primaryAccentLight,
                        ],
                      ),
                      onTap: () => _handleOptionTap(
                        onTap: () {
                          _navigationService.navigateTo(
                            const StoryCreatorScreen(openCamera: true),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: DesignTokens.spaceMD),

                    // Text Story option
                    _buildOptionCard(
                      context: context,
                      theme: theme,
                      icon: Icons.text_fields,
                      label: 'Text Story',
                      subtitle: 'Create a text-only story',
                      onTap: () => _handleOptionTap(
                        onTap: () {
                          _navigationService.navigateTo(
                            const TextStoryCreatorScreen(),
                          );
                        },
                      ),
                    ),

                    // Gallery option - Photos
                    _buildOptionCard(
                      context: context,
                      theme: theme,
                      icon: Icons.photo_library,
                      label: 'Choose Photo',
                      subtitle: 'Select a photo from your gallery',
                      onTap: () async {
                        debugPrint(
                            'StoryCreatorTypeScreen: Choose Photo tapped');
                        HapticFeedback.mediumImpact();

                        // CRITICAL FIX: Get root context before closing bottom sheet
                        final rootContext =
                            _navigationService.navigatorKey.currentContext;
                        if (rootContext == null) {
                          debugPrint(
                              'StoryCreatorTypeScreen: Root context is null, cannot proceed');
                          return;
                        }

                        // Close bottom sheet first
                        Navigator.of(context).pop();

                        // Wait for bottom sheet to close
                        await Future.delayed(AnimationTokens.fast);

                        if (!rootContext.mounted) {
                          debugPrint(
                              'StoryCreatorTypeScreen: Root context no longer mounted');
                          return;
                        }

                        try {
                          // CRITICAL FIX: Let ImagePicker handle permissions internally
                          // Don't request permissions manually as it conflicts with ImagePicker
                          final ImagePicker picker = ImagePicker();

                          debugPrint(
                              'StoryCreatorTypeScreen: Opening image picker...');
                          final XFile? image = await picker
                              .pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                            maxWidth: StoryConstants.storyWidth,
                            maxHeight: StoryConstants.storyHeight,
                          )
                              .timeout(
                            const Duration(seconds: 30), // Standard timeout
                            onTimeout: () {
                              debugPrint(
                                  'StoryCreatorTypeScreen: Image picker timed out');
                              return null;
                            },
                          );

                          debugPrint(
                              'StoryCreatorTypeScreen: Image picker returned: ${image != null ? image.path : "null"}');

                          if (image != null) {
                            try {
                              final file = File(image.path);
                              debugPrint(
                                  'StoryCreatorTypeScreen: Verifying file exists: ${file.path}');

                              // CRITICAL FIX: Verify file exists
                              if (await file.exists()) {
                                final fileSize = await file.length();
                                debugPrint(
                                    'StoryCreatorTypeScreen: File exists, size: $fileSize bytes');

                                if (fileSize > 0) {
                                  debugPrint(
                                      'StoryCreatorTypeScreen: Navigating to StoryCreatorScreen with image');
                                  // Use root context for navigation
                                  if (rootContext.mounted) {
                                    await _navigationService.navigateTo(
                                      StoryCreatorScreen(
                                        preSelectedMedia: file,
                                        mediaType: 'image',
                                      ),
                                    );
                                    debugPrint(
                                        'StoryCreatorTypeScreen: Navigation completed');
                                  } else {
                                    debugPrint(
                                        'StoryCreatorTypeScreen: Root context no longer mounted');
                                  }
                                } else {
                                  debugPrint(
                                      'StoryCreatorTypeScreen: File is empty');
                                  if (rootContext.mounted) {
                                    final theme = Theme.of(rootContext);
                                    ScaffoldMessenger.of(rootContext)
                                        .showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                            'Selected image is empty'),
                                        backgroundColor:
                                            theme.colorScheme.error,
                                      ),
                                    );
                                  }
                                }
                              } else {
                                debugPrint(
                                    'StoryCreatorTypeScreen: File does not exist');
                                if (rootContext.mounted) {
                                  final theme = Theme.of(rootContext);
                                  ScaffoldMessenger.of(rootContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          'Selected image not found. Please try again.'),
                                      backgroundColor: theme.colorScheme.error,
                                    ),
                                  );
                                }
                              }
                            } catch (e, stackTrace) {
                              debugPrint(
                                  'StoryCreatorTypeScreen: Error handling image picker: $e');
                              debugPrint(
                                  'StoryCreatorTypeScreen: Stack trace: $stackTrace');
                              if (rootContext.mounted) {
                                final theme = Theme.of(rootContext);
                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Error loading image: $e'),
                                    backgroundColor: theme.colorScheme.error,
                                  ),
                                );
                              }
                            }
                          } else {
                            debugPrint(
                                'StoryCreatorTypeScreen: User cancelled or picker returned null');
                            // User cancelled - no need to show error
                          }
                        } catch (e, stackTrace) {
                          debugPrint(
                              'StoryCreatorTypeScreen: Error in Choose Photo: $e');
                          debugPrint(
                              'StoryCreatorTypeScreen: Stack trace: $stackTrace');
                          if (rootContext.mounted) {
                            final theme = Theme.of(rootContext);
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(
                                content: Text('Failed to open gallery: $e'),
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                    ),

                    // Gallery option - Videos
                    ..._buildVideoOptionCards(context, theme),

                    // Recent Gallery Photos section
                    if (!kIsWeb && _hasPhotosPermission) ...[
                      const SizedBox(height: DesignTokens.spaceLG),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spaceMD,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Recent Photos',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (_loadingError == null)
                              TextButton(
                                onPressed: _loadRecentPhotos,
                                child: Text(
                                  'Refresh',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: SonarPulseTheme.primaryAccent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceSM),
                      if (_isLoadingPhotos)
                        SizedBox(
                          height:
                              DesignTokens.spaceXXXL + DesignTokens.spaceXXL,
                          child: Center(
                            child: AppProgressIndicator(
                              color: SonarPulseTheme.primaryAccent,
                            ),
                          ),
                        )
                      else if (_loadingError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceMD,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(DesignTokens.spaceMD),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusMD),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: theme.colorScheme.error,
                                  size: DesignTokens.iconMD,
                                ),
                                const SizedBox(width: DesignTokens.spaceSM),
                                Expanded(
                                  child: Text(
                                    _loadingError!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loadRecentPhotos,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_recentPhotos.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceMD,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(DesignTokens.spaceMD),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusMD),
                            ),
                            child: Center(
                              child: Text(
                                'No recent photos',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(DesignTokens.opacityMedium),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height:
                              DesignTokens.spaceXXXL + DesignTokens.spaceXXL,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceMD,
                            ),
                            itemCount: _recentPhotos.length,
                            itemBuilder: (context, index) {
                              final asset = _recentPhotos[index];
                              return _buildPhotoThumbnail(
                                context: context,
                                theme: theme,
                                asset: asset,
                                onTap: () => _handlePhotoTap(asset),
                              );
                            },
                          ),
                        ),
                    ],

                    // Recent Gallery Videos section
                    if (!kIsWeb && _hasPhotosPermission) ...[
                      const SizedBox(height: DesignTokens.spaceLG),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spaceMD,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Recent Videos',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (_videoLoadingError == null)
                              TextButton(
                                onPressed: _loadRecentVideos,
                                child: Text(
                                  'Refresh',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: SonarPulseTheme.primaryAccent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceSM),
                      if (_isLoadingVideos)
                        SizedBox(
                          height:
                              DesignTokens.spaceXXXL + DesignTokens.spaceXXL,
                          child: Center(
                            child: AppProgressIndicator(
                              color: SonarPulseTheme.primaryAccent,
                            ),
                          ),
                        )
                      else if (_videoLoadingError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceMD,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(DesignTokens.spaceMD),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusMD),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: theme.colorScheme.error,
                                  size: DesignTokens.iconMD,
                                ),
                                const SizedBox(width: DesignTokens.spaceSM),
                                Expanded(
                                  child: Text(
                                    _videoLoadingError!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loadRecentVideos,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_recentVideos.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceMD,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(DesignTokens.spaceMD),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusMD),
                            ),
                            child: Center(
                              child: Text(
                                'No recent videos',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(DesignTokens.opacityMedium),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height:
                              DesignTokens.spaceXXXL + DesignTokens.spaceXXL,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceMD,
                            ),
                            itemCount: _recentVideos.length,
                            itemBuilder: (context, index) {
                              final asset = _recentVideos[index];
                              return _buildVideoThumbnail(
                                context: context,
                                theme: theme,
                                asset: asset,
                                onTap: () => _handleVideoTap(asset),
                              );
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrimaryOptionCard({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
      child: Semantics(
        label: '$label: $subtitle',
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
            child: Container(
              padding: const EdgeInsets.all(DesignTokens.spaceLG),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
                boxShadow: [
                  BoxShadow(
                    color: SonarPulseTheme.primaryAccent.withOpacity(0.3),
                    blurRadius: DesignTokens.elevation3,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(DesignTokens.spaceMD),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onPrimary
                          .withOpacity(DesignTokens.opacityMedium),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: theme.colorScheme.onPrimary,
                      size: DesignTokens.iconXL,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spaceXS),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimary
                                .withOpacity(DesignTokens.opacityHigh),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: theme.colorScheme.onPrimary,
                    size: DesignTokens.iconSM,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMD,
        vertical: DesignTokens.spaceXS,
      ),
      child: Semantics(
        label: '$label: $subtitle',
        button: true,
        child: Card(
          margin: EdgeInsets.zero,
          color: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          ),
          elevation: DesignTokens.elevation1,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(DesignTokens.spaceSM),
                    decoration: BoxDecoration(
                      color: SonarPulseTheme.primaryAccent.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusSM),
                    ),
                    child: Icon(
                      icon,
                      color: SonarPulseTheme.primaryAccent,
                      size: DesignTokens.iconLG,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spaceXS),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withOpacity(DesignTokens.opacityMedium),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface
                        .withOpacity(DesignTokens.opacityMedium),
                    size: DesignTokens.iconMD,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail({
    required BuildContext context,
    required ThemeData theme,
    required AssetEntity asset,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: DesignTokens.spaceSM),
      child: Semantics(
        label: 'Recent photo ${asset.id}',
        image: true,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: DesignTokens.spaceXXXL - DesignTokens.spaceMD,
            height: DesignTokens.spaceXXXL - DesignTokens.spaceMD,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
                width: DesignTokens.elevation1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
              child: FutureBuilder<Widget?>(
                future: _buildThumbnailWidget(asset),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return snapshot.data!;
                  }
                  return Center(
                    child: Icon(
                      Icons.photo,
                      color: theme.colorScheme.onSurface
                          .withOpacity(DesignTokens.opacityMedium),
                      size: DesignTokens.iconMD,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail({
    required BuildContext context,
    required ThemeData theme,
    required AssetEntity asset,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: DesignTokens.spaceSM),
      child: Semantics(
        label: 'Recent video ${asset.id}',
        image: true,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: DesignTokens.spaceXXXL - DesignTokens.spaceMD,
            height: DesignTokens.spaceXXXL - DesignTokens.spaceMD,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
                width: DesignTokens.elevation1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<Widget?>(
                    future: _buildThumbnailWidget(asset),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        return snapshot.data!;
                      }
                      return Center(
                        child: Icon(
                          Icons.video_library,
                          color: theme.colorScheme.onSurface
                              .withOpacity(DesignTokens.opacityMedium),
                          size: DesignTokens.iconMD,
                        ),
                      );
                    },
                  ),
                  // Video play icon overlay
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(DesignTokens.spaceXS),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface
                            .withOpacity(DesignTokens.opacityMedium),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: theme.colorScheme.onSurface,
                        size: DesignTokens.iconSM,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<Widget?> _buildThumbnailWidget(AssetEntity asset) async {
    try {
      final thumbnail = await asset.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
      );
      if (thumbnail != null) {
        return Image.memory(
          thumbnail,
          fit: BoxFit.cover,
          width: DesignTokens.spaceXXXL - DesignTokens.spaceMD,
          height: DesignTokens.spaceXXXL - DesignTokens.spaceMD,
        );
      }
    } catch (e) {
      debugPrint('StoryCreatorTypeScreen: Error loading thumbnail: $e');
    }
    return null;
  }
}
