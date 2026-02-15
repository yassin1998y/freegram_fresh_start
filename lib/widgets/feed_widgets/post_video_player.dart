// lib/widgets/feed_widgets/post_video_player.dart
// Video player widget for feed posts

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:freegram/models/media_item_model.dart';
import 'package:freegram/services/network_quality_service.dart';
import 'package:freegram/services/cache_manager_service.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/lqip_image.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/screens/video_player_screen.dart';

class PostVideoPlayer extends StatefulWidget {
  final MediaItem mediaItem;
  final bool loadMedia;
  final double? aspectRatio;
  final VoidCallback? onFullScreen;
  final bool isVisible; // Controls playback based on feed visibility

  const PostVideoPlayer({
    Key? key,
    required this.mediaItem,
    this.loadMedia = true,
    this.aspectRatio,
    this.onFullScreen,
    this.isVisible = true,
  }) : super(key: key);

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _hasError = false;
  bool _showControls = false;
  bool _isMuted = true; // Default muted
  NetworkQuality _currentQuality = NetworkQuality.good;
  Timer? _controlsTimer;
  double? _videoAspectRatio; // Track actual video aspect ratio
  final CacheManagerService _cacheService = locator<CacheManagerService>();
  final NetworkQualityService _networkService = NetworkQualityService();

  @override
  void didUpdateWidget(PostVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isVisible && oldWidget.isVisible) {
      // Pause video when feed becomes invisible (tab switch)
      if (_controller != null && _isPlaying) {
        _controller!.pause();
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _currentQuality = _networkService.currentQuality;
    // Listen to network quality changes
    _networkService.qualityStream.listen((quality) {
      if (mounted && _currentQuality != quality) {
        setState(() {
          _currentQuality = quality;
        });
      }
    });
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _pauseAndDispose();
    super.dispose();
  }

  void _pauseAndDispose() {
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
      _controller!.pause();
      if (_controller!.value.isInitialized) {
        _controller!.dispose();
      }
      _controller = null;
    }
    _isInitialized = false;
    _isPlaying = false;
  }

  void _videoListener() {
    if (!mounted) return;
    if (_controller != null && _controller!.value.isInitialized) {
      // Calculate actual video aspect ratio
      final size = _controller!.value.size;
      final aspectRatio =
          size.width > 0 && size.height > 0 ? size.width / size.height : null;

      setState(() {
        _isInitialized = true;
        if (aspectRatio != null) {
          _videoAspectRatio = aspectRatio;
        }
        if (_controller!.value.isPlaying != _isPlaying) {
          _isPlaying = _controller!.value.isPlaying;
        }
      });
    }
  }

  Future<void> _initializeVideo() async {
    if (_isLoading || _isInitialized) return;
    if (!widget.loadMedia) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Get video URL based on network quality
      debugPrint('PostVideoPlayer: MediaItem type: ${widget.mediaItem.type}');
      debugPrint('PostVideoPlayer: MediaItem url: ${widget.mediaItem.url}');
      debugPrint(
          'PostVideoPlayer: MediaItem videoUrls - 360p: ${widget.mediaItem.videoUrl360p}, 720p: ${widget.mediaItem.videoUrl720p}, 1080p: ${widget.mediaItem.videoUrl1080p}');
      debugPrint('PostVideoPlayer: Current network quality: $_currentQuality');

      final videoUrl = widget.mediaItem.getVideoUrlForQuality(_currentQuality);

      debugPrint('PostVideoPlayer: Selected video URL: $videoUrl');

      // Validate video URL
      if (videoUrl.isEmpty) {
        debugPrint(
            'PostVideoPlayer: Video URL is empty. MediaItem data: ${widget.mediaItem.toMap()}');
        throw Exception('Video URL is empty');
      }

      // Try to parse the URL to ensure it's valid
      final uri = Uri.tryParse(videoUrl);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        throw Exception('Invalid video URL: $videoUrl');
      }

      // Try to get cached file first
      VideoPlayerController? controller;
      try {
        final cachedFile =
            await _cacheService.videoManager.getSingleFile(videoUrl);
        if (await cachedFile.exists()) {
          controller = VideoPlayerController.file(cachedFile);
        }
      } catch (e) {
        debugPrint('PostVideoPlayer: Cache check failed, using network: $e');
      }

      // If no cached file, use network
      controller ??= VideoPlayerController.networkUrl(uri);

      await controller.initialize();
      controller.setLooping(false);
      controller.setVolume(_isMuted ? 0.0 : 1.0);
      controller.addListener(_videoListener);

