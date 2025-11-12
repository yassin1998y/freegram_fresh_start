// lib/screens/video_player_screen.dart
// Full-screen video player for feed posts

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:freegram/models/media_item_model.dart';
import 'package:freegram/services/network_quality_service.dart';
import 'package:freegram/services/cache_manager_service.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/locator.dart';

class VideoPlayerScreen extends StatefulWidget {
  final MediaItem mediaItem;
  final Duration? initialPosition;

  const VideoPlayerScreen({
    Key? key,
    required this.mediaItem,
    this.initialPosition,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _hasError = false;
  bool _showControls = true;
  bool _isMuted = false;
  bool _isPlaying = false;
  NetworkQuality _currentQuality = NetworkQuality.good;
  Timer? _controlsTimer;
  final CacheManagerService _cacheService = locator<CacheManagerService>();
  final NetworkQualityService _networkService = NetworkQualityService();

  @override
  void initState() {
    super.initState();
    _currentQuality = _networkService.currentQuality;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    _initializeVideo();

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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _controlsTimer?.cancel();
    _pauseAndDispose();
    super.dispose();
  }

  void _pauseAndDispose() {
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
      _controller!.pause();
      _controller!.dispose();
      _controller = null;
    }
    _isInitialized = false;
    _isPlaying = false;
  }

  void _videoListener() {
    if (!mounted) return;
    if (_controller != null && _controller!.value.isInitialized) {
      setState(() {
        _isInitialized = true;
        if (_controller!.value.isPlaying != _isPlaying) {
          _isPlaying = _controller!.value.isPlaying;
        }
      });
    }
  }

  Future<void> _initializeVideo() async {
    if (_isLoading || _isInitialized) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Get video URL based on network quality
      final videoUrl = widget.mediaItem.getVideoUrlForQuality(_currentQuality);

      // Try to get cached file first
      VideoPlayerController? controller;
      try {
        final cachedFile =
            await _cacheService.videoManager.getSingleFile(videoUrl);
        if (await cachedFile.exists()) {
          controller = VideoPlayerController.file(cachedFile);
        }
      } catch (e) {
        debugPrint('VideoPlayerScreen: Cache check failed, using network: $e');
      }

      // If no cached file, use network
      controller ??= VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      await controller.initialize();
      controller.setLooping(false);
      controller.setVolume(_isMuted ? 0.0 : 1.0);
      controller.addListener(_videoListener);

      // Seek to initial position if provided
      if (widget.initialPosition != null) {
        await controller.seekTo(widget.initialPosition!);
      }

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
          _isLoading = false;
        });
        // Auto-play in full-screen
        _controller!.play();
        setState(() {
          _isPlaying = true;
        });
        _startControlsTimer();
      }
    } catch (e) {
      debugPrint('VideoPlayerScreen: Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _handlePlayPause() {
    if (!_isInitialized || _controller == null) return;

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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          _showControlsTemporarily();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video player
            if (_isInitialized && _controller != null && !_hasError)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (_isLoading)
              const Center(
                child: AppProgressIndicator(color: Colors.white),
              )
            else if (_hasError)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load video',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),

            // Controls overlay
            if (_showControls) _buildControlsOverlay(),

            // Back button - positioned in top-left corner
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(DesignTokens.spaceMD),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }

    final duration = _controller?.value.duration ?? Duration.zero;
    final position = _controller?.value.position ?? Duration.zero;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.5),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top spacing
          const SizedBox(height: 60),

          // Center play/pause button
          Center(
            child: IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 64,
              ),
              onPressed: _handlePlayPause,
            ),
          ),

          // Bottom controls
          Container(
            padding: const EdgeInsets.all(DesignTokens.spaceMD),
            child: Column(
              children: [
                // Progress bar
                if (duration.inSeconds > 0)
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 8),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // Mute button
                    IconButton(
                      icon: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 28,
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
