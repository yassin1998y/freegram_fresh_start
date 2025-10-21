import 'dart:math';
import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';

// Model for a single particle
class Particle {
  final Color color;
  late Offset position;
  late double speed;
  late double direction;
  late double size;

  Particle({required this.color}) {
    final random = Random();
    speed = random.nextDouble() * 1.5 + 0.5; // Random speed
    direction = random.nextDouble() * 2 * pi; // Random direction
    size = random.nextDouble() * 2.0 + 1.0;  // Random size
    position = const Offset(0, 0);
  }
}

// Widget to render a burst of particles
class ParticleBurstWidget extends StatefulWidget {
  final int numberOfParticles;
  final Color baseColor;

  const ParticleBurstWidget({
    super.key,
    this.numberOfParticles = 15,
    required this.baseColor,
  });

  @override
  State<ParticleBurstWidget> createState() => _ParticleBurstWidgetState();
}

class _ParticleBurstWidgetState extends State<ParticleBurstWidget> {
  final List<Particle> particles = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.numberOfParticles; i++) {
      particles.add(Particle(color: widget.baseColor.withOpacity(Random().nextDouble() * 0.5 + 0.5)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoopAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) {
        return CustomPaint(
          painter: _ParticlePainter(particles: particles, progress: value),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint();

    for (var particle in particles) {
      final currentProgress = (progress * 2.0).clamp(0.0, 1.0);
      final distance = particle.speed * 30 * currentProgress;

      final newX = center.dx + cos(particle.direction) * distance;
      final newY = center.dy + sin(particle.direction) * distance;
      particle.position = Offset(newX, newY);

      paint.color = particle.color.withOpacity(1.0 - progress);
      canvas.drawCircle(particle.position, particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
