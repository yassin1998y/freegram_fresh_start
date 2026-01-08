// lib/widgets/chat_widgets/enhanced_message_input.dart

import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/services/voice_recorder_controller.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/chat_widgets/emoji_picker_widget.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/island_popup.dart';

/// Enhanced message input area with multi-line support and attachments
/// Improvement #22 - Implement enhanced message input area
class EnhancedMessageInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onLongPressSend;
  final VoidCallback onCamera;
  final VoidCallback? onGallery;
  final VoidCallback? onAttachment;
  final Future<void> Function(String audioPath, Duration duration)? onSendAudio;
  final bool isUploading;
  final String? replyingTo;
  final VoidCallback? onCancelReply;

  const EnhancedMessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onLongPressSend,
    required this.onCamera,
    this.onGallery,
    this.onAttachment,
    this.onSendAudio,
    this.isUploading = false,
    this.replyingTo,
    this.onCancelReply,
  });

  @override
  State<EnhancedMessageInput> createState() => _EnhancedMessageInputState();
}

class _EnhancedMessageInputState extends State<EnhancedMessageInput> {
  bool _hasText = false;
  bool _showAttachmentMenu = false;
  bool _showEmojiPicker = false;
  bool _isRecording = false;
  bool _isCancellingRecording = false;
  Duration _currentRecordingDuration = Duration.zero;
  double _currentAmplitude = 0;
  String? _pendingAudioPath;
  Duration? _pendingAudioDuration;
  AudioPlayer? _previewPlayer;
  Duration _previewPosition = Duration.zero;
  bool _isPreviewPlaying = false;
  bool _micActionInProgress = false;

  static const double _cancelDragThreshold = 70;

  late final VoiceRecorderController _voiceRecorderController;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _voiceRecorderController = VoiceRecorderController();
    _voiceRecorderController.isRecording
        .addListener(_handleRecordingStateChanged);
    _voiceRecorderController.recordingDuration
        .addListener(_handleRecordingDurationChanged);
    _voiceRecorderController.amplitude.addListener(_handleAmplitudeChanged);
    _voiceRecorderController.isPaused
        .addListener(_handleRecordingPausedChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleRecordingStateChanged() {
    if (!mounted) return;
    setState(() {
      _isRecording = _voiceRecorderController.isRecording.value;
      if (!_isRecording) {
        _isCancellingRecording = false;
      }
    });
  }

  void _handleRecordingDurationChanged() {
    if (!mounted) return;
    setState(() {
      _currentRecordingDuration =
          _voiceRecorderController.recordingDuration.value;
    });
  }

  void _handleAmplitudeChanged() {
    if (!mounted) return;
    setState(() {
      _currentAmplitude = _voiceRecorderController.amplitude.value;
    });
  }

  void _handleRecordingPausedChanged() {
    if (!mounted) return;
    if (_voiceRecorderController.isPaused.value) {
      _stopPreviewPlayback();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _voiceRecorderController.isRecording
        .removeListener(_handleRecordingStateChanged);
    _voiceRecorderController.recordingDuration
        .removeListener(_handleRecordingDurationChanged);
    _voiceRecorderController.amplitude.removeListener(_handleAmplitudeChanged);
    _voiceRecorderController.isPaused
        .removeListener(_handleRecordingPausedChanged);
    _voiceRecorderController.dispose();
    _disposePreviewPlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply preview
            if (widget.replyingTo != null) _buildReplyPreview(),

            // Emoji picker
            if (_showEmojiPicker)
              EmojiPickerWidget(
                onEmojiSelected: (emoji) {
                  final text = widget.controller.text;
                  final selection = widget.controller.selection;
                  final newText = text.replaceRange(
                    selection.start,
                    selection.end,
                    emoji,
                  );
                  widget.controller.text = newText;
                  widget.controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: selection.start + emoji.length),
                  );
                  _onTextChanged(); // Update _hasText state
                },
              ),

            // Input row
            Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceSM),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attachment button
                  _buildAttachmentButton(),

                  const SizedBox(width: DesignTokens.spaceSM),

