import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:freegram/models/message.dart';
import 'package:freegram/theme/design_tokens.dart';

class VoiceMessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late final AudioPlayer _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;

  Duration _totalDuration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _totalDuration = widget.message.audioDuration ?? Duration.zero;
    _stateSub = _player.onPlayerStateChanged.listen(_handlePlayerState);
    _positionSub = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });
    _player.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _totalDuration = duration);
    });
  }

  void _handlePlayerState(PlayerState state) {
    if (!mounted) return;
    setState(() {
      if (state == PlayerState.completed) {
        _position = Duration.zero;
      }
      if (state != PlayerState.playing) {
        _isLoading = false;
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (widget.message.audioUrl == null) return;
    final currentState = _player.state;
    if (currentState == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (currentState == PlayerState.paused &&
        _position < _totalDuration &&
        _position > Duration.zero) {
      await _player.resume();
      return;
    }
    setState(() => _isLoading = true);
    await _player.stop();
    await _player.setSourceUrl(widget.message.audioUrl!);
    await _player.resume();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _seekTo(double value) async {
    final seekDuration = Duration(milliseconds: value.toInt());
    await _player.seek(seekDuration);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color accentColor =
        widget.isMe ? Colors.white : theme.colorScheme.primary;
    final bool hasWaveform =
        widget.message.waveform != null && widget.message.waveform!.isNotEmpty;

    return Column(
      crossAxisAlignment:
          widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildPlayButton(accentColor),
            const SizedBox(width: DesignTokens.spaceSM),
            Expanded(
              child: hasWaveform
                  ? _WaveformVisualizer(
                      samples: widget.message.waveform!,
                      progress: _progressRatio(),
                      activeColor: accentColor,
                      inactiveColor: accentColor.withOpacity(0.3),
                    )
                  : _buildProgressSlider(accentColor, theme),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spaceXS),
        Row(
          mainAxisAlignment:
              widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Text(
              _formatDuration(_position),
              style: TextStyle(
                fontSize: DesignTokens.fontSizeXS,
                color: accentColor.withOpacity(widget.isMe ? 0.9 : 0.7),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              ' / ',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeXS,
                color: accentColor.withOpacity(widget.isMe ? 0.8 : 0.6),
              ),
            ),
            Text(
              _formatDuration(_totalDuration),
              style: TextStyle(
                fontSize: DesignTokens.fontSizeXS,
                color: accentColor.withOpacity(widget.isMe ? 0.9 : 0.7),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayButton(Color accentColor) {
    final bool isPlaying = _player.state == PlayerState.playing;
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: _isLoading
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              )
            : Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: accentColor,
              ),
      ),
    );
  }

  Widget _buildProgressSlider(Color accentColor, ThemeData theme) {
    final double max = _totalDuration.inMilliseconds == 0
        ? 1
        : _totalDuration.inMilliseconds.toDouble();
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: accentColor,
        inactiveTrackColor: accentColor.withOpacity(0.2),
        thumbColor: accentColor,
      ),
      child: Slider(
        min: 0,
        max: max,
        value: _position.inMilliseconds.clamp(0, max.toInt()).toDouble(),
        onChanged: (_) {},
        onChangeEnd: _seekTo,
      ),
    );
  }

  double _progressRatio() {
    if (_totalDuration.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / _totalDuration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _WaveformVisualizer extends StatelessWidget {
  final List<double> samples;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  const _WaveformVisualizer({
    required this.samples,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final int activeCount =
        ((samples.length * progress).clamp(0, samples.length)).toInt();

    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < samples.length; i++)
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 1, vertical: 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: i <= activeCount ? activeColor : inactiveColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: SizedBox(
                    height: (samples[i].abs().clamp(0, 1) * 24) + 4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
