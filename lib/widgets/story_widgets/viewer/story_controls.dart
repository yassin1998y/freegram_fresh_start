// lib/widgets/story_widgets/viewer/story_controls.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:freegram/models/story_media_model.dart';

/// Gesture controls for story viewer
/// Handles tap, swipe, and long-press gestures
class StoryControls extends StatefulWidget {
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
  State<StoryControls> createState() => _StoryControlsState();
}

class _StoryControlsState extends State<StoryControls> {
  // CRITICAL FIX: Track long press state to prevent tap actions during long press
  bool _isLongPressing = false;
  bool _hasHandledLongPress = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => _handleTapDown(context, details),
      onTapUp: (details) => _handleTapUp(context, details),
      onHorizontalDragEnd: (details) =>
          _handleHorizontalSwipe(context, details),
      onVerticalDragUpdate: _handleVerticalDragUpdate,
      onVerticalDragEnd: (details) => _handleVerticalSwipe(context, details),
      onLongPressStart: (_) => _handleLongPressStart(context),
      onLongPressEnd: (_) => _handleLongPressEnd(context),
      child: widget.child,
    );
  }

  void _handleTapDown(BuildContext context, TapDownDetails details) {
    // CRITICAL FIX: Reset long press state when new tap starts
    _hasHandledLongPress = false;
  }

  void _handleTapUp(BuildContext context, TapUpDetails details) {
    // CRITICAL FIX: Don't handle tap if long press is active or was just handled
    if (_isLongPressing || _hasHandledLongPress) {
      debugPrint('StoryControls: Ignoring tap - long press is active');
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;

    // Provide refined haptic feedback - lighter for navigation
    HapticFeedback.selectionClick();

    // Left 1/3: Previous story (same user)
    if (tapX < screenWidth / 3) {
      widget.onPreviousStory?.call();
    }
    // Right 2/3: Next story (same user)
    // Note: Using > screenWidth / 3 to cover right 2/3 of screen
    else if (tapX > screenWidth / 3) {
      widget.onNextStory?.call();
    }
    // Note: Center area is now part of right zone for easier navigation
    // Pause is handled via long press only
  }

  void _handleHorizontalSwipe(BuildContext context, DragEndDetails details) {
    // CRITICAL FIX: Don't handle swipe during long press
    if (_isLongPressing) {
      debugPrint('StoryControls: Ignoring swipe - long press is active');
      return;
    }

    if (details.primaryVelocity == null) return;

    // Medium impact for user navigation (switching users)
    HapticFeedback.mediumImpact();

    // Swipe left: Next user's reel
    if (details.primaryVelocity! < -500) {
      widget.onNextUser?.call();
    }
    // Swipe right: Previous user's reel
    else if (details.primaryVelocity! > 500) {
      widget.onPreviousUser?.call();
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    // Visual feedback can be added here if needed
    // Currently just tracking for swipe detection
  }

  void _handleVerticalSwipe(BuildContext context, DragEndDetails details) {
    // CRITICAL FIX: Don't handle swipe during long press
    if (_isLongPressing) {
      debugPrint('StoryControls: Ignoring swipe - long press is active');
      return;
    }

    if (details.primaryVelocity == null) return;

    HapticFeedback.mediumImpact();

    // Swipe up: Focus on reply text field (reply bar is always visible)
    if (details.primaryVelocity! < -500) {
      widget.onShowReplyBar?.call();
    }
    // Swipe down: Close viewer
    else if (details.primaryVelocity! > 500) {
      widget.onClose?.call();
    }
  }

  void _handleLongPressStart(BuildContext context) {
    // CRITICAL FIX: Mark long press as active to prevent tap actions
    _isLongPressing = true;
    _hasHandledLongPress = true;

    // Only pause for video stories - prevent navigation during long press
    if (widget.currentStory != null &&
        widget.currentStory!.mediaType == 'video') {
      // Strong haptic for pause action
      HapticFeedback.heavyImpact();
      // Prevent any navigation while pausing
      widget.onTogglePause?.call();
    } else if (widget.currentStory != null &&
        widget.currentStory!.mediaType == 'image') {
      // CRITICAL FIX: For images, also pause (stop auto-advance)
      HapticFeedback.heavyImpact();
      widget.onTogglePause?.call();
    }
  }

  void _handleLongPressEnd(BuildContext context) {
    // CRITICAL FIX: Reset long press state after a delay to prevent immediate tap
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isLongPressing = false;
        });
      }
    });

    // Only resume for video stories if paused - prevent navigation
    if (widget.currentStory != null &&
        widget.currentStory!.mediaType == 'video' &&
        widget.isPaused) {
      // Medium haptic for resume
      HapticFeedback.mediumImpact();
      // Resume without navigation
      widget.onTogglePause?.call();
    } else if (widget.currentStory != null &&
        widget.currentStory!.mediaType == 'image' &&
        widget.isPaused) {
      // CRITICAL FIX: Resume images too
      HapticFeedback.mediumImpact();
      widget.onTogglePause?.call();
    }
  }
}
