import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class GiftRevealModal extends StatefulWidget {
  final String animationUrl;
  final VoidCallback onComplete;

  const GiftRevealModal({
    super.key,
    required this.animationUrl,
    required this.onComplete,
  });

  @override
  State<GiftRevealModal> createState() => _GiftRevealModalState();
}

class _GiftRevealModalState extends State<GiftRevealModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Glassmorphic Backdrop
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            color: Colors.black.withValues(alpha: 0.2), // Subtle tint
          ),
        ),
        // Lottie Animation
        Center(
          child: Lottie.asset(
            widget.animationUrl,
            controller: _controller,
            onLoaded: (composition) {
              _controller
                ..duration = composition.duration
                ..forward().whenComplete(() {
                  widget.onComplete();
                });
            },
            width: 300,
            height: 300,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}
