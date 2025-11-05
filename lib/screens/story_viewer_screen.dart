// lib/screens/story_viewer_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui' as ui;
import 'package:freegram/blocs/story_viewer_cubit.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/story_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/models/story_media_model.dart';
import 'package:freegram/models/text_overlay_model.dart';
import 'package:freegram/models/drawing_path_model.dart';
import 'package:freegram/models/sticker_overlay_model.dart';
import 'package:freegram/widgets/story_widgets/viewers_list_bottom_sheet.dart';

class StoryViewerScreen extends StatefulWidget {
  final String startingUserId;

  const StoryViewerScreen({
    Key? key,
    required this.startingUserId,
  }) : super(key: key);

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  VideoPlayerController? _videoController;
  final TextEditingController _replyController = TextEditingController();
  bool _showReplyBar = false;
  String? _currentStoryId; // Track current story to prevent reinitialization

  Future<void> _loadStoriesForViewer(
    StoryViewerCubit cubit,
    String viewerId,
    String startingUserId,
  ) async {
    try {
      debugPrint(
          'StoryViewerScreen: Loading stories for viewer $viewerId, starting user $startingUserId');

      // Always include the starting user (even if they're the viewer)
      final userIds = <String>[startingUserId];

      // Get user's friends list from repository
      try {
        final userRepository = locator<UserRepository>();
        final user = await userRepository.getUser(viewerId);
        final friends = user.friends;

        // Add friends who are not the starting user
        for (final friendId in friends) {
          if (friendId != startingUserId && !userIds.contains(friendId)) {
            userIds.add(friendId);
          }
        }
      } catch (e) {
        debugPrint('StoryViewerScreen: Error getting friends list: $e');
        // Continue with just the starting user
      }

      debugPrint(
          'StoryViewerScreen: Loading stories for ${userIds.length} users: $userIds');
      // Load stories for all these users
      await cubit.loadStoriesForUsers(userIds, startingUserId);
    } catch (e) {
      debugPrint('StoryViewerScreen: Error loading stories: $e');
      // Fallback: load just the starting user
      debugPrint(
          'StoryViewerScreen: Falling back to loading only starting user: $startingUserId');
      await cubit.loadStoriesForUsers([startingUserId], startingUserId);
    }
  }

  void _initializeVideoController(String storyId, String mediaUrl) {
    // If already initialized for this story, don't reinitialize
    if (_currentStoryId == storyId && _videoController != null) {
      return;
    }

    debugPrint(
        'StoryViewerScreen: Initializing video controller for story $storyId, URL: $mediaUrl');

    // Dispose old controller before creating new one
    _videoController?.dispose();
    _videoController = null;

    try {
      // Create and initialize new controller
      _videoController = VideoPlayerController.networkUrl(Uri.parse(mediaUrl));

      _videoController!.initialize().then((_) {
        // CRITICAL: Check mounted and controller validity before accessing
        if (!mounted || _videoController == null) {
          debugPrint(
              'StoryViewerScreen: Widget disposed or controller null after init');
          return;
        }
        if (!_videoController!.value.isInitialized) {
          debugPrint('StoryViewerScreen: Video controller not initialized');
          return;
        }

        debugPrint(
            'StoryViewerScreen: Video controller initialized successfully');
        if (mounted) {
          setState(() {
            _currentStoryId = storyId;
          });
          _videoController?.play();
        }
      }).catchError((error) {
        debugPrint('StoryViewerScreen: Error initializing video: $error');
        // Dispose controller on error
        if (_videoController != null && mounted) {
          _videoController?.dispose();
          _videoController = null;
        }
      });
    } catch (e) {
      debugPrint('StoryViewerScreen: Exception creating video controller: $e');
      _videoController = null;
    }
  }

  void _videoListener() {
    if (_videoController == null || !mounted) return;

    // Note: We don't access context here as listeners can fire during dispose
    // Video play/pause is handled by gesture controls and cubit state
  }

