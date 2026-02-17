// lib/widgets/story_widgets/viewer/story_controls.dart

import 'package:flutter/material.dart';
import 'package:freegram/models/story_media_model.dart';
import 'package:freegram/utils/haptic_helper.dart';

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
  final bool isLastStoryInTray;

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
    this.isLastStoryInTray = false,
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

    // Use HapticHelper.lightImpact() for skips as per optimization plan
    HapticHelper.lightImpact();

    // Left 1/3: Previous story (same user)
    if (tapX < screenWidth / 3) {
      widget.onPreviousStory?.call();
    }
    // Right 2/3: Next story (same user)
    // Note: Using > screenWidth / 3 to cover right 2/3 of screen
    else if (tapX > screenWidth / 3) {
      if (widget.isLastStoryInTray) {
        // Distinct haptic for end of tray
        HapticHelper.heavyImpact();
      }
      widget.onNextStory?.call();
    }
  }

  void _handleHorizontalSwipe(BuildContext context, DragEndDetails details) {
    // CRITICAL FIX: Don't handle swipe during long press
    if (_isLongPressing) {
      debugPrint('StoryControls: Ignoring swipe - long press is active');
      return;
    }

    if (details.primaryVelocity == null) return;

    // Medium impact for user navigation (switching users)
    HapticHelper.mediumImpact();

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
    // Currently just tracking for swipe detection
  }

  void _handleVerticalSwipe(BuildContext context, DragEndDetails details) {
    // CRITICAL FIX: Don't handle swipe during long press
    if (_isLongPressing) {
      debugPrint('StoryControls: Ignoring swipe - long press is active');
      return;
    }

    if (details.primaryVelocity == null) return;

    HapticHelper.mediumImpact();

    // Swipe up: Focus on reply text field
    if (details.primaryVelocity! < -500) {
      widget.onShowReplyBar?.call();
    }
    // Swipe down: Close viewer
    else if (details.primaryVelocity! > 500) {
      widget.onClose?.call();
    }
  }

  void _handleLongPressStart(BuildContext context) {
    _isLongPressing = true;
    _hasHandledLongPress = true;

    HapticHelper.heavyImpact();
    widget.onTogglePause?.call();
  }

  void _handleLongPressEnd(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isLongPressing = false;
        });
      }
    });

    if (widget.isPaused) {
      HapticHelper.mediumImpact();
      widget.onTogglePause?.call();
    }
  }
}
