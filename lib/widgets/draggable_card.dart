import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Enum to represent the swipe direction
enum SwipeDirection { left, right, up, none }

class DraggableCard extends StatefulWidget {
  final Widget child;
  final Function(SwipeDirection direction) onSwipe;
  final bool showTutorial;

  const DraggableCard({
    required Key key,
    required this.child,
    required this.onSwipe,
    this.showTutorial = false,
  }) : super(key: key);

  @override
  DraggableCardState createState() => DraggableCardState();
}

class DraggableCardState extends State<DraggableCard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _tutorialController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _tutorialFadeAnimation;
  Offset _dragPosition = Offset.zero;
  SwipeDirection _swipeDirection = SwipeDirection.none;
  DateTime? _lastTapTime;
  bool _isLongPressing = false;
  bool _hasHapticFired = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        setState(() {});
      });

    _tutorialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _tutorialFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _tutorialController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.showTutorial) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _tutorialController.repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tutorialController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DraggableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showTutorial != oldWidget.showTutorial) {
      if (widget.showTutorial) {
        _tutorialController.repeat(reverse: true);
      } else {
        _tutorialController.stop();
      }
    }
  }

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 300)) {
      // Double tap detected
      HapticFeedback.mediumImpact();
      _swipeDirection = SwipeDirection.right;
      _animateCardOffScreen();
    }
    _lastTapTime = now;
  }

  void _handleLongPressStart() {
    setState(() {
      _isLongPressing = true;
    });
    HapticFeedback.mediumImpact();
  }

  void _handleLongPressEnd() {
    setState(() {
      _isLongPressing = false;
    });
  }

  void _onPanStart(DragStartDetails details) {
    _hasHapticFired = false;
    _tutorialController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragPosition += details.delta;
      _updateSwipeDirection();

      // Haptic feedback at swipe threshold
      if (!_hasHapticFired) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        if (_dragPosition.dx.abs() > screenWidth / 6 ||
            _dragPosition.dy < -screenHeight / 6) {
          HapticFeedback.selectionClick();
          _hasHapticFired = true;
        }
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (_dragPosition.dx.abs() > screenWidth / 6 ||
        _dragPosition.dy < -screenHeight / 6) {
      HapticFeedback.lightImpact();
      _animateCardOffScreen();
    } else {
      _animateCardToCenter();
    }
  }

  void _updateSwipeDirection() {
    final previousDirection = _swipeDirection;

    if (_dragPosition.dy < -60 && _dragPosition.dx.abs() < 60) {
      _swipeDirection = SwipeDirection.up;
    } else if (_dragPosition.dx > 40) {
      _swipeDirection = SwipeDirection.right;
    } else if (_dragPosition.dx < -40) {
      _swipeDirection = SwipeDirection.left;
    } else {
      _swipeDirection = SwipeDirection.none;
    }

    // Haptic feedback when crossing direction threshold
    if (previousDirection == SwipeDirection.none &&
        _swipeDirection != SwipeDirection.none) {
      HapticFeedback.selectionClick();
    }
  }

  void _animateCardOffScreen() {
    double endDx = 0;
    double endDy = 0;

    switch (_swipeDirection) {
      case SwipeDirection.left:
        endDx = -500;
        break;
      case SwipeDirection.right:
        endDx = 500;
        break;
      case SwipeDirection.up:
        endDy = -800;
        break;
      case SwipeDirection.none:
        _animateCardToCenter();
        return;
    }

    _slideAnimation = Tween<Offset>(
      begin: _dragPosition,
      end: Offset(endDx, endDy),
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInQuad),
    );

    final originalSwipeDirection = _swipeDirection;
    _animationController.forward().then((_) {
      _animationController.reset();
      setState(() {
        _dragPosition = Offset.zero;
        _swipeDirection = SwipeDirection.none;
      });
      widget.onSwipe(originalSwipeDirection);
    });
  }

  void _animateCardToCenter() {
    _animationController.duration = const Duration(milliseconds: 400);

    _slideAnimation = Tween<Offset>(
      begin: _dragPosition,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward().then((_) {
      setState(() {
        _dragPosition = Offset.zero;
        _swipeDirection = SwipeDirection.none;
        _animationController.reset();
        _animationController.duration = const Duration(milliseconds: 300);
      });
    });
  }

  /// Public method to trigger the swipe animation from the parent widget.
  void triggerSwipe(SwipeDirection direction) {
    if (direction == SwipeDirection.none) return;
    setState(() {
      _swipeDirection = direction;
    });
    _animateCardOffScreen();
  }

  /// Public method to trigger a wiggle animation (for "not allowed" feedback)
  void triggerWiggle() {
    if (_animationController.isAnimating) return;

    const wiggleAmount = 15.0;
    const wiggleDuration = Duration(milliseconds: 80);

    // Create a wiggle sequence
    _animateWiggle(wiggleAmount, wiggleDuration);
  }

  void _animateWiggle(double amount, Duration duration) async {
    final startPosition = _dragPosition;

    // Right wiggle
    _slideAnimation = Tween<Offset>(
      begin: startPosition,
      end: Offset(amount, 0),
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.duration = duration;
    await _animationController.forward();
    _animationController.reset();

    // Left wiggle
    _slideAnimation = Tween<Offset>(
      begin: Offset(amount, 0),
      end: Offset(-amount, 0),
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    await _animationController.forward();
    _animationController.reset();

    // Right wiggle (smaller)
    _slideAnimation = Tween<Offset>(
      begin: Offset(-amount, 0),
      end: Offset(amount * 0.5, 0),
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    await _animationController.forward();
    _animationController.reset();

    // Return to center
    _slideAnimation = Tween<Offset>(
      begin: Offset(amount * 0.5, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    await _animationController.forward();

    // Reset state
    if (mounted) {
      setState(() {
        _dragPosition = Offset.zero;
        _swipeDirection = SwipeDirection.none;
        _animationController.reset();
        _animationController.duration = const Duration(milliseconds: 300);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = _animationController.isAnimating
        ? _slideAnimation.value
        : _dragPosition;
    final screenWidth = MediaQuery.of(context).size.width;

    // Amplified rotation for more dramatic effect
    final angle = (position.dx / screenWidth) * 0.6;

    final scale = _dragPosition == Offset.zero
        ? 1.0
        : 1 - (_dragPosition.distance / (screenWidth * 2)).clamp(0.0, 0.05);

    // Dynamic shadow based on drag distance
    final shadowDepth = _dragPosition == Offset.zero
        ? 8.0
        : 8.0 + (_dragPosition.distance / 50).clamp(0.0, 12.0);

    return GestureDetector(
      onTap: _handleTap,
      onLongPressStart: (_) => _handleLongPressStart(),
      onLongPressEnd: (_) => _handleLongPressEnd(),
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: position,
        child: Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    spreadRadius: 0,
                    blurRadius: shadowDepth,
                    offset: Offset(0, shadowDepth / 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  widget.child,
                  _buildActionOverlay(),
                  if (widget.showTutorial) _buildTutorialOverlay(),
                  if (_isLongPressing) _buildLongPressOverlay(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialOverlay() {
    return AnimatedBuilder(
      animation: _tutorialFadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _tutorialFadeAnimation.value * 0.9,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.black.withValues(alpha: 0.7),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTutorialHint(
                          Icons.arrow_back, 'Swipe Left\nto Pass', Colors.red),
                      _buildTutorialHint(Icons.arrow_upward,
                          'Swipe Up\nSuper Like', Colors.blue),
                      _buildTutorialHint(Icons.arrow_forward,
                          'Swipe Right\nto Like', Colors.green),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '💡 Double tap to quickly like',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTutorialHint(IconData icon, String text, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 48),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLongPressOverlay() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.3),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Tap info button to see full profile',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildActionOverlay() {
    Color color;
    String text;
    IconData icon;

    switch (_swipeDirection) {
      case SwipeDirection.right:
        color = Colors.green;
        text = "LIKE";
        icon = Icons.favorite;
        break;
      case SwipeDirection.left:
        color = Colors.red;
        text = "NOPE";
        icon = Icons.close;
        break;
      case SwipeDirection.up:
        color = Colors.blue;
        text = "SUPER";
        icon = Icons.star;
        break;
      case SwipeDirection.none:
        return const SizedBox.shrink();
    }

    final opacity = min(_dragPosition.distance / 100, 1.0);

    return Opacity(
      opacity: opacity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.black.withValues(alpha: 0.3),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 40),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
