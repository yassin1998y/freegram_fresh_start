import 'package:flutter/material.dart';
import 'package:freegram/utils/haptic_helper.dart';

class LikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onLike;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const LikeButton({
    super.key,
    required this.isLiked,
    required this.onLike,
    this.size = 24.0,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != oldWidget.isLiked && widget.isLiked) {
      _animate();
    }
  }

  void _animate() {
    _controller.forward().then((_) => _controller.reverse());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticHelper.selection();
        widget.onLike();
        if (!widget.isLiked) {
          _animate();
        }
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Icon(
          widget.isLiked ? Icons.favorite : Icons.favorite_border,
          color: widget.isLiked
              ? (widget.activeColor ?? Colors.red)
              : (widget.inactiveColor ?? Colors.grey),
          size: widget.size,
        ),
      ),
    );
  }
}
