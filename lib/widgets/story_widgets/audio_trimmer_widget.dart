// lib/widgets/story_widgets/audio_trimmer_widget.dart

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:freegram/models/audio_segment_model.dart';
import 'package:freegram/services/audio_trimmer_service.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

/// Widget for trimming audio with adaptive duration based on media type
class AudioTrimmerWidget extends StatefulWidget {
  final String audioFilePath;
  final String mediaType; // 'image' or 'video'
  final double? videoDuration; // Video duration in seconds (null for photos)
  final Function(AudioSegment segment) onSegmentSelected;

  const AudioTrimmerWidget({
    Key? key,
    required this.audioFilePath,
    required this.mediaType,
    this.videoDuration,
    required this.onSegmentSelected,
  }) : super(key: key);

  @override
  State<AudioTrimmerWidget> createState() => _AudioTrimmerWidgetState();
}

class _AudioTrimmerWidgetState extends State<AudioTrimmerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  double _audioDuration = 0.0;
  double _startTime = 0.0;
  double _selectedDuration = 20.0;
  bool _isLoading = true;
  bool _isPlaying = false;
  // Duration _currentPosition = Duration.zero; // Currently unused but kept for future use

  @override
  void initState() {
    super.initState();
    _initializeAudio();
    // Position tracking disabled - not currently used in UI
    // _audioPlayer.onPositionChanged.listen((position) {
    //   if (mounted) {
    //     setState(() {
    //       _currentPosition = position;
    //     });
    //   }
    // });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  Future<void> _initializeAudio() async {
    try {
      // Get audio duration
      final duration = await AudioTrimmerService.getAudioDuration(
        widget.audioFilePath,
      );

      if (duration != null && mounted) {
        setState(() {
          _audioDuration = duration;
          _calculateSelectedDuration();
          _isLoading = false;
        });
      } else {
        throw Exception('Could not get audio duration');
      }
    } catch (e) {
      debugPrint('AudioTrimmerWidget: Error initializing audio: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audio: $e')),
        );
      }
    }
  }

  void _calculateSelectedDuration() {
    if (widget.mediaType == 'image') {
      // Photos: always 20 seconds
      _selectedDuration = 20.0;
    } else if (widget.videoDuration != null) {
      if (widget.videoDuration! <= 20.0) {
        // Videos < 20s: match video duration exactly
        _selectedDuration = widget.videoDuration!;
      } else {
        // Videos > 20s: 20 seconds (video will be trimmed)
        _selectedDuration = 20.0;
      }
    }

    // Ensure start time + duration doesn't exceed audio duration
    if (_startTime + _selectedDuration > _audioDuration) {
      _startTime = (_audioDuration - _selectedDuration).clamp(0.0, _audioDuration);
    }
  }

  Future<void> _playPreview() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        // Seek to start time and play
        await _audioPlayer.seek(Duration(seconds: _startTime.toInt()));
        await _audioPlayer.play(DeviceFileSource(widget.audioFilePath));
        setState(() {
          _isPlaying = true;
        });

        // Auto-stop after selected duration
        Future.delayed(Duration(seconds: _selectedDuration.toInt()), () {
          if (mounted) {
            _audioPlayer.pause();
            setState(() {
              _isPlaying = false;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('AudioTrimmerWidget: Error playing preview: $e');
    }
  }

  void _applySelection() {
    final segment = AudioSegment(
      audioFilePath: widget.audioFilePath,
      startTime: _startTime,
      endTime: _startTime + _selectedDuration,
    );
    widget.onSegmentSelected(segment);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatTime(double seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toInt().toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(
        child: AppProgressIndicator(color: Colors.white),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusXL),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSM),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
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
                    widget.mediaType == 'image'
                        ? 'Select Audio (20s)'
                        : widget.videoDuration != null &&
                                widget.videoDuration! <= 20.0
                            ? 'Select Audio'
                            : 'Trim Video & Select Audio',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            // Media info
            if (widget.mediaType == 'video' && widget.videoDuration != null)
              Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
                child: Row(
                  children: [
                    Icon(
                      Icons.video_library,
                      size: DesignTokens.iconMD,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    const SizedBox(width: DesignTokens.spaceSM),
                    Text(
                      'Video: ${_formatTime(widget.videoDuration!)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (widget.videoDuration! > 20.0) ...[
                      const SizedBox(width: DesignTokens.spaceSM),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spaceSM,
                          vertical: DesignTokens.spaceXS,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                        ),
                        child: Text(
                          'Will be trimmed to 20s',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            // Waveform placeholder (simplified - can be enhanced with actual waveform)
            Container(
              height: 100,
              margin: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
              child: Center(
                child: Text(
                  'Audio Waveform',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            // Duration info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
              child: Text(
                widget.mediaType == 'image'
                    ? 'Duration: 20 seconds'
                    : widget.videoDuration != null &&
                            widget.videoDuration! <= 20.0
                        ? 'Audio matches video (${_formatTime(widget.videoDuration!)})'
                        : 'Audio matches video (20s)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            // Slider for start time selection
            if (_audioDuration > _selectedDuration)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatTime(_startTime),
                          style: theme.textTheme.bodySmall,
                        ),
                        Expanded(
                          child: Slider(
                            value: _startTime,
                            min: 0.0,
                            max: (_audioDuration - _selectedDuration)
                                .clamp(0.0, _audioDuration),
                            activeColor: SonarPulseTheme.primaryAccent,
                            onChanged: (value) {
                              setState(() {
                                _startTime = value;
                              });
                            },
                          ),
                        ),
                        Text(
                          _formatTime(_startTime + _selectedDuration),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    Text(
                      'Total: ${_formatTime(_audioDuration)} | Selected: ${_formatTime(_selectedDuration)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: DesignTokens.spaceMD),
            // Preview and Apply buttons
            Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _playPreview,
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      label: Text(_isPlaying ? 'Pause' : 'Preview'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SonarPulseTheme.primaryAccent,
                        side: const BorderSide(color: SonarPulseTheme.primaryAccent),
                      ),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceMD),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _applySelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SonarPulseTheme.primaryAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spaceSM),
          ],
        ),
      ),
    );
  }

}

