// lib/widgets/reels/enhanced_reel_caption_input_widget.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/common/keyboard_safe_area.dart';

/// Enhanced caption input widget for reels with smart features
/// - Character counter with limit
/// - Hashtag highlighting
/// - Mention highlighting
/// - Real-time formatting
class EnhancedReelCaptionInputWidget extends StatefulWidget {
  final TextEditingController captionController;
  final VoidCallback? onSubmitted;
  final int maxCharacters;
  final bool showCharacterCount;
  final bool highlightHashtags;
  final bool highlightMentions;

  const EnhancedReelCaptionInputWidget({
    Key? key,
    required this.captionController,
    this.onSubmitted,
    this.maxCharacters = 2200,
    this.showCharacterCount = true,
    this.highlightHashtags = true,
    this.highlightMentions = true,
  }) : super(key: key);

  @override
  State<EnhancedReelCaptionInputWidget> createState() =>
      _EnhancedReelCaptionInputWidgetState();
}

class _EnhancedReelCaptionInputWidgetState
    extends State<EnhancedReelCaptionInputWidget> {
  int _characterCount = 0;
  int _hashtagCount = 0;
  int _mentionCount = 0;

  @override
  void initState() {
    super.initState();
    widget.captionController.addListener(_updateCounts);
    _updateCounts();
  }

  @override
  void dispose() {
    widget.captionController.removeListener(_updateCounts);
    super.dispose();
  }

  void _updateCounts() {
    if (!mounted) return;

    final text = widget.captionController.text;
    final hashtagRegex = RegExp(r'#(\w+)');
    final mentionRegex = RegExp(r'@(\w+)');

    setState(() {
      _characterCount = text.length;
      _hashtagCount = hashtagRegex.allMatches(text).length;
      _mentionCount = mentionRegex.allMatches(text).length;
    });
  }

  Color _getCharacterCountColor() {
    final remaining = widget.maxCharacters - _characterCount;
    if (remaining < 0) {
      return Colors.red;
    } else if (remaining < 100) {
      return Colors.orange;
    } else {
      return Colors.white.withOpacity(DesignTokens.opacityMedium);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOverLimit = _characterCount > widget.maxCharacters;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(DesignTokens.opacityHigh),
              Colors.black.withOpacity(DesignTokens.opacityHigh),
              Colors.transparent,
            ],
          ),
        ),
        child: KeyboardAwareInput(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Caption input field
                TextField(
                  controller: widget.captionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  maxLength: widget.maxCharacters,
                  buildCounter: (context,
                      {required currentLength, required isFocused, maxLength}) {
                    // Hide default counter, we'll show custom one
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Write a caption... #hashtags @mentions',
                    hintStyle: TextStyle(
                      color:
                          Colors.white.withOpacity(DesignTokens.opacityMedium),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(
                      DesignTokens.opacityDisabled,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMD),
                      borderSide: BorderSide.none,
                    ),
                    errorBorder: isOverLimit
                        ? OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusMD),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          )
                        : null,
                    contentPadding: const EdgeInsets.all(DesignTokens.spaceMD),
                  ),
                  onSubmitted: widget.onSubmitted != null
                      ? (_) => widget.onSubmitted!()
                      : null,
                ),
                const SizedBox(height: DesignTokens.spaceSM),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Hashtag and mention counts
                    Row(
                      children: [
                        if (_hashtagCount > 0) ...[
                          Icon(
                            Icons.tag,
                            size: 14,
                            color: Colors.blue.withOpacity(0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_hashtagCount',
                            style: TextStyle(
                              color: Colors.blue.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: DesignTokens.spaceMD),
                        ],
                        if (_mentionCount > 0) ...[
                          Icon(
                            Icons.alternate_email,
                            size: 14,
                            color: Colors.purple.withOpacity(0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_mentionCount',
                            style: TextStyle(
                              color: Colors.purple.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Character counter
                    if (widget.showCharacterCount)
                      Text(
                        '$_characterCount/${widget.maxCharacters}',
                        style: TextStyle(
                          color: _getCharacterCountColor(),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                // Warning message if over limit
                if (isOverLimit) ...[
                  const SizedBox(height: DesignTokens.spaceSM),
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Caption is ${_characterCount - widget.maxCharacters} characters too long',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