  @override
  void initState() {
    super.initState();
    // Enable immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _videoController = null;
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view stories')),
      );
    }

    return BlocProvider(
      create: (context) {
        final cubit = StoryViewerCubit(
          storyRepository: locator<StoryRepository>(),
          userRepository: locator<UserRepository>(),
          viewerId: currentUser.uid,
        );

        // Load stories from repository
        // Get all users with active stories (from friends)
        _loadStoriesForViewer(cubit, currentUser.uid, widget.startingUserId);

        return cubit;
      },
      child: BlocBuilder<StoryViewerCubit, StoryViewerState>(
        builder: (context, state) {
          if (state is StoryViewerLoading) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          if (state is StoryViewerError) {
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.white, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      state.error,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is StoryViewerLoaded) {
            final story = state.currentStory;
            if (story == null) {
              debugPrint('StoryViewerScreen: currentStory is null');
              return Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  leading: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'No story available',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'User: ${state.currentUser?.username ?? "Unknown"}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stories count: ${state.userStoriesMap[state.currentUser?.userId ?? ""]?.length ?? 0}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }

            debugPrint(
                'StoryViewerScreen: Building story view for story ${story.storyId}');
            return _buildStoryView(context, state, story);
          }

          // Default loading state
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        },
      ),
    );
  }

  Widget _buildStoryView(
    BuildContext context,
    StoryViewerLoaded state,
    StoryMedia story,
  ) {
    // Initialize video player if needed (only if story changed)
    if (story.mediaType == 'video' && _currentStoryId != story.storyId) {
      _initializeVideoController(story.storyId, story.mediaUrl);
    } else if (story.mediaType == 'image') {
      // Dispose video controller when switching to image
      if (_videoController != null) {
        _videoController?.dispose();
        _videoController = null;
        _currentStoryId = null;
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) => _handleTap(context, details, state),
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        onVerticalDragEnd: (details) =>
            _handleVerticalSwipe(context, details, state),
        onLongPressStart: (_) => _handleLongPressStart(context, state),
        onLongPressEnd: (_) => _handleLongPressEnd(context, state),
        child: Stack(
          children: [
            // Story media - fill screen
            Positioned.fill(
              child: story.mediaType == 'image'
                  ? CachedNetworkImage(
                      imageUrl: story.mediaUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.error, color: Colors.white, size: 64),
                      ),
                    )
                  : _videoController != null &&
                          _videoController!.value.isInitialized
                      ? SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _videoController!.value.size.width,
                              height: _videoController!.value.size.height,
                              child: VideoPlayer(_videoController!),
                            ),
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
            ),

            // Progress bars
            _buildProgressBars(state),

            // User header
            _buildUserHeader(state),

            // Text overlays
            if (story.textOverlays != null && story.textOverlays!.isNotEmpty)
              ..._buildTextOverlays(story.textOverlays!),

            // Drawing overlays
            if (story.drawings != null && story.drawings!.isNotEmpty)
              _buildDrawingOverlay(story.drawings!),

            // Sticker overlays
            if (story.stickerOverlays != null &&
                story.stickerOverlays!.isNotEmpty)
              ..._buildStickerOverlays(story.stickerOverlays!),

            // Footer (conditional: owner footer or reply bar)
            _buildFooter(context, state),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTextOverlays(List<TextOverlay> textOverlays) {
    if (!mounted) return [];

    final screenSize = MediaQuery.of(context).size;

    return textOverlays.map((overlay) {
      // Calculate position using normalized coordinates
      final x = overlay.x * screenSize.width;
      final y = overlay.y * screenSize.height;

      // Parse color from hex string
      Color textColor;
      try {
        textColor = Color(int.parse(overlay.color.replaceFirst('#', '0xFF')));
      } catch (e) {
        textColor = Colors.white; // Default to white if parsing fails
      }

      // Apply text style based on overlay.style
      TextStyle textStyle = TextStyle(
        color: textColor,
        fontSize: overlay.fontSize,
        fontWeight: FontWeight.bold,
      );

      // Apply outline effect if style is 'outline'
      if (overlay.style == 'outline') {
        textStyle = textStyle.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.black,
        );
      }

      // Apply neon effect if style is 'neon'
      if (overlay.style == 'neon') {
        textStyle = textStyle.copyWith(
          shadows: [
            Shadow(
              color: textColor,
              blurRadius: 10,
            ),
            Shadow(
              color: textColor,
              blurRadius: 20,
            ),
          ],
        );
      }

      return Positioned(
        left: x,
        top: y,
        child: Transform.rotate(
          angle: overlay.rotation * 3.14159 / 180, // Convert degrees to radians
          child: Text(
            overlay.text,
            style: textStyle,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildDrawingOverlay(List<DrawingPath> drawings) {
    return Positioned.fill(
      child: CustomPaint(
        painter: DrawingPainter(drawings),
        size: Size.infinite,
      ),
    );
  }

  List<Widget> _buildStickerOverlays(List<StickerOverlay> stickerOverlays) {
    if (!mounted) return [];

    final screenSize = MediaQuery.of(context).size;

    return stickerOverlays.map((sticker) {
      final position = Offset(
        sticker.x * screenSize.width,
        sticker.y * screenSize.height,
      );

      return Positioned(
        left: position.dx,
        top: position.dy,
        child: Transform.rotate(
          angle: sticker.rotation * 3.14159 / 180, // Convert to radians
          child: Transform.scale(
            scale: sticker.scale,
            child: Text(
              sticker.stickerId,
              style: const TextStyle(fontSize: 48),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildProgressBars(StoryViewerLoaded state) {
    final userId = state.currentUser?.userId;
    if (userId == null) return const SizedBox.shrink();

    final stories = state.userStoriesMap[userId] ?? [];
    if (stories.isEmpty) return const SizedBox.shrink();

    // CRITICAL: Check mounted before accessing MediaQuery
    if (!mounted) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      right: 8,
      child: Row(
        children: List.generate(stories.length, (index) {
          final story = stories[index];
          final progress = state.progressMap[story.storyId] ?? 0.0;
          final isActive = index == state.currentStoryIndex;

          return Expanded(
            child: Container(
              height: 3,
              margin:
                  EdgeInsets.only(right: index < stories.length - 1 ? 4 : 0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Stack(
                children: [
                  if (isActive)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.linear,
                      width: double.infinity,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: state.isPaused
                                ? Colors.orange
                                : Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildUserHeader(StoryViewerLoaded state) {
    final user = state.currentUser;
    if (user == null) return const SizedBox.shrink();

    // CRITICAL: Check mounted before accessing MediaQuery
    if (!mounted) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final safeAreaTop = MediaQuery.of(context).padding.top;

    return Positioned(
      top: safeAreaTop + 8,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundImage: (user.userAvatarUrl.isNotEmpty &&
                      (user.userAvatarUrl.startsWith('http://') ||
                          user.userAvatarUrl.startsWith('https://')))
                  ? CachedNetworkImageProvider(user.userAvatarUrl)
                  : null,
              child: (user.userAvatarUrl.isEmpty ||
                      !(user.userAvatarUrl.startsWith('http://') ||
                          user.userAvatarUrl.startsWith('https://')))
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            // Username and timestamp
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.username,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  if (state.currentStory?.createdAt != null)
                    Text(
                      _formatTime(state.currentStory!.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[300],
                      ),
                    ),
                ],
              ),
            ),
            // Spacer
            const Spacer(),
            // Options menu (three dots)
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () => _showStoryOptions(context, state),
            ),
            // Close button
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, StoryViewerLoaded state) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final story = state.currentStory;
    if (story == null || currentUser == null) {
      return const SizedBox.shrink();
    }

    final isOwner = story.authorId == currentUser.uid;

    // Show owner footer if viewing own story, otherwise show reply bar
    if (isOwner) {
      return _buildOwnerFooter(context, state);
    } else {
      return _buildReplyBar(context, state);
    }
  }

  Widget _buildOwnerFooter(BuildContext context, StoryViewerLoaded state) {
    final theme = Theme.of(context);
    final story = state.currentStory;
    if (story == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  ViewersListBottomSheet.show(context, story.storyId);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.remove_red_eye,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${story.viewerCount} Viewers',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyBar(BuildContext context, StoryViewerLoaded state) {
    final theme = Theme.of(context);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _showReplyBar ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: IgnorePointer(
          ignoring: !_showReplyBar,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            transform: Matrix4.translationValues(
              0,
              _showReplyBar ? 0 : 50,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
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
              child: SafeArea(
                child: Row(
                  children: [
                    // Text field
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        style: const TextStyle(color: Colors.white),
                        autofocus: _showReplyBar,
                        decoration: InputDecoration(
                          hintText: 'Send reply...',
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: theme.colorScheme.surface.withOpacity(0.8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            context
                                .read<StoryViewerCubit>()
                                .sendReply(value.trim(), 'text');
                            _replyController.clear();
                            if (mounted) {
                              setState(() => _showReplyBar = false);
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quick emoji reactions
                    _buildEmojiButton('❤️', context, state),
                    const SizedBox(width: 4),
                    _buildEmojiButton('😂', context, state),
                    const SizedBox(width: 4),
                    _buildEmojiButton('👍', context, state),
                    const SizedBox(width: 8),
                    // Send button
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () {
                        if (!mounted) return;
                        final content = _replyController.text.trim();
                        if (content.isNotEmpty) {
                          context
                              .read<StoryViewerCubit>()
                              .sendReply(content, 'text');
                          _replyController.clear();
                          if (mounted) {
                            setState(() => _showReplyBar = false);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiButton(
    String emoji,
    BuildContext context,
    StoryViewerLoaded state,
  ) {
    return GestureDetector(
      onTap: () {
        // Send emoji as reply directly
        context.read<StoryViewerCubit>().sendReply(emoji, 'emoji');
        if (mounted) {
          setState(() => _showReplyBar = false);
        }
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }

  void _handleTap(
    BuildContext context,
    TapDownDetails details,
    StoryViewerLoaded state,
  ) {
    // CRITICAL: Check mounted before accessing MediaQuery
    if (!mounted) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;

    // Left 1/3: Previous story
    if (tapX < screenWidth / 3) {
      context.read<StoryViewerCubit>().previousStory();
    }
    // Right 2/3: Next story
    else if (tapX >= screenWidth / 3) {
      context.read<StoryViewerCubit>().nextStory();
    }
    // Note: Center tap removed - use swipe up for reply bar instead
  }

  void _handleVerticalSwipe(
    BuildContext context,
    DragEndDetails details,
    StoryViewerLoaded state,
  ) {
    if (details.primaryVelocity == null) return;

    if (details.primaryVelocity! < -500) {
      // Swipe up - show reply bar
      if (mounted) {
        setState(() => _showReplyBar = true);
      }
    } else if (details.primaryVelocity! > 500) {
      // Swipe down - exit
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    // Check for swipe down gesture (delta.dy > 10)
    if (details.primaryDelta != null && details.primaryDelta! > 10) {
      // Could add visual feedback here if needed
    }
  }

  void _handleLongPressStart(BuildContext context, StoryViewerLoaded state) {
    // Pause story when long pressing
    context.read<StoryViewerCubit>().pauseStory();
    if (mounted) {
      setState(() {
        // Show pause indicator
      });
    }
  }

  void _handleLongPressEnd(BuildContext context, StoryViewerLoaded state) {
    // Resume story when releasing
    context.read<StoryViewerCubit>().resumeStory();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showStoryOptions(BuildContext context, StoryViewerLoaded state) {
    final story = state.currentStory;
    if (story == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final isOwner = story.authorId == currentUser.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
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
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Story',
                  style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmDeleteStory(context, state);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.report_outlined, color: Colors.white),
                title: const Text(
                  'Report Story',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  // TODO: Implement report functionality
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Report functionality coming soon')),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white),
              title: const Text(
                'Close',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteStory(BuildContext context, StoryViewerLoaded state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Story?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This story will be deleted permanently. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await context.read<StoryViewerCubit>().deleteCurrentStory();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Story deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting story: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for rendering drawing paths on stories
class DrawingPainter extends CustomPainter {
  final List<DrawingPath> drawings;

  DrawingPainter(this.drawings);

  @override
  void paint(Canvas canvas, Size size) {
    for (final drawingPath in drawings) {
      // Parse color from hex string
      Color pathColor;
      try {
        pathColor =
            Color(int.parse(drawingPath.color.replaceFirst('#', '0xFF')));
      } catch (e) {
        pathColor = Colors.white; // Default to white if parsing fails
      }

      final paint = Paint()
        ..color = pathColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = drawingPath.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Create path from points
      final path = ui.Path();
      if (drawingPath.points.isNotEmpty) {
        // Convert normalized coordinates (0-1) to screen coordinates
        final firstPoint = drawingPath.points.first;
        path.moveTo(firstPoint.x * size.width, firstPoint.y * size.height);

        for (int i = 1; i < drawingPath.points.length; i++) {
          final point = drawingPath.points[i];
          path.lineTo(point.x * size.width, point.y * size.height);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return oldDelegate.drawings != drawings;
  }
}
