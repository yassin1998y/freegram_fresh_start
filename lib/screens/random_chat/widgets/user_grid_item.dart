import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/models/lounge_user.dart';
import 'package:freegram/theme/design_tokens.dart'; // Ensure this matches your project structure

class UserGridItem extends StatefulWidget {
  final LoungeUser user;
  final VoidCallback onTap;

  const UserGridItem({super.key, required this.user, required this.onTap});

  @override
  State<UserGridItem> createState() => _UserGridItemState();
}

class _UserGridItemState extends State<UserGridItem>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Press Animation (1.0 -> 0.96)
    _pressController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    // Pulse Animation for Online Dot
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(seconds: 1, milliseconds: 500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    HapticFeedback.lightImpact();
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _pressController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161618), // Dark Surface
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2A2A2C), width: 1.0),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Image with CachedNetworkImage
              Hero(
                tag: 'user_${widget.user.id}',
                child: CachedNetworkImage(
                  imageUrl: widget.user.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    decoration: Containers.glassDecoration(context),
                    child: const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white24),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.white10,
                    child: const Icon(Icons.person, color: Colors.white24),
                  ),
                ),
              ),

              // 2. Gradient Overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.5, 1.0],
                  ),
                ),
              ),

              // 3. User Info
              Positioned(
                left: 12,
                bottom: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${widget.user.flagEmoji} ${widget.user.name}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${widget.user.age} • ${widget.user.distance ?? 'Nearby'}",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Glowing Pulse Dot (Online Indicator)
              Positioned(
                top: 12,
                right: 12,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SemanticColors.success,
                        boxShadow: [
                          BoxShadow(
                            color: SemanticColors.success
                                .withValues(alpha: 0.6 * _pulseController.value),
                            blurRadius: 8 * _pulseController.value,
                            spreadRadius: 2 * _pulseController.value,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserGridItemSkeleton extends StatefulWidget {
  const UserGridItemSkeleton({super.key});

  @override
  State<UserGridItemSkeleton> createState() => _UserGridItemSkeletonState();
}

class _UserGridItemSkeletonState extends State<UserGridItemSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
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
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161618),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2A2A2C), width: 1.0),
          ),
          child: Stack(
            children: [
              // Shimmer Gradient Placeholder
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.05),
                        Colors.white.withValues(alpha: 0.1),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                      begin: Alignment(-1.0 + (_controller.value * 2), -0.5),
                      end: Alignment(0.0 + (_controller.value * 2), 0.5),
                      tileMode: TileMode.clamp,
                    ),
                  ),
                ),
              ),
              // Name Bar
              Positioned(
                left: 12,
                bottom: 30,
                child: Container(
                  width: 80,
                  height: 16,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              // Subtext Bar
              Positioned(
                left: 12,
                bottom: 10,
                child: Container(
                  width: 50,
                  height: 12,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