      // Calculate aspect ratio immediately after initialization
      final size = controller.value.size;
      final aspectRatio =
          size.width > 0 && size.height > 0 ? size.width / size.height : null;

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
          _isLoading = false;
          if (aspectRatio != null) {
            _videoAspectRatio = aspectRatio;
          }
        });
      }
    } catch (e) {
      debugPrint('PostVideoPlayer: Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _handlePlayPause() {
    if (!_isInitialized || _controller == null) {
      // Initialize and play
      _initializeVideo().then((_) {
        if (mounted && _controller != null) {
          _controller!.play();
          setState(() {
            _isPlaying = true;
            _showControls = true;
          });
          _startControlsTimer();
        }
      });
      return;
    }

    if (_isPlaying) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      _controller!.play();
      setState(() {
        _isPlaying = true;
      });
    }
    _showControlsTemporarily();
  }

  void _toggleMute() {
    if (_controller != null && _isInitialized) {
      setState(() {
        _isMuted = !_isMuted;
        _controller!.setVolume(_isMuted ? 0.0 : 1.0);
      });
      _showControlsTemporarily();
    }
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });
    _startControlsTimer();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    // Auto-pause when scrolled away
    if (info.visibleFraction < 0.1 && _isPlaying && _controller != null) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
    }
    // Dispose when scrolled far away to save memory
    if (info.visibleFraction < 0.05 && _controller != null) {
      _pauseAndDispose();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('post_video_${widget.mediaItem.url}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: GestureDetector(
        onTap: () {
          if (!_isInitialized) {
            _handlePlayPause();
          } else {
            _showControlsTemporarily();
          }
        },
        child: AspectRatio(
          // Use actual video aspect ratio if available, otherwise use provided or default
          aspectRatio: _videoAspectRatio ?? widget.aspectRatio ?? 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video player or thumbnail
              if (_isInitialized && _controller != null && !_hasError)
                // Wrap VideoPlayer to ensure it maintains aspect ratio
                FittedBox(
                  fit: BoxFit
                      .contain, // Use contain to maintain aspect ratio without cropping
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                )
              else if (widget.mediaItem.thumbnailUrl != null &&
                  widget.loadMedia)
                LQIPImage(
                  imageUrl: widget.mediaItem.thumbnailUrl!,
                  fit:
                      BoxFit.contain, // Use contain to avoid cropping thumbnail
                )
              else
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),

              // Loading indicator
              if (_isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: AppProgressIndicator(color: Colors.white),
                  ),
                ),

              // Error state
              if (_hasError)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.white, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Failed to load video',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

              // Controls overlay
              if (_showControls || !_isInitialized) _buildControlsOverlay(),

              // Play button on thumbnail (when not initialized)
              if (!_isInitialized && !_isLoading && !_hasError)
                Center(
                  child: GestureDetector(
                    onTap: _handlePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(DesignTokens.spaceMD),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    if (!_isInitialized && !_isLoading) {
      return const SizedBox.shrink(); // Don't show controls if not initialized
    }

    final duration = _controller?.value.duration ?? Duration.zero;
    final position = _controller?.value.position ?? Duration.zero;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.3),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.5),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top controls (full-screen)
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceSM),
              child: IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white),
                onPressed: widget.onFullScreen ??
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerScreen(
                            mediaItem: widget.mediaItem,
                            initialPosition: _controller?.value.position,
                          ),
                        ),
                      );
                    },
              ),
            ),
          ),

          // Center play/pause button
          Center(
            child: IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
              onPressed: _handlePlayPause,
            ),
          ),

          // Bottom controls
          Container(
            padding: const EdgeInsets.all(DesignTokens.spaceSM),
            child: Column(
              children: [
                // Progress bar
                if (duration.inSeconds > 0)
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: position.inSeconds
                          .toDouble()
                          .clamp(0, duration.inSeconds.toDouble()),
                      max: duration.inSeconds.toDouble(),
                      onChanged: (value) {
                        if (_controller != null) {
                          _controller!.seekTo(Duration(seconds: value.toInt()));
                        }
                      },
                      activeColor: Colors.white,
                      inactiveColor: Colors.white38,
                    ),
                  ),

                // Bottom row: duration, mute button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Duration
                    Text(
                      '${_formatDuration(position)} / ${_formatDuration(duration)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),

                    // Mute button
                    IconButton(
                      icon: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                      ),
                      onPressed: _toggleMute,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
