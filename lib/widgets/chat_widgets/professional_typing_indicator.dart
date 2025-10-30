import 'dart:math';

import 'package:flutter/material.dart';
import 'package:freegram/utils/chat_presence_constants.dart';

/// Professional typing indicator with animated bouncing dots
/// Used consistently across chat list and chat screen
class ProfessionalTypingIndicator extends StatelessWidget {
  final Color? color;
  final double fontSize;

  const ProfessionalTypingIndicator({
    super.key,
    this.color,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? ChatPresenceConstants.typingColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ChatPresenceConstants.labelTyping.replaceAll('...', ''),
          style: TextStyle(
            color: effectiveColor,
            fontSize: fontSize,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        _BouncingDot(delay: 0, color: effectiveColor),
        const SizedBox(width: 2),
        _BouncingDot(delay: 100, color: effectiveColor),
        const SizedBox(width: 2),
        _BouncingDot(delay: 200, color: effectiveColor),
      ],
    );
  }
}

/// Animated bouncing dot for typing indicator
class _BouncingDot extends StatefulWidget {
  final int delay;
  final Color color;

  const _BouncingDot({
    required this.delay,
    required this.color,
  });

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Start animation after delay
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final animatedValue = (_controller.value * 2 * pi);
        final yOffset = sin(animatedValue) * 2;

        return Transform.translate(
          offset: Offset(0, yOffset),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
