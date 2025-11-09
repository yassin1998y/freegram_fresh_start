// lib/widgets/story_widgets/audio_preview_widget.dart

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Simple widget for audio preview playback
class AudioPreviewWidget extends StatefulWidget {
  final String audioPath;
  final double? startTime;
  final double? duration;

  const AudioPreviewWidget({
    Key? key,
    required this.audioPath,
    this.startTime,
    this.duration,
  }) : super(key: key);

  @override
  State<AudioPreviewWidget> createState() => _AudioPreviewWidgetState();
}

class _AudioPreviewWidgetState extends State<AudioPreviewWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        if (widget.startTime != null) {
          await _audioPlayer.seek(Duration(seconds: widget.startTime!.toInt()));
        }
        await _audioPlayer.play(DeviceFileSource(widget.audioPath));
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint('AudioPreviewWidget: Error toggling playback: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final mins = duration.inMinutes.toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: _togglePlayback,
          color: SonarPulseTheme.primaryAccent,
        ),
        if (_totalDuration.inSeconds > 0)
          Text(
            '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
            style: const TextStyle(
              fontSize: DesignTokens.fontSizeXS,
              color: Colors.white70,
            ),
          ),
      ],
    );
  }
}

