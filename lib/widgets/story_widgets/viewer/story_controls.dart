// lib/widgets/story_widgets/viewer/story_controls.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/models/story_media_model.dart';

/// Gesture controls for story viewer
/// Handles tap, swipe, and long-press gestures
class StoryControls extends StatelessWidget {
  final Widget child;
  final StoryMedia? currentStory;
  final bool isPaused;
  final VoidCallback? onNextStory;
  final VoidCallback? onPreviousStory;
  final VoidCallback? onNextUser;
  final VoidCallback? onPreviousUser;
  final VoidCallback? onTogglePause;
  final VoidCallback? onClose;
  final VoidCallback? onShowReplyBar;

  const StoryControls({
    Key? key,
    required this.child,
    this.currentStory,
    this.isPaused = false,
    this.onNextStory,
    this.onPreviousStory,
    this.onNextUser,
    this.onPreviousUser,
    this.onTogglePause,
    this.onClose,
    this.onShowReplyBar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => _handleTap(context, details),
      onHorizontalDragEnd: (details) => _handleHorizontalSwipe(context, details),
      onVerticalDragUpdate: _handleVerticalDragUpdate,
      onVerticalDragEnd: (details) => _handleVerticalSwipe(context, details),
      onLongPressStart: (_) => _handleLongPressStart(context),
      onLongPressEnd: (_) => _handleLongPressEnd(context),
      child: child,
    );
  }

  void _handleTap(BuildContext context, TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;

    // Provide refined haptic feedback - lighter for navigation
    HapticFeedback.selectionClick();

    // Left 1/3: Previous story (same user)
    if (tapX < screenWidth / 3) {
      onPreviousStory?.call();
    }
    // Right 2/3: Next story (same user)
    // Note: Using > screenWidth / 3 to cover right 2/3 of screen
    else if (tapX > screenWidth / 3) {
      onNextStory?.call();
    }
    // Note: Center area is now part of right zone for easier navigation
    // Pause is handled via long press only
  }

  void _handleHorizontalSwipe(BuildContext context, DragEndDetails details) {
    if (details.primaryVelocity == null) return;

    // Medium impact for user navigation (switching users)
    HapticFeedback.mediumImpact();

    // Swipe left: Next user's reel
    if (details.primaryVelocity! < -500) {
      onNextUser?.call();
    }
    // Swipe right: Previous user's reel
    else if (details.primaryVelocity! > 500) {
      onPreviousUser?.call();
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    // Visual feedback can be added here if needed
    // Currently just tracking for swipe detection
  }

  void _handleVerticalSwipe(BuildContext context, DragEndDetails details) {
    if (details.primaryVelocity == null) return;

    HapticFeedback.mediumImpact();

    // Swipe up: Focus on reply text field (reply bar is always visible)
    if (details.primaryVelocity! < -500) {
      onShowReplyBar?.call();
    }
    // Swipe down: Close viewer
    else if (details.primaryVelocity! > 500) {
      onClose?.call();
    }
  }

  void _handleLongPressStart(BuildContext context) {
    // Only pause for video stories - prevent navigation during long press
    if (currentStory != null && currentStory!.mediaType == 'video') {
      // Strong haptic for pause action
      HapticFeedback.heavyImpact();
      // Prevent any navigation while pausing
      onTogglePause?.call();
    }
  }

  void _handleLongPressEnd(BuildContext context) {
    // Only resume for video stories if paused - prevent navigation
    if (currentStory != null &&
        currentStory!.mediaType == 'video' &&
        isPaused) {
      // Medium haptic for resume
      HapticFeedback.mediumImpact();
      // Resume without navigation
      onTogglePause?.call();
    }
  }
}
