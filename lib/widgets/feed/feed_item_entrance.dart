import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

class FeedItemEntrance extends StatefulWidget {
  final Widget child;
  final int index;

  const FeedItemEntrance({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<FeedItemEntrance> createState() => _FeedItemEntranceState();
}

class _FeedItemEntranceState extends State<FeedItemEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2), // Slide up from 20% below
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: AnimationTokens.snappyCurve),
      ),
    );

    // Staggered start based on index (capped to avoid very long delays)
    Future.delayed(Duration(milliseconds: (widget.index % 10) * 100), () {
      if (mounted) {
        _controller.forward();
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
        return Opacity(
          opacity: _opacityAnimation.value,
          child: FractionalTranslation(
            translation: _slideAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
