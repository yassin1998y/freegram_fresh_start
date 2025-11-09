// lib/widgets/story_widgets/video_trimmer_screen.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

/// Screen for trimming video to exactly 20 seconds
class VideoTrimmerScreen extends StatefulWidget {
  final File videoFile;
  final Function(File trimmedVideo)? onTrimmed;

  const VideoTrimmerScreen({
    Key? key,
    required this.videoFile,
    this.onTrimmed,
  }) : super(key: key);

  @override
  State<VideoTrimmerScreen> createState() => _VideoTrimmerScreenState();
}

class _VideoTrimmerScreenState extends State<VideoTrimmerScreen> {
  VideoPlayerController? _controller;
  double _startTime = 0.0;
  double _videoDuration = 0.0;
  bool _isTrimming = false;
  bool _isInitialized = false;
  
  // CRITICAL FIX: Throttle seek operations to prevent ImageReader buffer exhaustion
  DateTime? _lastSeekTime;
  static const Duration _minSeekInterval = Duration(milliseconds: 300); // Max ~3 seeks per second
  bool _isDragging = false;
  double? _pendingSeekTime;
  Timer? _seekDebounceTimer;

  static const double maxDuration = 20.0; // 20 seconds max

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(widget.videoFile);
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _videoDuration = _controller!.value.duration.inSeconds.toDouble();
          _isInitialized = true;
          
