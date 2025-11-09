// lib/screens/story_viewer_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:freegram/widgets/common/keyboard_safe_area.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/story_widgets/viewers_list_bottom_sheet.dart';
import 'package:freegram/widgets/story_widgets/viewer/story_user_header.dart';
import 'package:freegram/widgets/story_widgets/viewer/story_controls.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/services/media_prefetch_service.dart';
import 'package:freegram/services/network_quality_service.dart';
import 'package:freegram/services/cache_manager_service.dart';
import 'package:freegram/widgets/lqip_image.dart';
import 'dart:io';

class StoryViewerScreen extends StatefulWidget {
  final String startingUserId;

  const StoryViewerScreen({
    Key? key,
    required this.startingUserId,
  }) : super(key: key);

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  // Reply bar is now always visible
  String? _currentStoryId; // Track current story to prevent reinitialization
  DateTime? _pauseIndicatorHideTime;
  bool _isPrefetched = false; // Track if controller was prefetched
  late final MediaPrefetchService _prefetchService;
  late final NetworkQualityService _networkService;
  late final CacheManagerService _cacheService;
  
  // CRITICAL FIX: Mutex to prevent simultaneous video operations
  bool _isOperationInProgress = false;
  
  // CRITICAL FIX: Track pending callbacks to prevent accumulation (removed - no longer needed)
  // int _pendingCallbackId = 0;
  
  // CRITICAL FIX: Track initialization state to prevent duplicate calls
  String? _initializingStoryId;
  DateTime? _lastInitializationAttempt;
  static const Duration _initializationDebounceDelay = Duration(milliseconds: 500);
  
  // CRITICAL FIX: Track prefetch calls to prevent duplicates
  DateTime? _lastPrefetchTime;
  String? _lastHandledStoryId; // Track which story we've already handled
  bool? _lastPauseState; // Track last pause state to avoid unnecessary syncs
  
  // Animation controllers for polish improvements
  final Map<String, AnimationController> _emojiAnimations = {};
  AnimationController? _sendButtonAnimation;

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

