// lib/widgets/chat_widgets/celebration_match_badge.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:intl/intl.dart';
import 'dart:math';

/// Enhanced match badge with celebration animation
/// Improvement #27 - Enhance match badge with celebration animation and confetti
class CelebrationMatchBadge extends StatefulWidget {
  final DateTime timestamp;

  const CelebrationMatchBadge({
    super.key,
    required this.timestamp,
  });

  @override
  State<CelebrationMatchBadge> createState() => _CelebrationMatchBadgeState();
}

class _CelebrationMatchBadgeState extends State<CelebrationMatchBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  final List<_Confetti> _confettiParticles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: -0.1,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Generate confetti particles
    for (int i = 0; i < 30; i++) {
      _confettiParticles.add(_Confetti(
        color: _getRandomColor(),
        angle: _random.nextDouble() * 2 * pi,
        distance: 50 + _random.nextDouble() * 100,
        rotation: _random.nextDouble() * pi,
        size: 4 + _random.nextDouble() * 6,
      ));
    }

    _controller.forward();
  }

  Color _getRandomColor() {
    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.orange,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat.yMMMd().format(widget.timestamp);

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Confetti particles
              ..._confettiParticles.map((confetti) {
                final progress = _controller.value;
                final x = cos(confetti.angle) * confetti.distance * progress;
                final y = sin(confetti.angle) * confetti.distance * progress -
                    (progress * 20); // Slight upward motion
                final opacity = 1.0 - progress;

                return Positioned(
                  left: x,
                  top: y,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: confetti.rotation * progress * 4,
                      child: Container(
                        width: confetti.size,
                        height: confetti.size,
                        decoration: BoxDecoration(
                          color: confetti.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),

              // Main badge
              Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform.rotate(
                  angle: sin(_rotationAnimation.value * pi) * 0.05,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceLG,
                      vertical: DesignTokens.spaceMD,
                    ),
                    margin: const EdgeInsets.symmetric(
                      vertical: DesignTokens.spaceLG,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.pink.shade400,
                          Colors.red.shade400,
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusXL),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: DesignTokens.spaceSM),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'It\'s a Match!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: DesignTokens.fontSizeLG,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: DesignTokens.fontSizeXS,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: DesignTokens.spaceSM),
                        const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Confetti {
  final Color color;
  final double angle;
  final double distance;
  final double rotation;
  final double size;

  _Confetti({
    required this.color,
    required this.angle,
    required this.distance,
    required this.rotation,
    required this.size,
  });
}























