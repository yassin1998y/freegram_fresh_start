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

  static const double _swipeThreshold = 60.0;

  void _onSwipeDetected(bool isRight) {
    HapticFeedback.lightImpact();
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
          },
          onHorizontalDragEnd: (details) {
            if (_dragOffset.abs() > _swipeThreshold) {
              _onSwipeDetected(_dragOffset > 0);
            }
            _dragOffset = 0;
          },
          behavior: HitTestBehavior.translucent,
          child: widget.child,
        ),

        // Visual Arrow Overlay
        if (_showArrow)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showArrow ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(DesignTokens.spaceLG),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _arrowReverse
                        ? Icons.arrow_back_ios_new_rounded
                        : Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