          // If video is already 20 seconds or less, set start time to 0
          if (_videoDuration <= maxDuration) {
            _startTime = 0.0;
          }
        });
        
        // CRITICAL FIX: Start playing the video after initialization
        // This ensures the preview is visible
        _controller?.play();
      }
    } catch (e) {
      debugPrint('VideoTrimmerScreen: Error initializing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading video: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _trimVideo() async {
    if (_isTrimming) return;

    setState(() {
      _isTrimming = true;
    });

    try {
      // Calculate end time
      final endTime = (_startTime + maxDuration).clamp(0.0, _videoDuration);
      
      debugPrint('VideoTrimmerScreen: Trimming video from $_startTime to $endTime');

      // Use video_compress to trim video
      final trimmedFile = await VideoCompress.compressVideo(
        widget.videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 30,
        startTime: _startTime.toInt(),
        duration: maxDuration.toInt(),
      );

      if (trimmedFile != null && trimmedFile.file != null) {
        debugPrint('VideoTrimmerScreen: Video trimmed successfully');
        
        if (mounted) {
          widget.onTrimmed?.call(trimmedFile.file!);
          Navigator.of(context).pop(trimmedFile.file);
        }
      } else {
        throw Exception('Failed to trim video');
      }
    } catch (e) {
      debugPrint('VideoTrimmerScreen: Error trimming video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error trimming video: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTrimming = false;
        });
      }
    }
  }

  /// CRITICAL FIX: Throttled seek to prevent ImageReader buffer exhaustion
  /// Completely disables seeks during dragging - only updates UI
  void _throttledSeek(double timeInSeconds) {
    // CRITICAL: Never seek while dragging - only update UI
    if (_isDragging) {
      _pendingSeekTime = timeInSeconds;
      return;
    }
    
    final now = DateTime.now();
    if (_lastSeekTime != null && now.difference(_lastSeekTime!) < _minSeekInterval) {
      // Skip this seek - too soon since last one, but schedule it
      _pendingSeekTime = timeInSeconds;
      _seekDebounceTimer?.cancel();
      _seekDebounceTimer = Timer(_minSeekInterval, () {
        if (!_isDragging && _pendingSeekTime != null) {
          _seekToTime(_pendingSeekTime!);
          _pendingSeekTime = null;
        }
      });
      return;
    }
    
    _lastSeekTime = now;
    _seekToTime(timeInSeconds);
  }
  
  /// CRITICAL FIX: Safe seek that handles errors and prevents buffer issues
  void _seekToTime(double timeInSeconds) {
    // CRITICAL: Never seek while dragging
    if (_isDragging || _controller == null || !_controller!.value.isInitialized) return;
    
    try {
      final duration = Duration(milliseconds: (timeInSeconds * 1000).toInt());
      _controller?.seekTo(duration);
    } catch (e) {
      debugPrint('VideoTrimmerScreen: Error seeking video: $e');
    }
  }

  @override
  void dispose() {
    // CRITICAL FIX: Cancel any pending seek operations
    _seekDebounceTimer?.cancel();
    // CRITICAL FIX: Pause before disposing to release buffers
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
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
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Trim Video',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _isInitialized
          ? Column(
              children: [
                // Video preview
                Expanded(
                  child: Center(
                    child: _controller != null &&
                            _controller!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                VideoPlayer(_controller!),
                                // CRITICAL FIX: Show pause indicator when dragging to prevent buffer exhaustion
                                if (_isDragging)
                                  Container(
                                    color: Colors.black26,
                                    child: const Center(
                                      child: Icon(
                                        Icons.pause_circle_filled,
                                        color: Colors.white70,
                                        size: 64,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : const AppProgressIndicator(color: Colors.white),
                  ),
                ),
                // Trim controls
                Container(
                  padding: const EdgeInsets.all(DesignTokens.spaceMD),
                  color: Colors.black87,
                  child: Column(
                    children: [
                      // Info text
                      if (_videoDuration > maxDuration)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: DesignTokens.spaceMD,
                          ),
                          child: Text(
                            'Select a 20-second segment from your video',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      // Visual Segment Selector
                      if (_videoDuration > maxDuration) ...[
                        // Segment timeline
                        Container(
                          height: 60,
                          margin: const EdgeInsets.only(bottom: DesignTokens.spaceMD),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            children: [
                              // Background timeline
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _TimelinePainter(
                                    totalDuration: _videoDuration,
                                    segmentStart: _startTime,
                                    segmentDuration: maxDuration,
                                  ),
                                ),
                              ),
                              // Draggable segment selector
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final timelineWidth = constraints.maxWidth - 32;
                                  final segmentWidth = (maxDuration / _videoDuration) * timelineWidth;
                                  final segmentLeft = (_startTime / _videoDuration) * timelineWidth + 16;
                                  
                                  return GestureDetector(
                                    onPanStart: (_) {
                                      // CRITICAL FIX: Pause video during dragging to prevent buffer exhaustion
                                      _isDragging = true;
                                      _controller?.pause();
                                    },
                                    onPanUpdate: (details) {
                                      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
                                      if (renderBox == null) return;
                                      
                                      final localPosition = renderBox.globalToLocal(details.globalPosition);
                                      final relativeX = localPosition.dx;
                                      
                                      final newLeft = (relativeX - (segmentWidth / 2)).clamp(16.0, timelineWidth - segmentWidth + 16.0);
                                      final newStart = ((newLeft - 16) / timelineWidth) * _videoDuration;
                                      final maxStart = _videoDuration - maxDuration;
                                      
                                      // CRITICAL FIX: Update UI immediately - NO seeks during dragging
                                      setState(() {
                                        _startTime = newStart.clamp(0.0, maxStart);
                                        _pendingSeekTime = _startTime; // Store for seek on drag end
                                      });
                                    },
                                    onPanEnd: (_) {
                                      // CRITICAL FIX: Seek to final position only after dragging ends
                                      _isDragging = false;
                                      if (_pendingSeekTime != null) {
                                        // Wait a bit for drag to fully end, then seek
                                        Future.delayed(const Duration(milliseconds: 100), () {
                                          if (mounted && !_isDragging && _controller != null) {
                                            _seekToTime(_pendingSeekTime!);
                                            _pendingSeekTime = null;
                                            // Resume playback after seek completes
                                            Future.delayed(const Duration(milliseconds: 300), () {
                                              if (mounted && !_isDragging) {
                                                _controller?.play();
                                              }
                                            });
                                          }
                                        });
                                      }
                                    },
                                    child: Stack(
                                      children: [
                                        // Non-selected portion before segment
                                        if (_startTime > 0)
                                          Positioned(
                                            left: 16,
                                            width: segmentLeft - 16,
                                            height: 60,
                                            child: Container(
                                              color: Colors.white.withOpacity(0.1),
                                            ),
                                          ),
                                        // Selected segment
                                        Positioned(
                                          left: segmentLeft,
                                          width: segmentWidth,
                                          height: 60,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: SonarPulseTheme.primaryAccent.withOpacity(0.3),
                                              border: Border.all(
                                                color: SonarPulseTheme.primaryAccent,
                                                width: 2,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                _formatTime(maxDuration),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: DesignTokens.fontSizeXS,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Non-selected portion after segment
                                        if (_startTime + maxDuration < _videoDuration)
                                          Positioned(
                                            left: segmentLeft + segmentWidth,
                                            width: timelineWidth - segmentLeft - segmentWidth + 16,
                                            height: 60,
                                            child: Container(
                                              color: Colors.white.withOpacity(0.1),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        // Time labels
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTime(_startTime),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: DesignTokens.fontSizeXS,
                              ),
                            ),
                            Text(
                              'Selected: ${_formatTime(maxDuration)}',
                              style: TextStyle(
                                color: SonarPulseTheme.primaryAccent,
                                fontSize: DesignTokens.fontSizeXS,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatTime(_startTime + maxDuration),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: DesignTokens.fontSizeXS,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.spaceMD),
                        // Fine adjustment slider
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.white),
                              onPressed: () {
                                final newStart = (_startTime - 1.0).clamp(0.0, _videoDuration - maxDuration);
                                setState(() {
                                  _startTime = newStart;
                                });
                                // CRITICAL FIX: Use throttled seek
                                _throttledSeek(_startTime);
                              },
                            ),
                            Expanded(
                              child: Slider(
                                value: _startTime,
                                min: 0.0,
                                max: (_videoDuration - maxDuration).clamp(0.0, _videoDuration),
                                activeColor: SonarPulseTheme.primaryAccent,
                                onChangeStart: (_) {
                                  // CRITICAL FIX: Pause video during slider drag
                                  _isDragging = true;
                                  _controller?.pause();
                                },
                                onChanged: (value) {
                                  // CRITICAL FIX: Update UI immediately - NO seeks during dragging
                                  setState(() {
                                    _startTime = value;
                                    _pendingSeekTime = value; // Store for seek on drag end
                                  });
                                },
                                onChangeEnd: (value) {
                                  // CRITICAL FIX: Seek to final position only after dragging ends
                                  _isDragging = false;
                                  // Wait a bit for drag to fully end, then seek
                                  Future.delayed(const Duration(milliseconds: 100), () {
                                    if (mounted && !_isDragging && _controller != null) {
                                      _seekToTime(value);
                                      _pendingSeekTime = null;
                                      // Resume playback after seek completes
                                      Future.delayed(const Duration(milliseconds: 300), () {
                                        if (mounted && !_isDragging) {
                                          _controller?.play();
                                        }
                                      });
                                    }
                                  });
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.white),
                              onPressed: () {
                                final maxStart = _videoDuration - maxDuration;
                                final newStart = (_startTime + 1.0).clamp(0.0, maxStart);
                                setState(() {
                                  _startTime = newStart;
                                });
                                // CRITICAL FIX: Use throttled seek
                                _throttledSeek(_startTime);
                              },
                            ),
                          ],
                        ),
                      ] else
                        // Video is already 20 seconds or less
                        Padding(
                          padding: const EdgeInsets.only(bottom: DesignTokens.spaceMD),
                          child: Text(
                            'Video is ${_formatTime(_videoDuration)} - no trimming needed',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: DesignTokens.fontSizeSM,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      // Video duration info
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: DesignTokens.spaceMD,
                        ),
                        child: Text(
                          'Total: ${_formatTime(_videoDuration)} | Selected: ${_formatTime(maxDuration)}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: DesignTokens.fontSizeXS,
                          ),
                        ),
                      ),
                      // Trim button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isTrimming ? null : _trimVideo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SonarPulseTheme.primaryAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: DesignTokens.spaceMD,
                            ),
                          ),
                          child: _isTrimming
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: AppProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Trim to 20 Seconds'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: AppProgressIndicator(color: Colors.white),
            ),
    );
  }

  String _formatTime(double seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toInt().toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

/// Custom painter for timeline visualization
class _TimelinePainter extends CustomPainter {
  final double totalDuration;
  final double segmentStart;
  final double segmentDuration;

  _TimelinePainter({
    required this.totalDuration,
    required this.segmentStart,
    required this.segmentDuration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2;

    // Draw timeline marks every 5 seconds
    final markInterval = 5.0;
    final markCount = (totalDuration / markInterval).ceil();
    final markSpacing = size.width / markCount;

    for (int i = 0; i <= markCount; i++) {
      final x = (i * markSpacing);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) {
    return oldDelegate.segmentStart != segmentStart ||
        oldDelegate.segmentDuration != segmentDuration;
  }
}