                  // Text input
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                        maxHeight: 120, // 5 lines max
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.3),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusXL),
                        border: Border.all(
                          color: theme.dividerColor.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isRecording
                            ? _buildRecordingContent(theme)
                            : (_pendingAudioPath != null
                                ? _buildRecordingPreviewContent(theme)
                                : _buildTextInputContent(theme)),
                      ),
                    ),
                  ),

                  const SizedBox(width: DesignTokens.spaceSM),

                  // Send button (morphs from voice)
                  _buildActionButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInputContent(ThemeData theme) {
    return Row(
      key: const ValueKey('text-input'),
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: widget.controller,
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: DesignTokens.fontSizeMD,
                                height: DesignTokens.lineHeightNormal,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                  fontSize: DesignTokens.fontSizeMD,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: DesignTokens.spaceMD,
                                  vertical: DesignTokens.spaceSM,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
            _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                              color: _showEmojiPicker
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withOpacity(0.6),
                              size: DesignTokens.iconLG,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _showEmojiPicker = !_showEmojiPicker;
                              });
                              if (_showEmojiPicker) {
                                FocusScope.of(context).unfocus();
                              }
                            },
                          ),
                        ],
    );
  }

  Widget _buildRecordingContent(ThemeData theme) {
    final cancelColor = theme.colorScheme.error;
    final primary = theme.colorScheme.primary;

    return Container(
      key: const ValueKey('recording-content'),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMD,
        vertical: DesignTokens.spaceSM,
      ),
      child: Row(
        children: [
          Icon(
            Icons.mic,
            color: _isCancellingRecording ? cancelColor : primary,
          ),
          const SizedBox(width: DesignTokens.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _formatDuration(_currentRecordingDuration),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceSM),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        height: 18,
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FractionallySizedBox(
                          widthFactor: (_normalizedAmplitude() * 0.6) + 0.2,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _isCancellingRecording
                                  ? cancelColor
                                  : primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _isCancellingRecording
                          ? Icons.delete_outline
                          : Icons.swipe_left_alt,
                      size: DesignTokens.iconSM,
                      color: _isCancellingRecording
                          ? cancelColor
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _isCancellingRecording
                            ? 'Release to cancel'
                            : 'Slide left to cancel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeSM,
                          color: _isCancellingRecording
                              ? cancelColor
                              : theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
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

  Widget _buildRecordingPreviewContent(ThemeData theme) {
    final primary = theme.colorScheme.primary;
    final danger = theme.colorScheme.error;
    final total = _pendingAudioDuration ?? Duration.zero;

    return Container(
      key: const ValueKey('recording-preview'),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMD,
        vertical: DesignTokens.spaceSM,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.isUploading ? null : _togglePreviewPlayback,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPreviewPlaying ? Icons.pause : Icons.play_arrow,
                color: primary,
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: primary,
                    inactiveTrackColor: primary.withOpacity(0.2),
                    thumbColor: primary,
                  ),
                  child: Slider(
                    min: 0,
                    max: total.inMilliseconds
                        .clamp(1, double.infinity)
                        .toDouble(),
                    value: _previewPosition.inMilliseconds
                        .clamp(0, total.inMilliseconds)
                        .toDouble(),
                    onChanged: widget.isUploading
                        ? null
                        : (value) {
                            _previewPlayer?.seek(
                              Duration(milliseconds: value.toInt()),
                            );
                          },
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _formatDuration(_previewPosition),
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeXS,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ ${_formatDuration(total)}',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeXS,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
            ),
          ],
        ),
          ),
          const SizedBox(width: DesignTokens.spaceSM),
          IconButton(
            icon: Icon(Icons.delete_outline, color: danger),
            onPressed: widget.isUploading
                ? null
                : () async {
                    await _discardPendingAudio();
                  },
            tooltip: 'Delete recording',
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 1,
          ),
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: DesignTokens.iconSM,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: DesignTokens.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeXS,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.replyingTo!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeSM,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: DesignTokens.iconSM,
              color: theme.colorScheme.primary.withOpacity(0.6),
            ),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton() {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _showAttachmentMenu = !_showAttachmentMenu);
          if (_showAttachmentMenu) {
            _showAttachmentOptions();
          }
        },
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
            boxShadow: DesignTokens.shadowLight,
          ),
          child: Icon(
            _showAttachmentMenu ? Icons.close : Icons.add,
            color: Colors.white,
            size: DesignTokens.iconLG,
          ),
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusXL),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: DesignTokens.spaceMD),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AttachmentOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onCamera();
                    },
                  ),
                  _AttachmentOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onGallery?.call();
                    },
                  ),
                  _AttachmentOption(
                    icon: Icons.attach_file,
                    label: 'File',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onAttachment?.call();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _showAttachmentMenu = false);
      }
    });
  }

  Widget _buildActionButton() {
    final theme = Theme.of(context);

    if (widget.isUploading) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        ),
        child: const Center(
          child: AppProgressIndicator(
            size: 24,
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      );
    }

    if (_pendingAudioPath != null && widget.onSendAudio != null) {
      return _buildSendAudioButton(theme);
    }

    if (_hasText || widget.onSendAudio == null) {
      return _buildSendButton(theme);
    }

    return _buildMicButton(theme);
  }

  Widget _buildSendButton(ThemeData theme) {
    return GestureDetector(
      onTap: _hasText
          ? () {
              HapticFeedback.mediumImpact();
              widget.onSend();
            }
          : null,
      onLongPress: _hasText && widget.onLongPressSend != null
          ? () {
              HapticFeedback.heavyImpact();
              widget.onLongPressSend!();
            }
          : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _hasText
              ? theme.colorScheme.primary
              : theme.colorScheme.primary.withOpacity(0.3),
          borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
          boxShadow: _hasText ? DesignTokens.shadowLight : null,
        ),
        child: Icon(
          widget.onLongPressSend != null ? Icons.schedule_send : Icons.send,
          color: _hasText ? Colors.white : Colors.white.withOpacity(0.6),
          size: DesignTokens.iconMD,
        ),
      ),
    );
  }

  Widget _buildSendAudioButton(ThemeData theme) {
    return GestureDetector(
      onTap: widget.isUploading ? null : _sendPendingAudio,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
          boxShadow: DesignTokens.shadowLight,
        ),
        child: const Icon(
          Icons.send,
          color: Colors.white,
          size: DesignTokens.iconMD,
        ),
      ),
    );
  }

  Widget _buildMicButton(ThemeData theme) {
    final bool recordingActive = _voiceRecorderController.isRecording.value;
    final Color baseColor = _isCancellingRecording
        ? theme.colorScheme.error.withOpacity(0.9)
        : recordingActive
            ? theme.colorScheme.error
            : theme.colorScheme.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: widget.onSendAudio == null
          ? null
          : (details) async => _handleMicLongPressStart(),
      onLongPressMoveUpdate: widget.onSendAudio == null
          ? null
          : (details) => _handleMicLongPressMove(details),
      onLongPressEnd: widget.onSendAudio == null
          ? null
          : (details) async {
              await _handleMicLongPressEnd(details);
            },
      onLongPressCancel: widget.onSendAudio == null
          ? null
          : () async {
              await _voiceRecorderController.cancelRecording();
              if (mounted) {
                setState(() => _isCancellingRecording = false);
              }
            },
      onTap: widget.onSendAudio == null ? null : _handleMicTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
          boxShadow: recordingActive ? DesignTokens.shadowLight : null,
        ),
        child: const Icon(
          Icons.mic,
          color: Colors.white,
          size: DesignTokens.iconMD,
        ),
      ),
    );
  }

  Future<void> _handleMicLongPressStart() async {
    if (widget.onSendAudio == null ||
        widget.isUploading ||
        _micActionInProgress) {
      return;
    }
    _micActionInProgress = true;
    try {
      if (_pendingAudioPath != null) {
        await _discardPendingAudio();
      }
      await _startVoiceRecording();
    } finally {
      _micActionInProgress = false;
    }
  }

  void _handleMicLongPressMove(LongPressMoveUpdateDetails details) {
    if (!_voiceRecorderController.isRecording.value) return;
    final shouldCancel = details.offsetFromOrigin.dx < -_cancelDragThreshold;
    if (shouldCancel != _isCancellingRecording) {
      setState(() => _isCancellingRecording = shouldCancel);
    }
  }

  Future<void> _handleMicLongPressEnd(LongPressEndDetails details) async {
    if (!_voiceRecorderController.isRecording.value) {
      if (mounted) setState(() => _isCancellingRecording = false);
      return;
    }

    final shouldCancel = _isCancellingRecording;

    if (shouldCancel) {
      await _voiceRecorderController.cancelRecording();
      if (mounted) {
        setState(() => _isCancellingRecording = false);
        showIslandPopup(
          context: context,
          message: 'Recording cancelled',
          icon: Icons.mic_off,
        );
      }
      return;
    }

    await _finalizeRecording();
  }

  Future<void> _startVoiceRecording({bool showHint = false}) async {
    setState(() {
      _isCancellingRecording = false;
      _showEmojiPicker = false;
    });
    FocusScope.of(context).unfocus();

    final started = await _voiceRecorderController.startRecording();
    if (!started && mounted) {
      showIslandPopup(
        context: context,
        message: 'Allow microphone access to send voice messages',
        icon: Icons.mic_off,
      );
    } else if (started) {
      HapticFeedback.mediumImpact();
      if (showHint) {
        showIslandPopup(
          context: context,
          message: 'Recording... tap again to finish or slide left to cancel',
          icon: Icons.mic,
        );
      }
    }
  }

  double _normalizedAmplitude() {
    const double maxAmplitude = 120;
    return (_currentAmplitude.abs() / maxAmplitude).clamp(0.0, 1.0);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _handleMicTap() async {
    if (widget.onSendAudio == null ||
        widget.isUploading ||
        _micActionInProgress) {
      return;
    }

    _micActionInProgress = true;
    HapticFeedback.selectionClick();

    try {
      if (_voiceRecorderController.isRecording.value) {
        await _finalizeRecording();
        return;
      }

      if (_pendingAudioPath != null) {
        showIslandPopup(
          context: context,
          message:
              'Preview or send the current recording, or delete it to record again.',
          icon: Icons.mic,
        );
        return;
      }

      await _startVoiceRecording(showHint: true);
    } finally {
      _micActionInProgress = false;
    }
  }

  Future<void> _finalizeRecording() async {
    final duration = _currentRecordingDuration;
    final path = await _voiceRecorderController.stopRecording();
    if (path == null) {
      if (mounted) {
        setState(() => _isCancellingRecording = false);
        showIslandPopup(
          context: context,
          message: 'Recording failed. Please try again.',
          icon: Icons.error_outline,
        );
      }
      return;
    }

    await _preparePreview(path, duration);
    if (mounted) {
      setState(() {
        _pendingAudioPath = path;
        _pendingAudioDuration = duration;
        _isCancellingRecording = false;
      });
    }
  }

  Future<void> _preparePreview(String path, Duration duration) async {
    await _disposePreviewPlayer();

    // Ensure we have an absolute path and verify file exists with content
    final file = File(path);
    if (!await file.exists()) {
      // Wait for file to be written (max 2 seconds)
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (await file.exists()) {
          final stat = await file.stat();
          if (stat.size > 0) break;
        }
      }
    }

    // Final check that file exists and has content
    if (!await file.exists()) {
      debugPrint('Audio file does not exist: $path');
      if (mounted) {
        showIslandPopup(
          context: context,
          message: 'Failed to prepare audio preview',
          icon: Icons.error_outline,
        );
      }
      return;
    }

    final stat = await file.stat();
    if (stat.size == 0) {
      debugPrint('Audio file is empty: $path');
      if (mounted) {
        showIslandPopup(
          context: context,
          message: 'Audio file is empty',
          icon: Icons.error_outline,
        );
      }
      return;
    }

    final absolutePath = file.absolute.path;
    final player = AudioPlayer();

    try {
      await player.setSourceDeviceFile(absolutePath);
      player.onPositionChanged.listen((position) {
        if (!mounted) return;
        setState(() => _previewPosition = position);
      });
      player.onPlayerComplete.listen((event) {
        if (!mounted) return;
        setState(() {
          _isPreviewPlaying = false;
          _previewPosition = Duration.zero;
        });
      });
      if (mounted) {
        setState(() {
          _previewPlayer = player;
          _previewPosition = Duration.zero;
          _isPreviewPlaying = false;
        });
      }
    } catch (e) {
      debugPrint('Error preparing audio preview: $e');
      await player.dispose();
      if (mounted) {
        showIslandPopup(
          context: context,
          message: 'Failed to load audio preview',
          icon: Icons.error_outline,
        );
      }
    }
  }

  Future<void> _disposePreviewPlayer() async {
    await _previewPlayer?.stop();
    await _previewPlayer?.dispose();
    _previewPlayer = null;
    _previewPosition = Duration.zero;
    _isPreviewPlaying = false;
  }

  void _togglePreviewPlayback() async {
    if (_previewPlayer == null || widget.isUploading) return;
    if (_isPreviewPlaying) {
      await _previewPlayer!.pause();
      setState(() => _isPreviewPlaying = false);
    } else {
      await _previewPlayer!.resume();
      setState(() => _isPreviewPlaying = true);
    }
  }

  void _stopPreviewPlayback() {
    _previewPlayer?.pause();
    _previewPlayer?.seek(Duration.zero);
    if (mounted) {
      setState(() {
        _isPreviewPlaying = false;
        _previewPosition = Duration.zero;
      });
    }
  }

  Future<void> _discardPendingAudio() async {
    _stopPreviewPlayback();
    final path = _pendingAudioPath;
    setState(() {
      _pendingAudioPath = null;
      _pendingAudioDuration = null;
    });
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _sendPendingAudio() async {
    if (_pendingAudioPath == null ||
        _pendingAudioDuration == null ||
        widget.onSendAudio == null) {
      return;
    }

    final path = _pendingAudioPath!;
    final duration = _pendingAudioDuration!;

    try {
      _stopPreviewPlayback();
      await widget.onSendAudio!(path, duration);
      await _disposePreviewPlayer();
      if (mounted) {
        setState(() {
          _pendingAudioPath = null;
          _pendingAudioDuration = null;
        });
      }
    } catch (_) {
      await _preparePreview(path, duration);
    }
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: DesignTokens.iconLG,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXS),
          Text(
            label,
            style: TextStyle(
              fontSize: DesignTokens.fontSizeXS,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
