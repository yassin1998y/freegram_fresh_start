import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/theme/design_tokens.dart';

class PulseAvatar extends StatefulWidget {
  final String? photoUrl;
  final double size;
  final bool showAvatar;

  const PulseAvatar({
    super.key,
    required this.photoUrl,
    this.size = 100,
    this.showAvatar = true,
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
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
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
                  color: SemanticColors.primary(context)
                      .withValues(alpha: _opacityAnimation.value),
                  border: Border.all(
                    color: SemanticColors.primary(context).withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
              );
            },
          ),
          // Avatar
          if (widget.showAvatar)
            Container(
              width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const Icon(Icons.person, color: Colors.white70, size: 40),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.person, color: Colors.white70, size: 40),
                    )
                  : const Icon(Icons.person, color: Colors.white70, size: 40),
            ),
          ),
        ],
      ),
    );
  }
}
