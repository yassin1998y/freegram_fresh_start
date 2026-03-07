import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_event.dart';
import 'package:freegram/theme/design_tokens.dart';

class SwipeToSkipDetector extends StatefulWidget {
  final Widget child;

  const SwipeToSkipDetector({super.key, required this.child});

  @override
  State<SwipeToSkipDetector> createState() => _SwipeToSkipDetectorState();
}

class _SwipeToSkipDetectorState extends State<SwipeToSkipDetector> {
  double _dragOffset = 0;
  bool _showArrow = false;
  bool _arrowReverse = false; // true for swipe left, false for swipe right
  bool _thresholdCrossedHapticTriggered = false;

  static const double _swipeThreshold = 60.0;
  static const double _velocityThreshold = 500.0;

  void _onSwipeAction(bool isRight) {
    context.read<RandomChatBloc>().add(const RandomChatStartSearching());

    setState(() {
      _showArrow = true;
      _arrowReverse = !isRight;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _showArrow = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            _dragOffset += details.primaryDelta ?? 0;

            // Trigger haptic physical validation exactly when threshold is crossed
            if (_dragOffset.abs() > _swipeThreshold &&
                !_thresholdCrossedHapticTriggered) {
              HapticFeedback.mediumImpact();
              _thresholdCrossedHapticTriggered = true;
            } else if (_dragOffset.abs() < _swipeThreshold) {
              _thresholdCrossedHapticTriggered = false;
            }
          },
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;

            // Swipe must be deliberate: exceed threshold AND have sufficient velocity
            if (_dragOffset.abs() > _swipeThreshold &&
                velocity.abs() > _velocityThreshold) {
              _onSwipeAction(_dragOffset > 0);
            }

            _dragOffset = 0;
            _thresholdCrossedHapticTriggered = false;
          },
          behavior: HitTestBehavior.translucent,
          child: widget.child,
        ),

        // Visual Arrow Overlay (Premium Feedback)
        if (_showArrow)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showArrow ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(DesignTokens.spaceLG),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.white12,
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Icon(
                    _arrowReverse
                        ? Icons.arrow_back_ios_new_rounded
                        : Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
