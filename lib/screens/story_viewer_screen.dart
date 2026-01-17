// lib/screens/story_viewer_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:freegram/blocs/story_viewer_cubit.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/story_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/models/story_media_model.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/story_widgets/viewer/story_user_header.dart';
import 'package:freegram/widgets/story_widgets/viewer/story_controls.dart';
import 'package:freegram/widgets/story_widgets/viewer/story_overlays_widget.dart';
import 'package:freegram/widgets/story_widgets/viewer/story_reply_bar_widget.dart';
import 'package:freegram/widgets/story_widgets/viewer/story_viewers_count_widget.dart';
import 'package:freegram/widgets/story_widgets/viewer/story_play_pause_indicator_widget.dart';
import 'package:freegram/widgets/story_widgets/viewer/story_video_display_widget.dart';
import 'package:freegram/widgets/story_widgets/viewer/story_error_widget.dart';
import 'package:freegram/widgets/story_widgets/viewer/story_options_dialog.dart';
import 'package:freegram/theme/design_tokens.dart';
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

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  VideoPlayerController? _videoController;
  String? _currentStoryId; // Track current story to prevent reinitialization
  DateTime? _pauseIndicatorHideTime;
  bool _isPrefetched = false; // Track if controller was prefetched
  late final MediaPrefetchService _prefetchService;
  late final NetworkQualityService _networkService;
  late final CacheManagerService _cacheService;

  // CRITICAL FIX: Mutex to prevent simultaneous video operations
  bool _isOperationInProgress = false;

  // CRITICAL FIX: Track initialization state to prevent duplicate calls
  String? _initializingStoryId;
  DateTime? _lastInitializationAttempt;
  static const Duration _initializationDebounceDelay =
      Duration(milliseconds: 500);

  // CRITICAL FIX: Track prefetch calls to prevent duplicates
  DateTime? _lastPrefetchTime;
  String? _lastHandledStoryId; // Track which story we've already handled
  bool? _lastPauseState; // Track last pause state to avoid unnecessary syncs

  // CRITICAL FIX: Store cubit reference to avoid context access issues in async callbacks
  StoryViewerCubit? _cubit;

  Future<void> _loadStoriesForViewer(
    StoryViewerCubit cubit,
    String viewerId,
    String startingUserId,
  ) async {
    try {
      debugPrint(
          'StoryViewerScreen: Loading stories for viewer $viewerId, starting user $startingUserId');

      // CRITICAL FIX: Always include both the starting user AND the current user (viewer)
      // This ensures you can navigate back to your own story even when opening another user's story
      final userIds = <String>[];
      final processedUserIds =
          <String>{}; // Track processed IDs to prevent duplicates

      // Always add starting user first (the story being opened)
      if (!processedUserIds.contains(startingUserId)) {
        userIds.add(startingUserId);
        processedUserIds.add(startingUserId);
      }

      // Always add current user (viewer) if different from starting user
      // This allows navigation back to your own story
      if (viewerId != startingUserId && !processedUserIds.contains(viewerId)) {
        userIds.add(viewerId);
        processedUserIds.add(viewerId);
      }

      // Get user's friends list from repository
      try {
        final userRepository = locator<UserRepository>();
        final user = await userRepository.getUser(viewerId);
        final friends = user.friends;

        // Add friends who are not already in the list
        for (final friendId in friends) {
          if (!processedUserIds.contains(friendId)) {
            userIds.add(friendId);
            processedUserIds.add(friendId);
          }
        }
      } catch (e) {
        debugPrint('StoryViewerScreen: Error getting friends list: $e');
        // Continue with starting user and viewer
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
      debugPrint(
          'StoryViewerScreen: Operation in progress, skipping initialization');
      return;
    }

    _isOperationInProgress = true;

    try {
      // Add delay before retry (exponential backoff)
      if (attempt > 1) {
        final delayMs = (200 * (1 << (attempt - 2)))
            .clamp(200, 2000); // 200ms, 400ms, 800ms
        debugPrint(
            'StoryViewerScreen: Retrying video initialization (attempt $attempt/$maxRetries) after ${delayMs}ms delay');
        await Future.delayed(Duration(milliseconds: delayMs));
      }

      // Dispose previous controller if retrying
      if (_videoController != null && !_isPrefetched) {
        try {
          _videoController?.pause();
          _videoController?.dispose();
        } catch (e) {
          debugPrint(
              'StoryViewerScreen: Error disposing controller during retry: $e');
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
            debugPrint(
                'StoryViewerScreen: Using cached file for story ${story.storyId} (quality: $quality, size: $fileSize bytes)');
            controller = VideoPlayerController.file(cachedFile);
          } else {
            // File exists but is too small/invalid - delete and re-download
            debugPrint(
                'StoryViewerScreen: Cached file is invalid (size: $fileSize bytes), deleting and re-downloading');
            try {
              await cachedFile.delete();
            } catch (e) {
              debugPrint(
                  'StoryViewerScreen: Error deleting invalid cache file: $e');
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
          debugPrint(
              'StoryViewerScreen: Downloading story video to cache for ${story.storyId}');
          final fileInfo =
              await _cacheService.videoManager.downloadFile(videoUrl);
          cachedFile = fileInfo.file;

          // CRITICAL FIX: Enhanced verification - verify downloaded file exists and has valid size
          if (await cachedFile.exists()) {
            final fileSize = await cachedFile.length();
            if (fileSize > 1024) {
              // ✅ File downloaded and cached - use it
              debugPrint(
                  'StoryViewerScreen: Story video downloaded and cached (size: $fileSize bytes)');
              controller = VideoPlayerController.file(cachedFile);
            } else {
              throw Exception(
                  'Downloaded file is invalid (size: $fileSize bytes)');
            }
          } else {
            throw Exception('Downloaded file does not exist');
          }
        } catch (e) {
          debugPrint(
              'StoryViewerScreen: Cache download failed: $e, falling back to network');
          // Fallback to network only if cache download fails
          controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        }
      }

      _videoController = controller;
      _isPrefetched = false;

      await _videoController!.initialize();

      // Success! Set up the controller
      if (mounted) {
        setState(() {
          _currentStoryId = story.storyId;
        });
        _videoController?.play();

        // Start progress now that video is ready
        // CRITICAL FIX: Use stored cubit reference instead of context to avoid provider errors
        _cubit?.startStoryProgress();
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      final isMemoryError = errorStr.contains('no_memory') ||
          errorStr.contains('memory') ||
          errorStr.contains('codec');

      debugPrint(
          'StoryViewerScreen: Video initialization attempt $attempt failed: $e');

      // Clean up failed controller
      if (_videoController != null && !_isPrefetched) {
        try {
          _videoController?.dispose();
        } catch (_) {}
        _videoController = null;
      }

      // If memory error and we can downgrade quality, try lower quality
      if (isMemoryError && attempt == 1 && quality != NetworkQuality.poor) {
        final lowerQuality = _getLowerQuality(quality);
        debugPrint(
            'StoryViewerScreen: Memory error detected, falling back to lower quality: $lowerQuality');
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
      debugPrint(
          'StoryViewerScreen: All retry attempts failed for video initialization');
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
    if (_currentStoryId == storyId &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      debugPrint(
          'StoryViewerScreen: Already initialized for story $storyId, skipping');
      return;
    }

    // CRITICAL FIX: Prevent duplicate initialization attempts
    if (_initializingStoryId == storyId) {
      debugPrint(
          'StoryViewerScreen: Already initializing story $storyId, skipping duplicate call');
      return;
    }

    // CRITICAL FIX: Debounce rapid initialization calls
    final now = DateTime.now();
    if (_lastInitializationAttempt != null &&
        storyId == _initializingStoryId &&
        now.difference(_lastInitializationAttempt!) <
            _initializationDebounceDelay) {
      debugPrint(
          'StoryViewerScreen: Debouncing initialization for story $storyId');
      return;
    }

    // CRITICAL FIX: Wait for any in-progress operations to complete (with timeout)
    if (_isOperationInProgress) {
      debugPrint(
          'StoryViewerScreen: Waiting for operation to complete before initialization');
      int waitCount = 0;
      while (_isOperationInProgress && waitCount < 20) {
        // Increased timeout
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      if (_isOperationInProgress) {
        debugPrint(
            'StoryViewerScreen: Force unlocking operation for initialization (timeout)');
        _isOperationInProgress = false;
      }
    }

    // Mark as initializing
    _initializingStoryId = storyId;
    _lastInitializationAttempt = now;

    debugPrint(
        'StoryViewerScreen: Initializing video controller for story $storyId');

    try {
      // CRITICAL FIX: Dispose old controller with proper cleanup
      if (_currentStoryId != storyId ||
          _videoController == null ||
          !_videoController!.value.isInitialized) {
        await _disposeVideoController();
        _videoController = null;
        _isPrefetched = false;
        _currentStoryId = null;
      }

      // Try to get a prefetched controller first
      VideoPlayerController? prefetchedController =
          _prefetchService.getPrefetchedStoryController(storyId);

      if (prefetchedController != null &&
          prefetchedController.value.isInitialized) {
        // Use prefetched controller - instant loading!
        debugPrint(
            'StoryViewerScreen: Using prefetched controller for story $storyId');

        // Dispose old controller if exists
        if (_videoController != null &&
            _videoController != prefetchedController) {
          await _disposeVideoController();
        }

        _videoController = prefetchedController;
        _isPrefetched = true;
        _currentStoryId = storyId;

        // Use prefetched controller
        if (!_videoController!.value.hasError) {
          if (mounted) {
            setState(() {
              _currentStoryId = storyId;
            });
            _videoController?.play();

            // Start progress now that prefetched video is ready
            // CRITICAL FIX: Use stored cubit reference instead of context to avoid provider errors
            _cubit?.startStoryProgress();
          }
        }
      } else {
        // No prefetched controller available - create one with ABR and retry logic
        final NetworkQuality currentQuality = _networkService.currentQuality;
        final String videoUrl = story.getVideoUrlForQuality(currentQuality);

        debugPrint(
            'StoryViewerScreen: Creating new controller for story $storyId with quality: $currentQuality, URL: $videoUrl');

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

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: story_viewer_screen.dart');
    // Enable immersive mode for story viewer
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    // Initialize prefetch, network, and cache services using GetIt
    _prefetchService = locator<MediaPrefetchService>();
    _networkService = locator<NetworkQualityService>();
    _cacheService = locator<CacheManagerService>();
  }

  /// CRITICAL FIX: Sync video playback state without triggering rebuilds
  void _syncVideoPlaybackState(bool shouldBePaused) {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }
    if (!mounted) return;

    try {
      final isCurrentlyPlaying = _videoController!.value.isPlaying;

      if (shouldBePaused && isCurrentlyPlaying) {
        _videoController?.pause();
      } else if (!shouldBePaused &&
          !isCurrentlyPlaying &&
          !_videoController!.value.hasError) {
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
    // Don't change system UI mode here - let the parent screen manage it
    // Changing it in dispose causes issues with the app bar after closing
    // The main app already sets immersive sticky mode in main.dart
    // Dispose video controller (synchronous for dispose)
    if (_videoController != null) {
      try {
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
    // CRITICAL FIX: Clear cubit reference on dispose
    _cubit = null;
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

        // CRITICAL FIX: Store cubit reference for use in async callbacks
        _cubit = cubit;

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
              final theme = Theme.of(context);
              return Scaffold(
                backgroundColor: theme.colorScheme.surface,
                body: Center(
                  child: AppProgressIndicator(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              );
            }

            if (state is StoryViewerError) {
              return StoryErrorWidget(
                message: state.error,
                onClose: () => Navigator.of(context).pop(),
              );
            }

            if (state is StoryViewerLoaded) {
              // CRITICAL FIX: Check if there are no users with stories
              if (state.usersWithStories.isEmpty) {
                // Auto-close will be handled by listener, but show a loading state
                final theme = Theme.of(context);
                return Scaffold(
                  backgroundColor: theme.colorScheme.surface,
                  body: Center(
                    child: AppProgressIndicator(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                );
              }

              final story = state.currentStory;
              if (story == null) {
                debugPrint(
                    'StoryViewerScreen: currentStory is null, users: ${state.usersWithStories.length}');
                // Auto-close is handled by listener if usersWithStories is empty
                final theme = Theme.of(context);
                return Scaffold(
                  backgroundColor: theme.colorScheme.surface,
                  appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    leading: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(DesignTokens.spaceXL),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: theme.colorScheme.onSurface,
                            size: DesignTokens.iconXXL,
                          ),
                          const SizedBox(height: DesignTokens.spaceMD),
                          Text(
                            'No story available',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceSM),
                          Text(
                            'User: ${state.currentUser?.username ?? "Unknown"}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(DesignTokens.opacityMedium),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceSM),
                          Text(
                            'Stories count: ${state.userStoriesMap[state.currentUser?.userId ?? ""]?.length ?? 0}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(DesignTokens.opacityMedium),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // CRITICAL FIX: Remove debug print that spams logs during build loops
              // Only log when story actually changes to reduce log spam
              if (_lastHandledStoryId != story.storyId) {
                debugPrint(
                    'StoryViewerScreen: Building story view for story ${story.storyId}');
              }
              return _buildStoryView(context, state, story);
            }

            // Default loading state
            final theme = Theme.of(context);
            return Scaffold(
              backgroundColor: theme.colorScheme.surface,
              body: Center(
                child: AppProgressIndicator(
                  color: theme.colorScheme.onSurface,
                ),
              ),
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
              final currentIndex =
                  currentUserStories.indexWhere((s) => s.storyId == storyId);
              if (currentIndex >= 0) {
                // Prefetch next 3-5 story videos (increased per plan requirements)
                _prefetchService.prefetchStoryVideos(
                    currentUserStories, currentIndex);
                // Prefetch next 3-5 story images (increased per plan requirements)
                _prefetchService.prefetchStoryImages(
                    currentUserStories, currentIndex);
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
              final currentIndex =
                  currentUserStories.indexWhere((s) => s.storyId == storyId);
              if (currentIndex >= 0) {
                // Prefetch next 2-3 story images
                _prefetchService.prefetchStoryImages(
                    currentUserStories, currentIndex);
                // Prefetch next 2-3 story videos
                _prefetchService.prefetchStoryVideos(
                    currentUserStories, currentIndex);
              }
            }
          }
        }
      });
    }

    // CRITICAL FIX: Sync video controller with pause state (only when needed)
    // Use a callback to avoid calling during build, which can cause rebuild loops
    if (story.mediaType == 'video' &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _videoController == null) return;

        // Only sync if state actually changed
        final shouldBePaused = state.isPaused;
        final isCurrentlyPlaying = _videoController!.value.isPlaying;

        if (shouldBePaused && isCurrentlyPlaying) {
          _videoController?.pause();
        } else if (!shouldBePaused &&
            !isCurrentlyPlaying &&
            !_videoController!.value.hasError) {
          _videoController?.play();
        }
      });
    }

    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser != null && story.authorId == currentUser.uid;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
          // Reply bar is always visible, this is handled by the widget itself
        },
        child: Stack(
          children: [
            // Story media - fill screen with smooth transitions
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: AnimationTokens.normal,
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
                    : Hero(
                        key: ValueKey('story-video-${story.storyId}'),
                        tag: 'story-${story.storyId}',
                        child: StoryVideoDisplayWidget(
                          controller: _videoController,
                        ),
                      ),
              ),
            ),

            // User header (includes progress segments)
            StoryUserHeader(
              user: state.currentUser,
              timestamp: story.createdAt,
              onOptionsPressed: () => _showStoryOptions(context, state),
              onClosePressed: () => Navigator.of(context).pop(),
              stories:
                  state.userStoriesMap[state.currentUser?.userId ?? ''] ?? [],
              currentStoryIndex: state.currentStoryIndex,
              progressMap: state.progressMap,
              isPaused: state.isPaused,
            ),

            // Overlays (text, drawings, stickers)
            StoryOverlaysWidget(story: story),

            // Play/pause indicator overlay (for video stories)
            if (story.mediaType == 'video')
              StoryPlayPauseIndicatorWidget(
                isPaused: state.isPaused,
                pauseIndicatorHideTime: _pauseIndicatorHideTime,
              ),

            // Viewers count (only for owners)
            if (isOwner)
              StoryViewersCountWidget(
                story: story,
                reactionCount: story.reactionCount,
              ),

            // Reply bar (only visible when viewing someone else's story)
            if (!isOwner)
              StoryReplyBarWidget(
                storyId: story.storyId,
                initialReactionCount: story.reactionCount,
                cubit: _cubit,
              ),
          ],
        ),
      ),
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
      // Show indicator and schedule auto-hide
      if (mounted) {
        setState(() {
          _pauseIndicatorHideTime = DateTime.now();
        });
        // Auto-hide after 3 seconds (handled by StoryPlayPauseIndicatorWidget)
      }
    }
  }

  void _showStoryOptions(BuildContext context, StoryViewerLoaded state) {
    final story = state.currentStory;
    if (story == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final isOwner = story.authorId == currentUser.uid;

    StoryOptionsDialog.show(
      context,
      isOwner: isOwner,
      onDelete: () async {
        final confirmed =
            await StoryOptionsDialog.showDeleteConfirmation(context);
        if (confirmed && mounted) {
          try {
            await _cubit?.deleteCurrentStory();
            if (mounted) {
              final theme = Theme.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Story deleted successfully'),
                  backgroundColor: theme.colorScheme.primary,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              final theme = Theme.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error deleting story: $e'),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            }
          }
        }
      },
      onReport: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report functionality coming soon'),
            ),
          );
        }
      },
      onClose: () {},
    );
  }
}
