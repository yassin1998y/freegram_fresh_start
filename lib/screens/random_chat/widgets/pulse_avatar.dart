import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PulseAvatar extends StatefulWidget {
  final String? photoUrl;
  final double size;

  const PulseAvatar({
    super.key,
    required this.photoUrl,
    this.size = 100,
  });

  @override
  State<PulseAvatar> createState() => _PulseAvatarState();
}

class _PulseAvatarState extends State<PulseAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.3, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.5,
      height: widget.size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse Effect
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: widget.size * _scaleAnimation.value,
                height: widget.size * _scaleAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00BFA5)
                      .withValues(alpha: _opacityAnimation.value),
                  border: Border.all(
                    color: const Color(0xFF00BFA5).withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
              );
            },
          ),
          // Avatar
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: widget.photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: widget.photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const Icon(Icons.person, color: Colors.white70),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.person, color: Colors.white70),
                    )
                  : const Icon(Icons.person, color: Colors.white70, size: 40),
            ),
          ),
        ],
      ),
    );
  }
}