  /// Initialize video with exponential backoff retry logic and cache-first strategy
  /// CRITICAL FIX: Cache-first strategy to prevent internet leaks
  Future<void> _initializeVideoWithRetry({
    required StoryMedia story,
    required NetworkQuality quality,
    required String videoUrl,
    int maxRetries = 3,
    int attempt = 1,
  }) async {
    // CRITICAL FIX: Prevent simultaneous operations
    if (_isOperationInProgress) {
      debugPrint('StoryViewerScreen: Operation in progress, skipping initialization');
      return;
    }
    
    _isOperationInProgress = true;
    
    try {
      // Add delay before retry (exponential backoff)
      if (attempt > 1) {
        final delayMs = (200 * (1 << (attempt - 2))).clamp(200, 2000); // 200ms, 400ms, 800ms
        debugPrint('StoryViewerScreen: Retrying video initialization (attempt $attempt/$maxRetries) after ${delayMs}ms delay');
        await Future.delayed(Duration(milliseconds: delayMs));
      }
      
      // Dispose previous controller if retrying
      if (_videoController != null && !_isPrefetched) {
        try {
          _videoController?.removeListener(_videoListener);
          _videoController?.pause();
          _videoController?.dispose();
        } catch (e) {
          debugPrint('StoryViewerScreen: Error disposing controller during retry: $e');
        }
        _videoController = null;
        // Small delay to ensure codec is released
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // CRITICAL FIX: Cache-first strategy - check cache before network
      VideoPlayerController? controller;
      File? cachedFile;
      
      try {
        // Step 1: Try to get cached file
        cachedFile = await _cacheService.videoManager.getSingleFile(videoUrl);
        
        // Step 2: Verify file exists and has valid size
        if (await cachedFile.exists()) {
          final fileSize = await cachedFile.length();
          if (fileSize > 1024) {
            // ✅ File is cached and valid - use it
            debugPrint('StoryViewerScreen: Using cached file for story ${story.storyId} (quality: $quality, size: $fileSize bytes)');
            controller = VideoPlayerController.file(cachedFile);
          } else {
            // File exists but is too small/invalid - delete and re-download
            debugPrint('StoryViewerScreen: Cached file is invalid (size: $fileSize bytes), deleting and re-downloading');
            try {
              await cachedFile.delete();
            } catch (e) {
              debugPrint('StoryViewerScreen: Error deleting invalid cache file: $e');
            }
            cachedFile = null;
          }
        }
      } catch (e) {
        debugPrint('StoryViewerScreen: Cache check failed: $e');
        cachedFile = null;
      }
      
      // Step 3: If no cached file, download to cache FIRST, then create controller from cached file
      if (controller == null) {
        try {
          // CRITICAL FIX: Download to cache FIRST, then use cached file
          debugPrint('StoryViewerScreen: Downloading story video to cache for ${story.storyId}');
          final fileInfo = await _cacheService.videoManager.downloadFile(videoUrl);
          cachedFile = fileInfo.file;
          
          // CRITICAL FIX: Enhanced verification - verify downloaded file exists and has valid size
          if (await cachedFile.exists()) {
            final fileSize = await cachedFile.length();
            if (fileSize > 1024) {
              // ✅ File downloaded and cached - use it
              debugPrint('StoryViewerScreen: Story video downloaded and cached (size: $fileSize bytes)');
              controller = VideoPlayerController.file(cachedFile);
            } else {
              throw Exception('Downloaded file is invalid (size: $fileSize bytes)');
            }
          } else {
            throw Exception('Downloaded file does not exist');
          }
        } catch (e) {
          debugPrint('StoryViewerScreen: Cache download failed: $e, falling back to network');
          // Fallback to network only if cache download fails
          controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        }
      }
      
      _videoController = controller;
      _videoController!.addListener(_videoListener);
      _isPrefetched = false;
      
      await _videoController!.initialize();
      
      // Success! Set up the controller
      if (mounted) {
        setState(() {
          _currentStoryId = story.storyId;
        });
        _videoController?.play();
        
        // Start progress now that video is ready
        context.read<StoryViewerCubit>().startStoryProgress();
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      final isMemoryError = errorStr.contains('no_memory') || 
                           errorStr.contains('memory') ||
                           errorStr.contains('codec');
      
      debugPrint('StoryViewerScreen: Video initialization attempt $attempt failed: $e');
      
      // Clean up failed controller
      if (_videoController != null && !_isPrefetched) {
        try {
          _videoController?.removeListener(_videoListener);
          _videoController?.dispose();
        } catch (_) {}
        _videoController = null;
      }
      
      // If memory error and we can downgrade quality, try lower quality
      if (isMemoryError && attempt == 1 && quality != NetworkQuality.poor) {
        final lowerQuality = _getLowerQuality(quality);
        debugPrint('StoryViewerScreen: Memory error detected, falling back to lower quality: $lowerQuality');
        final lowerQualityUrl = story.getVideoUrlForQuality(lowerQuality);
        _isOperationInProgress = false; // Release lock before recursive call
        return _initializeVideoWithRetry(
          story: story,
          quality: lowerQuality,
          videoUrl: lowerQualityUrl,
          maxRetries: maxRetries,
          attempt: 1, // Reset attempt for quality change
        );
      }
      
      // Retry if we have attempts left
      if (attempt < maxRetries) {
        _isOperationInProgress = false; // Release lock before retry
        return _initializeVideoWithRetry(
          story: story,
          quality: quality,
          videoUrl: videoUrl,
          maxRetries: maxRetries,
          attempt: attempt + 1,
        );
      }
      
      // All retries failed
      debugPrint('StoryViewerScreen: All retry attempts failed for video initialization');
      _isOperationInProgress = false;
      rethrow;
    } finally {
      _isOperationInProgress = false;
    }
  }
  
  /// Get a lower quality for fallback when memory errors occur
  NetworkQuality _getLowerQuality(NetworkQuality current) {
    switch (current) {
      case NetworkQuality.excellent:
        return NetworkQuality.good;
      case NetworkQuality.good:
        return NetworkQuality.fair;
      case NetworkQuality.fair:
        return NetworkQuality.poor;
      case NetworkQuality.poor:
      case NetworkQuality.offline:
        return NetworkQuality.poor;
    }
  }

  Future<void> _initializeVideoController(StoryMedia story) async {
    final storyId = story.storyId;
    
    // CRITICAL FIX: If already initialized for this story, don't reinitialize
    if (_currentStoryId == storyId && _videoController != null && _videoController!.value.isInitialized) {
      debugPrint('StoryViewerScreen: Already initialized for story $storyId, skipping');
      return;
    }

    // CRITICAL FIX: Prevent duplicate initialization attempts
    if (_initializingStoryId == storyId) {
      debugPrint('StoryViewerScreen: Already initializing story $storyId, skipping duplicate call');
      return;
    }

    // CRITICAL FIX: Debounce rapid initialization calls
    final now = DateTime.now();
    if (_lastInitializationAttempt != null && 
        storyId == _initializingStoryId &&
        now.difference(_lastInitializationAttempt!) < _initializationDebounceDelay) {
      debugPrint('StoryViewerScreen: Debouncing initialization for story $storyId');
      return;
    }

    // CRITICAL FIX: Wait for any in-progress operations to complete (with timeout)
    if (_isOperationInProgress) {
      debugPrint('StoryViewerScreen: Waiting for operation to complete before initialization');
      int waitCount = 0;
      while (_isOperationInProgress && waitCount < 20) { // Increased timeout
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      if (_isOperationInProgress) {
        debugPrint('StoryViewerScreen: Force unlocking operation for initialization (timeout)');
        _isOperationInProgress = false;
      }
    }

    // Mark as initializing
    _initializingStoryId = storyId;
    _lastInitializationAttempt = now;

    debugPrint('StoryViewerScreen: Initializing video controller for story $storyId');

    try {
      // CRITICAL FIX: Dispose old controller with proper cleanup
      if (_currentStoryId != storyId || _videoController == null || !_videoController!.value.isInitialized) {
        await _disposeVideoController();
        _videoController = null;
        _isPrefetched = false;
        _currentStoryId = null;
      }

      // Try to get a prefetched controller first
      VideoPlayerController? prefetchedController =
          _prefetchService.getPrefetchedStoryController(storyId);

      if (prefetchedController != null && prefetchedController.value.isInitialized) {
        // Use prefetched controller - instant loading!
        debugPrint('StoryViewerScreen: Using prefetched controller for story $storyId');
        
        // Dispose old controller if exists
        if (_videoController != null && _videoController != prefetchedController) {
          await _disposeVideoController();
        }
        
        _videoController = prefetchedController;
        _isPrefetched = true;
        _currentStoryId = storyId;

        // Add listener if not already added
        if (!_videoController!.value.hasError) {
          _videoController!.addListener(_videoListener);
          if (mounted) {
            setState(() {
              _currentStoryId = storyId;
            });
            _videoController?.play();
            
            // Start progress now that prefetched video is ready
            context.read<StoryViewerCubit>().startStoryProgress();
          }
        }
      } else {
        // No prefetched controller available - create one with ABR and retry logic
        final NetworkQuality currentQuality = _networkService.currentQuality;
        final String videoUrl = story.getVideoUrlForQuality(currentQuality);

        debugPrint('StoryViewerScreen: Creating new controller for story $storyId with quality: $currentQuality, URL: $videoUrl');

        // Use retry logic for initialization
        await _initializeVideoWithRetry(
          story: story,
          quality: currentQuality,
          videoUrl: videoUrl,
          maxRetries: 3,
          attempt: 1,
        );
      }
    } catch (e) {
      debugPrint('StoryViewerScreen: Error initializing video: $e');
      // Dispose controller on error (only if not prefetched)
      if (_videoController != null && !_isPrefetched) {
        try {
          await _disposeVideoController();
        } catch (_) {}
        _videoController = null;
      }
      _currentStoryId = null;
      rethrow;
    } finally {
      // CRITICAL FIX: Always clear initializing flag
      if (_initializingStoryId == storyId) {
        _initializingStoryId = null;
      }
    }
  }

  /// CRITICAL FIX: Safe listener that doesn't trigger unnecessary rebuilds
  /// Video listener is called very frequently (every frame/position update)
  /// We should NOT call setState here to avoid infinite build loops
  void _videoListener() {
    // CRITICAL FIX: Do NOT call setState in video listener
    // This listener is called very frequently and causes build loops
    // Only handle critical state changes (like errors) that require UI updates
    if (_videoController == null || !mounted) return;
    
    try {
      // Only handle errors that require UI updates
      if (_videoController!.value.hasError) {
        debugPrint('StoryViewerScreen: Video controller error: ${_videoController!.value.errorDescription}');
        // Error handling can be done without setState if needed
      }
      // CRITICAL: Do NOT call setState here - it causes infinite rebuilds
      // Progress updates are handled by VideoPlayer widget itself
    } catch (e) {
      debugPrint('StoryViewerScreen: Error in video listener: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // Listen to text changes to update send button state
    _replyController.addListener(() {
      if (mounted) {
        setState(() {}); // Rebuild to update send button state
      }
    });
    debugPrint('📱 SCREEN: story_viewer_screen.dart');
    // Enable immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Initialize prefetch, network, and cache services using GetIt
    _prefetchService = locator<MediaPrefetchService>();
    _networkService = locator<NetworkQualityService>();
    _cacheService = locator<CacheManagerService>();
  }

  /// CRITICAL FIX: Sync video playback state without triggering rebuilds
  void _syncVideoPlaybackState(bool shouldBePaused) {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    if (!mounted) return;
    
    try {
      final isCurrentlyPlaying = _videoController!.value.isPlaying;
      
      if (shouldBePaused && isCurrentlyPlaying) {
        _videoController?.pause();
      } else if (!shouldBePaused && !isCurrentlyPlaying && !_videoController!.value.hasError) {
        _videoController?.play();
      }
    } catch (e) {
      debugPrint('StoryViewerScreen: Error syncing video playback state: $e');
    }
  }

  /// CRITICAL FIX: Properly dispose video controller with cleanup
  Future<void> _disposeVideoController() async {
    if (_videoController != null) {
      try {
        _videoController!.removeListener(_videoListener);
        _videoController!.pause();
        
        // Only dispose if we created it (not prefetched)
        if (!_isPrefetched) {
          final controller = _videoController;
          _videoController = null;
          controller?.dispose();
          
          // CRITICAL FIX: Add delay to allow codec resources to be released
          await Future.delayed(const Duration(milliseconds: 150));
        } else {
          // If prefetched, service manages it - just nullify our reference
          _videoController = null;
        }
      } catch (e) {
        debugPrint('StoryViewerScreen: Error disposing video controller: $e');
        _videoController = null;
      }
    }
  }

  @override
  void dispose() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Dispose video controller (synchronous for dispose)
    if (_videoController != null) {
      try {
        _videoController!.removeListener(_videoListener);
        _videoController!.pause();
        if (!_isPrefetched) {
          final controller = _videoController;
          _videoController = null;
          controller?.dispose();
        } else {
          _videoController = null;
        }
      } catch (e) {
        debugPrint('StoryViewerScreen: Error in dispose: $e');
        _videoController = null;
      }
    }
    // Dispose animation controllers
    for (final controller in _emojiAnimations.values) {
      controller.dispose();
    }
    _emojiAnimations.clear();
    _sendButtonAnimation?.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
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
      child: BlocListener<StoryViewerCubit, StoryViewerState>(
        listener: (context, state) {
          // CRITICAL FIX: Auto-close when no more stories exist
          if (state is StoryViewerLoaded) {
            // Check if there are no users with stories left
            if (state.usersWithStories.isEmpty) {
              // Close the viewer
              Future.microtask(() {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              });
              return;
            }
            
            // CRITICAL FIX: Sync pause/play state only when it changes, not on every build
            final newPauseState = state.isPaused;
            if (_lastPauseState != newPauseState) {
              _lastPauseState = newPauseState;
              _syncVideoPlaybackState(newPauseState);
            }
          }
        },
        child: BlocBuilder<StoryViewerCubit, StoryViewerState>(
          builder: (context, state) {
          if (state is StoryViewerLoading) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: const AppProgressIndicator(color: Colors.white),
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
            // CRITICAL FIX: Check if there are no users with stories
            if (state.usersWithStories.isEmpty) {
              // Auto-close will be handled by listener, but show a loading state
              return const Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: AppProgressIndicator(color: Colors.white),
                ),
              );
            }
            
            final story = state.currentStory;
            if (story == null) {
              debugPrint('StoryViewerScreen: currentStory is null, users: ${state.usersWithStories.length}');
              // Auto-close is handled by listener if usersWithStories is empty
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

            // CRITICAL FIX: Remove debug print that spams logs during build loops
            // Only log when story actually changes to reduce log spam
            if (_lastHandledStoryId != story.storyId) {
              debugPrint('StoryViewerScreen: Building story view for story ${story.storyId}');
            }
            return _buildStoryView(context, state, story);
          }

          // Default loading state
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: AppProgressIndicator(color: Colors.white)),
          );
        },
        ),
      ),
    );
  }

  Widget _buildStoryView(
    BuildContext context,
    StoryViewerLoaded state,
    StoryMedia story,
  ) {
    // CRITICAL FIX: Only handle story change once, prevent infinite loops
    final storyId = story.storyId;
    final storyChanged = _lastHandledStoryId != storyId;
    
    if (storyChanged) {
      _lastHandledStoryId = storyId;
      
      // CRITICAL FIX: Use WidgetsBinding to schedule initialization AFTER build
      // This prevents build loop issues and ensures it only runs once per story
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _lastHandledStoryId != storyId) return;
        
        // Get current user's stories for prefetching
        final currentUserId = state.currentUser?.userId;
        final currentUserStories = currentUserId != null
            ? state.userStoriesMap[currentUserId] ?? []
            : <StoryMedia>[];

        // Initialize video player if needed (only if story changed)
        if (story.mediaType == 'video') {
          if (_currentStoryId != storyId || 
              _videoController == null || 
              !_videoController!.value.isInitialized) {
            _initializeVideoController(story);
          }
          
          // CRITICAL FIX: Debounce prefetching to prevent duplicate calls
          final now = DateTime.now();
          if (_lastPrefetchTime == null || 
              now.difference(_lastPrefetchTime!) > const Duration(seconds: 2)) {
            _lastPrefetchTime = now;
            
            // Trigger prefetching for next stories (only once per story)
            if (currentUserStories.isNotEmpty) {
              final currentIndex = currentUserStories
                  .indexWhere((s) => s.storyId == storyId);
              if (currentIndex >= 0) {
                // Prefetch next 3-5 story videos (increased per plan requirements)
                _prefetchService.prefetchStoryVideos(currentUserStories, currentIndex);
                // Prefetch next 3-5 story images (increased per plan requirements)
                _prefetchService.prefetchStoryImages(currentUserStories, currentIndex);
              }
            }
          }
        } else if (story.mediaType == 'image') {
          // CRITICAL FIX: Dispose video controller when switching to image
          if (_videoController != null) {
            _disposeVideoController();
            _currentStoryId = null;
            _isPrefetched = false;
          }
          
          // For images, progress is already started in cubit via _startAutoAdvance
          // (with startProgressImmediately: true for images)
          // No need to call startStoryProgress() again
          
          // CRITICAL FIX: Debounce prefetching to prevent duplicate calls
          final now = DateTime.now();
          if (_lastPrefetchTime == null || 
              now.difference(_lastPrefetchTime!) > const Duration(seconds: 2)) {
            _lastPrefetchTime = now;
            
            // Trigger prefetching for next stories (only once per story)
            if (currentUserStories.isNotEmpty) {
              final currentIndex = currentUserStories
                  .indexWhere((s) => s.storyId == storyId);
              if (currentIndex >= 0) {
                // Prefetch next 2-3 story images
                _prefetchService.prefetchStoryImages(currentUserStories, currentIndex);
                // Prefetch next 2-3 story videos
                _prefetchService.prefetchStoryVideos(currentUserStories, currentIndex);
              }
            }
          }
        }
      });
    }

    // CRITICAL FIX: Sync video controller with pause state (only when needed)
    // Use a callback to avoid calling during build, which can cause rebuild loops
    if (story.mediaType == 'video' && _videoController != null && _videoController!.value.isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _videoController == null) return;
        
        // Only sync if state actually changed
        final shouldBePaused = state.isPaused;
        final isCurrentlyPlaying = _videoController!.value.isPlaying;
        
        if (shouldBePaused && isCurrentlyPlaying) {
          _videoController?.pause();
        } else if (!shouldBePaused && !isCurrentlyPlaying && !_videoController!.value.hasError) {
          _videoController?.play();
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: StoryControls(
        currentStory: story,
        isPaused: state.isPaused,
        onNextStory: () => context.read<StoryViewerCubit>().nextStory(),
        onPreviousStory: () => context.read<StoryViewerCubit>().previousStory(),
        onNextUser: () => context.read<StoryViewerCubit>().nextUser(),
        onPreviousUser: () => context.read<StoryViewerCubit>().previousUser(),
        onTogglePause: () => _togglePlayPause(context, state),
        onClose: () => Navigator.of(context).pop(),
        onShowReplyBar: () {
          // Reply bar is always visible, focus on text field
          _replyFocusNode.requestFocus();
        },
        child: Stack(
          children: [
            // Story media - fill screen with smooth transitions
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: story.mediaType == 'image'
                    ? Hero(
                        key: ValueKey('story-image-${story.storyId}'),
                        tag: 'story-${story.storyId}',
                        child: LQIPImage(
                          imageUrl: story.mediaUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : _videoController != null &&
                            _videoController!.value.isInitialized
                        ? Hero(
                            key: ValueKey('story-video-${story.storyId}'),
                            tag: 'story-${story.storyId}',
                            child: RepaintBoundary(
                              // CRITICAL FIX: Wrap in RepaintBoundary to isolate rendering
                              child: SizedBox.expand(
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _videoController!.value.size.width,
                                    height: _videoController!.value.size.height,
                                    child: VideoPlayer(_videoController!),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const Center(
                            child: AppProgressIndicator(color: Colors.white),
                          ),
              ),
            ),

            // User header (includes progress segments)
            StoryUserHeader(
              user: state.currentUser,
              timestamp: story.createdAt,
              onOptionsPressed: () => _showStoryOptions(context, state),
              onClosePressed: () => Navigator.of(context).pop(),
              stories: state.userStoriesMap[state.currentUser?.userId ?? ''] ?? [],
              currentStoryIndex: state.currentStoryIndex,
              progressMap: state.progressMap,
              isPaused: state.isPaused,
            ),

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

            // Play/pause indicator overlay (for video stories)
            if (story.mediaType == 'video')
              _buildPlayPauseIndicator(state),

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


  Widget _buildFooter(BuildContext context, StoryViewerLoaded state) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final story = state.currentStory;
    if (story == null || currentUser == null) {
      return const SizedBox.shrink();
    }

    final isOwner = story.authorId == currentUser.uid;

    // Reply bar is always visible
    // If owner, show viewers count above the reply bar
    if (isOwner) {
      return Stack(
        children: [
          // Reply bar (always at bottom)
          _buildReplyBar(context, state),
          // Viewers count (above reply bar)
          _buildViewersCount(context, state, story),
        ],
      );
    } else {
      // Non-owner: Just show reply bar
      return _buildReplyBar(context, state);
    }
  }

  Widget _buildViewersCount(BuildContext context, StoryViewerLoaded state, StoryMedia story) {
    final theme = Theme.of(context);
    final reactionCount = story.reactionCount;
    final viewerCount = story.viewerCount;

    return Positioned(
      bottom: 80, // Above reply bar
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () {
            ViewersListBottomSheet.show(context, story.storyId);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMD,
              vertical: DesignTokens.spaceSM,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Heart icon for reactions
                if (reactionCount > 0) ...[
                  const Icon(
                    Icons.favorite,
                    color: Colors.green,
                    size: DesignTokens.iconSM,
                  ),
                  const SizedBox(width: DesignTokens.spaceXS),
                  Text(
                    '$reactionCount',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSM),
                ],
                // Viewers icon and count
                const Icon(
                  Icons.remove_red_eye,
                  color: Colors.white,
                  size: DesignTokens.iconSM,
                ),
                const SizedBox(width: DesignTokens.spaceXS),
                Text(
                  '$viewerCount',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyBar(BuildContext context, StoryViewerLoaded state) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: RepaintBoundary(
        child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMD,
          vertical: DesignTokens.spaceSM,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: const [0.0, 0.5, 1.0],
            colors: [
              Colors.black.withOpacity(0.95),
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: KeyboardAwareInput(
          child: SafeArea(
            child: Row(
              children: [
                // Text field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _replyController,
                      focusNode: _replyFocusNode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: DesignTokens.fontSizeMD,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Send message...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: DesignTokens.fontSizeMD,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spaceMD,
                          vertical: DesignTokens.spaceSM,
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          context
                              .read<StoryViewerCubit>()
                              .sendReply(value.trim(), 'text');
                          _replyController.clear();
                          _replyFocusNode.unfocus();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                // Green heart reaction button
                _buildHeartReactionButton(context, state),
                const SizedBox(width: DesignTokens.spaceSM),
                // Send button with animation
                _buildSendButton(context, state),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHeartReactionButton(BuildContext context, StoryViewerLoaded state) {
    // Get or create animation controller for heart
    const emoji = '❤️';
    if (!_emojiAnimations.containsKey(emoji)) {
      _emojiAnimations[emoji] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
    }

    final controller = _emojiAnimations[emoji]!;
    final scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.elasticOut,
      ),
    );

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
        },
        onTapUp: (_) {
          // Bounce animation on tap
          controller.forward().then((_) {
            controller.reverse();
          });
          // Send heart reaction
          context.read<StoryViewerCubit>().sendReply(emoji, 'emoji');
        },
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Transform.scale(
              scale: scaleAnimation.value,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2 + (controller.value * 0.15)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.green.withOpacity(0.5 + (controller.value * 0.3)),
                    width: 2,
                  ),
                  boxShadow: controller.value > 0
                      ? [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.5 * controller.value),
                            blurRadius: 12 * controller.value,
                            spreadRadius: 3 * controller.value,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }


  Widget _buildSendButton(BuildContext context, StoryViewerLoaded state) {
    // Initialize send button animation controller
    _sendButtonAnimation ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    final controller = _sendButtonAnimation!;
    final scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ),
    );
    final rotationAnimation = Tween<double>(begin: 0.0, end: 0.2).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ),
    );

    final hasText = _replyController.text.trim().isNotEmpty;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.scale(
          scale: scaleAnimation.value,
          child: Transform.rotate(
            angle: rotationAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: hasText
                    ? SonarPulseTheme.primaryAccent
                    : SonarPulseTheme.primaryAccent.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                boxShadow: controller.value > 0
                    ? [
                        BoxShadow(
                          color: SonarPulseTheme.primaryAccent
                              .withValues(alpha: 0.5 * (1 - controller.value)),
                          blurRadius: 12 * (1 - controller.value),
                          spreadRadius: 2 * (1 - controller.value),
                        ),
                      ]
                    : null,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: DesignTokens.iconMD,
                ),
                onPressed: hasText
                    ? () {
                        if (!mounted) return;
                        HapticFeedback.mediumImpact();
                        controller.forward().then((_) {
                          controller.reverse();
                        });
                        final content = _replyController.text.trim();
                        if (content.isNotEmpty) {
                          context
                              .read<StoryViewerCubit>()
                              .sendReply(content, 'text');
                          _replyController.clear();
                          _replyFocusNode.unfocus();
                        }
                      }
                    : null,
                padding: const EdgeInsets.all(DesignTokens.spaceSM),
                constraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _togglePlayPause(BuildContext context, StoryViewerLoaded state) {
    final cubit = context.read<StoryViewerCubit>();
    HapticFeedback.mediumImpact();

    if (state.isPaused) {
      cubit.resumeStory();
      // Resume video playback
      if (_videoController != null && _videoController!.value.isInitialized) {
        _videoController?.play();
      }
      // Hide indicator immediately when resuming
      if (mounted) {
        setState(() {
          _pauseIndicatorHideTime = null;
        });
      }
    } else {
      cubit.pauseStory();
      // Pause video playback
      if (_videoController != null && _videoController!.value.isInitialized) {
        _videoController?.pause();
      }
      // Show indicator and schedule auto-hide after 3 seconds
      if (mounted) {
        setState(() {
          _pauseIndicatorHideTime = DateTime.now();
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _pauseIndicatorHideTime != null) {
            final now = DateTime.now();
            // Only hide if it's been 3 seconds since we showed it
            if (now.difference(_pauseIndicatorHideTime!) >= const Duration(seconds: 3)) {
              setState(() {
                _pauseIndicatorHideTime = null;
              });
            }
          }
        });
      }
    }
  }


  Widget _buildPlayPauseIndicator(StoryViewerLoaded state) {
    // Show indicator if paused and hide time hasn't passed
    final shouldShow = state.isPaused && 
        (_pauseIndicatorHideTime == null || 
         DateTime.now().difference(_pauseIndicatorHideTime!) < const Duration(seconds: 3));
    
    return AnimatedOpacity(
      opacity: shouldShow ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.pause,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ),
    );
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
