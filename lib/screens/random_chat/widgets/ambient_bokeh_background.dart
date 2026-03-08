import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class AmbientBokehBackground extends StatefulWidget {
  const AmbientBokehBackground({super.key});

  @override
  State<AmbientBokehBackground> createState() => _AmbientBokehBackgroundState();
}

class _AmbientBokehBackgroundState extends State<AmbientBokehBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_SparkleParticle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(20, (_) => _SparkleParticle());
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          for (var particle in _particles) {
            particle.update();
          }
          return CustomPaint(
            painter: _BokehPainter(_particles),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SparkleParticle {
  late double x, y, size, speedX, speedY;
  final Random random = Random();

  _SparkleParticle() {
    _reset();
    // Randomize initial positions across the screen
    x = random.nextDouble() * 2 - 1;
    y = random.nextDouble() * 2 - 1;
  }

  void _reset() {
    x = random.nextDouble() * 2 - 1; // -1 to 1 (screen coordinate system)
    y = random.nextDouble() > 0.5
        ? 1.2
        : -1.2; // Start slightly off-screen vertically
    size = 50 + random.nextDouble() * 100; // 50 to 150
    speedX = (random.nextDouble() - 0.5) * 0.005;
    speedY = (random.nextDouble() > 0.5 ? -1 : 1) *
        (0.002 + random.nextDouble() * 0.005);
  }

  void update() {
    x += speedX;
    y += speedY;

    if (x < -1.5 || x > 1.5 || y < -1.5 || y > 1.5) {
      _reset();
    }
  }
}

class _BokehPainter extends CustomPainter {
  final List<_SparkleParticle> particles;

  _BokehPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    for (var particle in particles) {
      // Map coordinate system (-1 to 1) to screen size
      final px = (particle.x + 1) / 2 * size.width;
      final py = (particle.y + 1) / 2 * size.height;
      canvas.drawCircle(Offset(px, py), particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
