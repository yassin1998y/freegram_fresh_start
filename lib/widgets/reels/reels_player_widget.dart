// lib/widgets/reels/reels_player_widget.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/widgets/lqip_image.dart';
import 'package:freegram/widgets/reels/reels_video_ui_overlay.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/reel_repository.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_bloc.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_event.dart';
import 'package:freegram/widgets/reels/reels_comments_bottom_sheet.dart';
import 'package:freegram/widgets/reels/reels_profile_preview_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:freegram/services/media_prefetch_service.dart';
import 'package:freegram/services/network_quality_service.dart';
import 'package:freegram/services/cache_manager_service.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/blocs/reels_feed/reels_feed_state.dart';
import 'package:lottie/lottie.dart';

class ReelsPlayerWidget extends StatefulWidget {
  final ReelModel reel;
  final bool isCurrentReel;
  final MediaPrefetchService prefetchService;
  final bool showSwipeHint;

  const ReelsPlayerWidget({
    Key? key,
    required this.reel,
    required this.isCurrentReel,
    required this.prefetchService,
    this.showSwipeHint = false,
  }) : super(key: key);

  @override
  State<ReelsPlayerWidget> createState() => _ReelsPlayerWidgetState();
}

class _ReelsPlayerWidgetState extends State<ReelsPlayerWidget>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isLiked = false;
  bool _isLoading = true;
  bool _isPaused = false;
  DateTime? _lastTapTime;
  late NetworkQualityService _networkService;
  late CacheManagerService _cacheService;
  bool _isPrefetched = false; // Track if controller was prefetched

  // Phase 2.3: ABR properties for mid-stream quality switching
  NetworkQuality? _currentQuality;
  StreamSubscription<NetworkQuality>? _networkSubscription;
  bool _isSwitchingQuality = false;

  // Memory management: Track disposal timer to prevent flickering
  Timer? _disposalTimer;

  // CRITICAL FIX: Track pending post-frame callbacks to prevent accumulation
  int _pendingCallbackId = 0;

  // CRITICAL FIX: Mutex to prevent simultaneous video operations
  bool _isOperationInProgress = false;

  // Phase 1.2: Allow widget to be disposed when off-screen
  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    // Use GetIt to get services
    _networkService = locator<NetworkQualityService>();
    _cacheService = locator<CacheManagerService>();

    // Set initial quality with buffer capping for Task 3
    _currentQuality =
        _getAdjustedNetworkQuality(_networkService.currentQuality);

    _initializeVideo(initialQuality: _currentQuality!);
    _checkLikeStatus();

    // CRITICAL FIX: Listen to network quality changes with proper cancellation
    _networkSubscription = _networkService.qualityStream.listen(
      (newQuality) {
        final adjustedQuality = _getAdjustedNetworkQuality(newQuality);
        // Early return if widget is disposed, switching, or not current
        if (_isSwitchingQuality || !mounted || _videoController == null) return;
        if (!widget.isCurrentReel) return; // Only switch if currently visible

        // Check if a quality switch is necessary
        if (adjustedQuality != _currentQuality &&
            _shouldSwitchQuality(_currentQuality!, adjustedQuality)) {
          debugPrint(
              'ReelsPlayerWidget: Network change detected! Switching to $adjustedQuality (Network: $newQuality)');
          _switchVideoQuality(adjustedQuality);
        }
      },
      onError: (error) {
        debugPrint('ReelsPlayerWidget: Network quality stream error: $error');
      },
      cancelOnError: true, // CRITICAL: Cancel on error to prevent leaks
    );
  }

  @override
  void didUpdateWidget(ReelsPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CRITICAL FIX: Always dispose when reel changes
    if (oldWidget.reel.reelId != widget.reel.reelId) {
      // Use unawaited to prevent blocking - disposal is async now
      _disposeVideoImmediately().then((_) {
        if (mounted && !_isOperationInProgress) {
          _initializeVideo(
              initialQuality:
                  _currentQuality ?? _networkService.currentQuality);
          _checkLikeStatus();
        }
      });
      return;
    }

    // CRITICAL FIX: Immediate disposal when scrolling away (no timer delay)
    if (oldWidget.isCurrentReel != widget.isCurrentReel) {
      if (!widget.isCurrentReel) {
        // Immediately dispose when scrolled away - no delay
        // Use unawaited to prevent blocking
        _disposeVideoImmediately();
        // CRITICAL FIX: Cancel network subscription when scrolled away
        _cancelNetworkSubscription();
      } else if (widget.isCurrentReel) {
        // Re-initialize if scrolled back and controller was disposed
        // Add delay to ensure previous disposal completes
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_isOperationInProgress) {
            if (_videoController == null || !_isInitialized) {
              _initializeVideo(
                  initialQuality:
                      _currentQuality ?? _networkService.currentQuality);
            } else if (!_videoController!.value.isPlaying && !_isPaused) {
              _videoController?.play();
              if (mounted) {
                setState(() {
                  _isPaused = false;
                });
              }
            }
          }
        });
      }
    }
  }

  /// Consolidated video initialization with cache-first strategy, retry logic, and quality support
  /// Phase 2.1: Cache-first strategy - checks cache before network
  /// Phase 4.1: Consolidated initialization method (removed duplicate _initializeVideoWithRetry)
  Future<void> _initializeVideo({
    required NetworkQuality initialQuality,
    Duration startAt = Duration.zero,
    bool useCache = true,
    int maxRetries = 3,
    int attempt = 1,
  }) async {
    // CRITICAL FIX: Prevent simultaneous operations
    if (_isOperationInProgress) {
      debugPrint(
          'ReelsPlayerWidget: Operation in progress, skipping initialization');
      return;
    }

    if (_isSwitchingQuality && startAt == Duration.zero) return;

    // CRITICAL FIX: Set operation lock
    _isOperationInProgress = true;

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          if (startAt == Duration.zero) {
            _isSwitchingQuality = true;
          }
        });
      }

      // Phase 2.1: Check for prefetched controller first
      VideoPlayerController? prefetchedController;
      if (startAt == Duration.zero) {
        prefetchedController =
            widget.prefetchService.getPrefetchedController(widget.reel.reelId);
      }

      if (prefetchedController != null) {
        // Use prefetched controller
        debugPrint(
            'ReelsPlayerWidget: Using prefetched controller for ${widget.reel.reelId}');
        _videoController = prefetchedController;
        _isPrefetched = true;
        _videoController!.addListener(_videoListener);
        _videoController!.setVolume(1.0);
        _videoController!.setLooping(true);

        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isLoading = false;
            _isSwitchingQuality = false;
            _currentQuality = initialQuality;
          });

          if (widget.isCurrentReel && !_isPaused) {
            _videoController?.play();
          }
        }
        return;
      }

      // CRITICAL FIX: Cache-first strategy - ALWAYS check cache first, download if needed
      final videoUrl = widget.reel.getVideoUrlForQuality(initialQuality);
      VideoPlayerController? controller;
      File? cachedFile;

      if (useCache) {
        try {
          // Step 1: Try to get cached file
          cachedFile = await _cacheService.videoManager.getSingleFile(videoUrl);

          // Step 2: Verify file exists, is readable, and has valid size
          if (await cachedFile.exists()) {
            final fileSize = await cachedFile.length();
            // CRITICAL FIX: Enhanced verification - file must be > 1KB to be considered valid
            if (fileSize > 1024) {
              // ✅ File is cached and valid - use it
              debugPrint(
                  'ReelsPlayerWidget: Using cached file for ${widget.reel.reelId} (quality: $initialQuality, size: $fileSize bytes)');
              controller = VideoPlayerController.file(cachedFile);
            } else {
              // File exists but is too small/invalid - delete it and re-download
              debugPrint(
                  'ReelsPlayerWidget: Cached file is invalid (size: $fileSize bytes), deleting and re-downloading');
              try {
                await cachedFile.delete();
              } catch (e) {
                debugPrint(
                    'ReelsPlayerWidget: Error deleting invalid cache file: $e');
              }
              cachedFile = null;
            }
          }
        } catch (e) {
          debugPrint('ReelsPlayerWidget: Cache check failed: $e');
          cachedFile = null;
        }
      }

      // Step 3: If no cached file, download to cache FIRST, then create controller from cached file
      if (controller == null) {
        if (useCache) {
          try {
            // CRITICAL FIX: Download to cache FIRST, then use cached file
            debugPrint(
                'ReelsPlayerWidget: Downloading video to cache for ${widget.reel.reelId}');
            final fileInfo =
                await _cacheService.videoManager.downloadFile(videoUrl);
            cachedFile = fileInfo.file;

            // CRITICAL FIX: Enhanced verification - verify downloaded file exists and has valid size
            if (await cachedFile.exists()) {
              final fileSize = await cachedFile.length();
              // File must be > 1KB to be considered valid (prevents using corrupted/incomplete files)
              if (fileSize > 1024) {
                // ✅ File downloaded and cached - use it
                debugPrint(
                    'ReelsPlayerWidget: Video downloaded and cached (size: $fileSize bytes)');
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
                'ReelsPlayerWidget: Cache download failed: $e, falling back to network');
            // Fallback to network only if cache download fails
            controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
          }
        } else {
          // If cache is disabled, use network directly
          controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        }
      }

      // Add delay before retry (exponential backoff)
      if (attempt > 1) {
        final delayMs = (200 * (1 << (attempt - 2))).clamp(200, 2000);
        debugPrint(
            'ReelsPlayerWidget: Retrying video initialization (attempt $attempt/$maxRetries) after ${delayMs}ms delay');
        await Future.delayed(Duration(milliseconds: delayMs));
      }

      // Dispose previous controller if retrying
      if (_videoController != null && !_isPrefetched) {
        try {
          _videoController?.removeListener(_videoListener);
          _videoController?.dispose();
        } catch (e) {
          debugPrint(
              'ReelsPlayerWidget: Error disposing controller during retry: $e');
        }
        _videoController = null;
        if (attempt > 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      _videoController = controller;
      _videoController!.addListener(_videoListener);
      _isPrefetched = false;

      await _videoController!.initialize();

      // Success! Set up the controller
      if (mounted) {
        _videoController!.setLooping(true);
        _videoController!.setVolume(1.0);

        if (startAt > Duration.zero) {
          await _videoController!.seekTo(startAt);
        }

        setState(() {
          _isInitialized = true;
          _isLoading = false;
          _isSwitchingQuality = false;
          _currentQuality = initialQuality;
        });

        if (widget.isCurrentReel && !_isPaused) {
          _videoController?.play();
        }
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      final isMemoryError = errorStr.contains('no_memory') ||
          errorStr.contains('memory') ||
          errorStr.contains('codec');

      debugPrint(
          'ReelsPlayerWidget: Video initialization attempt $attempt failed: $e');

      // Clean up failed controller
      if (_videoController != null && !_isPrefetched) {
        try {
          _videoController?.removeListener(_videoListener);
          _videoController?.dispose();
        } catch (_) {}
        _videoController = null;
      }

      // If memory error and we can downgrade quality, try lower quality
      if (isMemoryError &&
          attempt == 1 &&
          initialQuality != NetworkQuality.poor) {
        final lowerQuality = _getLowerQuality(initialQuality);
        debugPrint(
            'ReelsPlayerWidget: Memory error detected, falling back to lower quality: $lowerQuality');
        return _initializeVideo(
          initialQuality: lowerQuality,
          startAt: startAt,
          useCache: useCache,
          maxRetries: maxRetries,
          attempt: 1,
        );
      }

      // Retry if we have attempts left
      if (attempt < maxRetries) {
        return _initializeVideo(
          initialQuality: initialQuality,
          startAt: startAt,
          useCache: useCache,
          maxRetries: maxRetries,
          attempt: attempt + 1,
        );
      }

      // All retries failed
      debugPrint(
          'ReelsPlayerWidget: All retry attempts failed for video initialization');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSwitchingQuality = false;
        });
      }
    } finally {
      // CRITICAL FIX: Release operation lock
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

  /// Phase 2.3: Switch video quality during playback (ABR).
  ///
  /// This method implements adaptive bitrate streaming by switching
  /// to a different quality URL based on network conditions while
  /// preserving playback position.
  Future<void> _switchVideoQuality(NetworkQuality newQuality) async {
    if (_videoController == null || !mounted || _isSwitchingQuality) return;
    if (!_videoController!.value.isInitialized) return;
    if (_isOperationInProgress) {
      debugPrint(
          'ReelsPlayerWidget: Operation in progress, skipping quality switch');
      return;
    }

    try {
      _isOperationInProgress = true;

      // 1. Save current playback position
      final oldPosition = _videoController!.value.position;
      final wasPlaying = _videoController!.value.isPlaying;

      debugPrint(
          'ReelsPlayerWidget: Switching quality to $newQuality at position $oldPosition');

      // 2. Dispose old controller immediately (CRITICAL FIX: no delayed disposal, no seek)
      _videoController!.removeListener(_videoListener);

      // CRITICAL FIX: Remove seekTo before disposal - it causes codec exhaustion
      // The pause() call is sufficient to stop playback

      if (!_isPrefetched) {
        // CRITICAL FIX: Dispose immediately to prevent memory leak
        final oldController = _videoController;
        _videoController = null;
        oldController?.dispose();

        // CRITICAL FIX: Add small delay to allow codec to release resources
        await Future.delayed(const Duration(milliseconds: 100));
      } else {
        // If it was prefetched, just nullify (service manages it)
        _videoController = null;
      }

      // 3. Re-initialize with new quality and old position
      await _initializeVideo(
        initialQuality: newQuality,
        startAt: oldPosition,
        useCache: true,
      );

      // 4. Resume playback if it was playing
      if (wasPlaying &&
          mounted &&
          _videoController != null &&
          widget.isCurrentReel) {
        _videoController?.play();
      }
    } catch (e) {
      debugPrint('ReelsPlayerWidget: Error switching video quality: $e');
      if (mounted) {
        setState(() {
          _isSwitchingQuality = false;
        });
      }
    } finally {
      _isOperationInProgress = false;
    }
  }

  /// Phase 2.3: Determines if a quality switch is necessary.
  ///
  /// Only switches for significant network quality changes to avoid
  /// unnecessary interruptions during playback.
  bool _shouldSwitchQuality(NetworkQuality old, NetworkQuality new_) {
    // Only switch if it's a significant change
    if (old == NetworkQuality.excellent &&
        (new_ == NetworkQuality.poor || new_ == NetworkQuality.fair)) {
      return true; // Downgrade from excellent to poor/fair
    }
    if ((old == NetworkQuality.poor || old == NetworkQuality.fair) &&
        new_ == NetworkQuality.excellent) {
      return true; // Upgrade from poor/fair to excellent
    }
    if (old == NetworkQuality.good && new_ == NetworkQuality.poor) {
      return true; // Downgrade from good to poor
    }
    if (old == NetworkQuality.poor && new_ == NetworkQuality.good) {
      return true; // Upgrade from poor to good
    }
    return false; // No significant change, don't switch
  }

  /// CRITICAL FIX: Safe listener that checks state before setState
  /// Tracks callback IDs to prevent accumulation of pending callbacks
  void _videoListener() {
    // Early return if controller is null or widget is disposed
    if (_videoController == null || !mounted) return;

    try {
      // Only update state if widget is still mounted and controller is valid
      if (mounted &&
          _videoController != null &&
          _videoController!.value.isInitialized) {
        // CRITICAL FIX: Track callback ID to prevent accumulation
        final callbackId = ++_pendingCallbackId;

        // Use WidgetsBinding to ensure we're in a valid frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // CRITICAL FIX: Only execute if this is still the latest callback and widget is mounted
          if (callbackId == _pendingCallbackId &&
              mounted &&
              _videoController != null) {
            setState(() {
              // State update is safe here
            });
          }
        });
      }
    } catch (e) {
      debugPrint('ReelsPlayerWidget: Error in video listener: $e');
    }
  }

  Future<void> _checkLikeStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final reelRepository = locator<ReelRepository>();
      final isLiked = await reelRepository.isReelLiked(
        widget.reel.reelId,
        currentUser.uid,
      );
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
        });
      }
    } catch (e) {
      debugPrint('ReelsPlayerWidget: Error checking like status: $e');
    }
  }

  /// CRITICAL FIX: Immediate disposal without delay, with operation lock
  Future<void> _disposeVideoImmediately() async {
    // CRITICAL FIX: Wait for any in-progress operations to complete
    if (_isOperationInProgress) {
      debugPrint(
          'ReelsPlayerWidget: Waiting for operation to complete before disposal');
      // Wait up to 500ms for operation to complete
      int waitCount = 0;
      while (_isOperationInProgress && waitCount < 10) {
        await Future.delayed(const Duration(milliseconds: 50));
        waitCount++;
      }
      // If still in progress, force unlock (might cause issues but prevents deadlock)
      if (_isOperationInProgress) {
        debugPrint('ReelsPlayerWidget: Force unlocking operation for disposal');
        _isOperationInProgress = false;
      }
    }

    // Cancel any pending timers
    _disposalTimer?.cancel();
    _disposalTimer = null;

    // CRITICAL FIX: Invalidate pending callbacks to prevent accumulation
    _pendingCallbackId++;

    if (_videoController != null) {
      try {
        _videoController!.removeListener(_videoListener);
        _videoController!.pause();

        // CRITICAL FIX: Remove seekTo - it causes codec exhaustion during fast scrolling
        // Just pause and dispose - the codec will be released by dispose()

        // Only dispose if we created it (not prefetched)
        // Prefetched controllers are managed by MediaPrefetchService
        if (!_isPrefetched) {
          // CRITICAL FIX: Dispose synchronously and immediately - no delay
          // Delays cause memory accumulation when scrolling quickly, leading to OOM crashes
          final controller = _videoController;
          _videoController = null;
          _isInitialized = false;
          controller?.dispose();

          // CRITICAL FIX: Removed delay - dispose immediately to prevent memory accumulation
        } else {
          // If prefetched, service manages it - just nullify our reference
          _videoController = null;
        }

        _isInitialized = false;

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        debugPrint('ReelsPlayerWidget: Error disposing video: $e');
        // Ensure controller is nullified even if disposal fails
        _videoController = null;
      }
    }
  }

  /// CRITICAL FIX: Cancel network subscription
  void _cancelNetworkSubscription() {
    _networkSubscription?.cancel();
    _networkSubscription = null;
  }

  @override
  void dispose() {
    // CRITICAL FIX: Cancel subscription FIRST
    _cancelNetworkSubscription();
    // Cancel disposal timer
    _disposalTimer?.cancel();
    _disposalTimer = null;
    // Invalidate pending callbacks
    _pendingCallbackId++;
    // Dispose video immediately (synchronous for dispose)
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
        debugPrint('ReelsPlayerWidget: Error in dispose: $e');
        _videoController = null;
      }
    }
    super.dispose();
  }

  void _handleLike() {
    HapticFeedback.mediumImpact(); // More important action gets medium impact
    final bloc = context.read<ReelsFeedBloc>();
    if (_isLiked) {
      bloc.add(UnlikeReel(widget.reel.reelId));
    } else {
      bloc.add(LikeReel(widget.reel.reelId));
    }

    // Update local state optimistically
    if (mounted) {
      setState(() {
        _isLiked = !_isLiked;
      });
    }
  }

  void _handleComment() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReelsCommentsBottomSheet(
        reelId: widget.reel.reelId,
        reel: widget.reel,
      ),
    );
  }

  void _handleShare() async {
    HapticFeedback.selectionClick();
    final bloc = context.read<ReelsFeedBloc>();
    bloc.add(ShareReel(widget.reel.reelId));

    // Implement native share functionality
    try {
      final shareText = widget.reel.caption?.isNotEmpty == true
          ? '${widget.reel.caption}\n\nCheck out this reel on Freegram!'
          : 'Check out this reel on Freegram!';

      await Share.share(
        shareText,
        subject: 'Reel by ${widget.reel.uploaderUsername}',
      );
    } catch (e) {
      debugPrint('ReelsPlayerWidget: Error sharing reel: $e');
      // Show error message to user if needed
    }
  }

  void _handleProfileTap() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReelsProfilePreviewBottomSheet(
        userId: widget.reel.uploaderId,
      ),
    );
  }

  void _handleDelete() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    HapticFeedback.mediumImpact();

    try {
      // Delete the reel
      final reelRepository = locator<ReelRepository>();
      await reelRepository.deleteReel(widget.reel.reelId, currentUser.uid);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reel deleted successfully'),
            duration: Duration(seconds: 2),
          ),
        );

        // Trigger feed refresh via BLoC
        final bloc = context.read<ReelsFeedBloc>();
        bloc.add(const RefreshReelsFeed());

        // Navigate back if in a modal or detail view
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('ReelsPlayerWidget: Error deleting reel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete reel: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleVideoTap() {
    // Prevent accidental taps - require a small delay between taps
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < AnimationTokens.normal) {
      return; // Ignore rapid taps
    }
    _lastTapTime = now;

    HapticFeedback.lightImpact();

    if (_videoController == null || !_isInitialized) return;

    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _videoController?.pause();
    } else {
      _videoController?.play();
    }

    // Auto-hide pause indicator after delay
    if (_isPaused) {
      Future.delayed(AnimationTokens.slow, () {
        if (mounted &&
            _videoController != null &&
            _videoController!.value.isPlaying) {
          setState(() {
            _isPaused = false;
          });
        }
      });
    }
  }

  Widget _buildPlayPauseIndicator() {
    return AnimatedOpacity(
      opacity: _isPaused ? DesignTokens.opacityFull : 0.0,
      duration: AnimationTokens.fast,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(DesignTokens.spaceMD),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: DesignTokens.opacityMedium),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pause,
              color: Colors.white,
              size: DesignTokens.iconXXL,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);

    // Listen to BLoC state changes to react to PlayReel/PauseReel events
    // This ensures the widget responds even if parent doesn't rebuild
    return BlocListener<ReelsFeedBloc, ReelsFeedState>(
      listener: (context, state) {
        if (state is ReelsFeedLoaded) {
          final shouldBePlaying =
              state.currentPlayingReelId == widget.reel.reelId &&
                  widget.isCurrentReel;
          final isCurrentlyPlaying = _videoController?.value.isPlaying ?? false;

          // Only react if state changed and video is initialized
          if (_isInitialized && _videoController != null) {
            if (shouldBePlaying && !isCurrentlyPlaying && !_isPaused) {
              _videoController?.play();
              if (mounted) setState(() => _isPaused = false);
            } else if (!shouldBePlaying && isCurrentlyPlaying) {
              _videoController?.pause();
            }
          }
        }
      },
      child: VisibilityDetector(
        key: Key('reel_${widget.reel.reelId}'),
        onVisibilityChanged: _handleVisibilityChanged,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black, // Dark background for video player
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video player
              // CRITICAL FIX: Wrap in RepaintBoundary to isolate rendering and reduce memory pressure
              if (_isInitialized && _videoController != null)
                RepaintBoundary(
                  child: GestureDetector(
                    onTap: _handleVideoTap,
                    onDoubleTapDown: (details) =>
                        _handleDoubleTap(details.localPosition),
                    onDoubleTap: () {}, // Handled by onDoubleTapDown
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
              else if (_isLoading)
                const Center(
                  child: AppProgressIndicator(
                    color: Colors.white,
                  ),
                )
              else
                // Thumbnail fallback - Using LQIP for fast loading
                // CRITICAL FIX: Wrap in RepaintBoundary and avoid Hero widgets to prevent tag collisions
                widget.reel.thumbnailUrl.isNotEmpty
                    ? RepaintBoundary(
                        child: LQIPImage(
                          imageUrl: widget.reel.thumbnailUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.video_library_outlined,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: DesignTokens.iconXXL,
                            ),
                            const SizedBox(height: DesignTokens.spaceMD),
                            Text(
                              'No thumbnail available',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),

              // Heart Pop Animations
              ..._hearts.map((heart) => _HeartAnim(
                    key: ValueKey(heart.id),
                    position: heart.position,
                    onComplete: () => setState(
                        () => _hearts.removeWhere((h) => h.id == heart.id)),
                  )),

              // Play/pause indicator overlay
              _buildPlayPauseIndicator(),

              // UI Overlay
              if (_isInitialized || !_isLoading)
                ReelsVideoUIOverlay(
                  reel: widget.reel,
                  isLiked: _isLiked,
                  onLike: _handleLike,
                  onComment: _handleComment,
                  onShare: _handleShare,
                  onProfileTap: _handleProfileTap,
                  currentUserId: FirebaseAuth.instance.currentUser?.uid,
                  onDelete: _handleDelete,
                  progress: _videoController?.value.isInitialized == true
                      ? _videoController!.value.position.inMilliseconds /
                          _videoController!.value.duration.inMilliseconds
                      : 0.0,
                  onScrub: (value) {
                    final duration = _videoController?.value.duration;
                    if (duration != null) {
                      _videoController?.seekTo(duration * value);
                    }
                  },
                ),

              // Swipe Up Hint (Lottie)
              if (widget.showSwipeHint && _isInitialized)
                Positioned(
                  bottom: 120,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 100,
                        child: Lottie.network(
                          'https://assets9.lottiefiles.com/packages/lf20_7limp2as.json',
                          repeat: true,
                        ),
                      ),
                      const Text(
                        'Swipe up for more',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // HEART ANIMATION LOGIC
  final List<_HeartPosition> _hearts = [];

  void _handleDoubleTap(Offset position) {
    if (!_isLiked) {
      _handleLike();
    }

    HapticFeedback.heavyImpact(); // Task 3: Double tap gets heavy haptic

    setState(() {
      _hearts.add(_HeartPosition(
        id: DateTime.now().millisecondsSinceEpoch,
        position: position,
      ));
    });
  }

  // Task 1: Smart-Auto-Play (>80% visible)
  void _handleVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction < 0.1 &&
        _videoController != null &&
        !widget.isCurrentReel) {
      _disposeVideoImmediately();
      return;
    }

    if (_videoController == null || !_isInitialized) return;
    if (_isPaused && !widget.isCurrentReel) return;

    // Task 1: auto-play only when >80% visible
    if (info.visibleFraction > 0.8 && widget.isCurrentReel) {
      _disposalTimer?.cancel();
      if (!_videoController!.value.isPlaying && !_isPaused) {
        _videoController?.play();
        if (mounted) setState(() => _isPaused = false);
      }
    } else if (info.visibleFraction < 0.5) {
      // Auto-pause when less than 50% visible (as requested: reset/pause move out of view)
      if (_videoController!.value.isPlaying) {
        _videoController?.pause();
      }
    }
  }

  /// Task 3: Adaptive Bitrate / Buffer Capping
  /// Returns a quality level capped by current network conditions
  NetworkQuality _getAdjustedNetworkQuality(NetworkQuality actualQuality) {
    switch (actualQuality) {
      case NetworkQuality.excellent:
        return NetworkQuality.excellent; // Allow 1080p/4K
      case NetworkQuality.good:
        return NetworkQuality.good; // Allow High/720p
      case NetworkQuality.fair:
        // Cap at 'fair' (roughly 720p or lower)
        return NetworkQuality.fair;
      case NetworkQuality.poor:
        // Strictly cap at 'poor' (360p/480p)
        return NetworkQuality.poor;
      case NetworkQuality.offline:
        return NetworkQuality.poor;
    }
  }
}

class _HeartPosition {
  final int id;
  final Offset position;
  _HeartPosition({required this.id, required this.position});
}

class _HeartAnim extends StatefulWidget {
  final Offset position;
  final VoidCallback onComplete;

  const _HeartAnim({
    Key? key,
    required this.position,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<_HeartAnim> createState() => _HeartAnimState();
}

class _HeartAnimState extends State<_HeartAnim>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 60,
      ),
    ]).animate(_controller);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 50,
      top: widget.position.dy - 50,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: const Icon(
                Icons.favorite,
                color: Colors.white,
                size: 100,
                shadows: [
                  Shadow(color: Colors.black26, blurRadius: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
