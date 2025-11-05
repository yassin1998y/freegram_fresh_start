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
import 'package:freegram/blocs/unified_feed_bloc.dart';
import 'package:freegram/blocs/following_feed_bloc.dart';
import 'package:shimmer/shimmer.dart';

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

  List<MediaItem> _mediaItems = [];
  final Map<int, TextEditingController> _captionControllers = {};
  final Map<int, bool> _uploadingMedia =
      {}; // Track upload state per media item
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
  }

  @override
  void dispose() {
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
      Future.delayed(DesignTokens.durationNormal, () {
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
    Future.delayed(DesignTokens.durationNormal, () {
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
              margin: EdgeInsets.only(top: DesignTokens.spaceSM),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: DesignTokens.spaceMD),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
              child: Text(
                'Add Media',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: DesignTokens.spaceLG),
            // Options
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: theme.colorScheme.primary,
                size: DesignTokens.iconLG,
              ),
              title: Text(
                'Take Photo/Video',
                style: theme.textTheme.titleMedium,
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
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            SizedBox(height: DesignTokens.spaceMD),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    if (!mounted) return;

    // Show options: Photo or Video
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
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record Video'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
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

  Future<void> _pickFromGallery() async {
    if (!mounted) return;

    try {
      // Pick images
      final List<XFile> images = await _imagePicker.pickMultiImage();

      // Pick video (if user wants to add video too)
      // Note: We'll combine both in one flow
      final List<XFile> allFiles = List.from(images);

      // For now, we'll let users pick images first, then optionally add video
      // In a future enhancement, we could use a unified picker

      if (allFiles.isNotEmpty && mounted) {
        for (final file in allFiles) {
          await _uploadAndAddMedia(file, 'image');
        }
        _expand();
      }

      // Optionally allow adding video separately
      // For simplicity, we'll just handle images from gallery for now
      // Users can use camera for video if needed
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

    // Add placeholder item immediately with loading state
    setState(() {
      _uploadingMedia[newIndex] = true;
      _mediaItems.add(MediaItem(url: '', type: type)); // Placeholder
    });

    try {
      String? url;
      if (type == 'video') {
        // For video, we might need different upload logic
        // For now, using the same service
        url = await CloudinaryService.uploadImageFromXFile(file);
      } else {
        url = await CloudinaryService.uploadImageFromXFile(file);
      }

      if (url != null && mounted) {
        final captionController = TextEditingController();
        _captionControllers[newIndex] = captionController;

        setState(() {
          _mediaItems[newIndex] = MediaItem(url: url!, type: type);
          _uploadingMedia.remove(newIndex);
        });
      } else if (mounted) {
        setState(() {
          _mediaItems.removeAt(newIndex);
          _uploadingMedia.remove(newIndex);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload media')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_mediaItems.length > newIndex) {
            _mediaItems.removeAt(newIndex);
          }
          _uploadingMedia.remove(newIndex);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading: $e')),
        );
      }
    }
  }

  void _removeMedia(int index) {
    if (!mounted) return;

    // Dispose the controller for this index
    _captionControllers[index]?.dispose();
    _captionControllers.remove(index);

    // Reindex all controllers after the removed index
    final newControllers = <int, TextEditingController>{};
    for (int i = 0; i < _mediaItems.length; i++) {
      if (i < index) {
        // Keep controllers before the removed index
        if (_captionControllers.containsKey(i)) {
          newControllers[i] = _captionControllers[i]!;
        }
      } else if (i > index) {
        // Shift controllers after the removed index
        if (_captionControllers.containsKey(i)) {
          newControllers[i - 1] = _captionControllers[i]!;
        }
      }
    }

    setState(() {
      _mediaItems.removeAt(index);
      _captionControllers.clear();
      _captionControllers.addAll(newControllers);
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
              padding: EdgeInsets.all(DesignTokens.spaceMD),
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
        mediaItemsWithCaptions.add(_mediaItems[i].copyWith(caption: caption));
      }

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

          try {
            // Refresh FollowingFeedBloc (for Following feed)
            context.read<FollowingFeedBloc>().add(
                  LoadFollowingFeedEvent(
                    userId: user.uid,
                    refresh: true,
                  ),
                );
          } catch (e) {
            // FollowingFeedBloc might not be available in this context, that's okay
            debugPrint(
                'CreatePostWidget: Could not refresh FollowingFeedBloc: $e');
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
      duration: DesignTokens.durationNormal,
      curve: DesignTokens.curveEaseInOut,
      color: theme.scaffoldBackgroundColor,
      padding: EdgeInsets.symmetric(
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
      padding: EdgeInsets.all(DesignTokens.spaceMD),
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
          SizedBox(width: DesignTokens.spaceMD),
          // Text Input Field (tappable)
          Expanded(
            child: GestureDetector(
              onTap: _handleInputFieldTap,
              child: Container(
                padding: EdgeInsets.symmetric(
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
          SizedBox(width: DesignTokens.spaceSM),
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
      padding: EdgeInsets.all(DesignTokens.spaceMD),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with collapse button
          Row(
            children: [
              // Avatar
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
              SizedBox(width: DesignTokens.spaceSM),
              Expanded(
                child: Text(
                  displayName,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _collapse,
              ),
            ],
          ),
          SizedBox(height: DesignTokens.spaceMD),
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

                  return Padding(
                    padding: EdgeInsets.only(right: DesignTokens.spaceSM),
                    child: Stack(
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusMD),
                            image: (mediaItem.type == 'video' ||
                                    isUploading ||
                                    mediaItem.url.isEmpty)
                                ? null
                                : DecorationImage(
                                    image: CachedNetworkImageProvider(
                                        mediaItem.url),
                                    fit: BoxFit.cover,
                                  ),
                            color: (mediaItem.type == 'video' ||
                                    isUploading ||
                                    mediaItem.url.isEmpty)
                                ? theme.colorScheme.surfaceContainerHighest
                                : null,
                          ),
                          child: isUploading
                              ? _buildShimmerLoader(theme)
                              : (mediaItem.type == 'video' &&
                                      mediaItem.url.isNotEmpty)
                                  ? const Center(
                                      child: Icon(
                                        Icons.play_circle_filled,
                                        size: 48,
                                        color: Colors.white,
                                      ),
                                    )
                                  : (mediaItem.url.isEmpty)
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              CircularProgressIndicator(
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                              SizedBox(
                                                  height: DesignTokens.spaceSM),
                                              Text(
                                                'Uploading...',
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        )
                                      : null,
                        ),
                        if (!isUploading)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton(
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                              onPressed: () => _removeMedia(index),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (_mediaItems.isNotEmpty) SizedBox(height: DesignTokens.spaceMD),
          // Text Input
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
          SizedBox(height: DesignTokens.spaceMD),
          // Footer Toolbar
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
              // Post button - Enable if there's text OR media
              FilledButton(
                onPressed: (_isPosting ||
                        (_contentController.text.trim().isEmpty &&
                            _mediaItems.isEmpty))
                    ? null
                    : _createPost,
                child: _isPosting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Text('Post'),
              ),
            ],
          ),
          // Location chip if enabled
          if (_isLocationEnabled) ...[
            SizedBox(height: DesignTokens.spaceSM),
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
                  padding: EdgeInsets.all(DesignTokens.spaceMD),
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
                  title: Text('Public'),
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
                  title: Text('Friends'),
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
                  title: Text('Nearby'),
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
                SizedBox(height: DesignTokens.spaceMD),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(
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
            SizedBox(width: DesignTokens.spaceXS),
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
}
