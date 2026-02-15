// lib/widgets/reels/reel_caption_input_widget.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/common/keyboard_safe_area.dart';

/// Caption input widget for reels
/// Allows user to enter caption with hashtags and mentions
class ReelCaptionInputWidget extends StatelessWidget {
  final TextEditingController captionController;
  final VoidCallback? onSubmitted;

  const ReelCaptionInputWidget({
    Key? key,
    required this.captionController,
    this.onSubmitted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              Colors.black.withValues(alpha: DesignTokens.opacityHigh),
              Colors.black.withValues(alpha: DesignTokens.opacityHigh),
              Colors.transparent,
            ],
          ),
        ),
        child: KeyboardAwareInput(
          child: SafeArea(
            child: TextField(
              controller: captionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: DesignTokens.opacityMedium),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 
                  DesignTokens.opacityDisabled,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(DesignTokens.spaceMD),
              ),
              onSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
            ),
          ),
        ),
      ),
    );
  }
}
