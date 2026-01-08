import 'package:flutter/material.dart';
import 'dart:math' as math;

class RadarScanAnimation extends StatefulWidget {
  final double size;
  final Color color;

  const RadarScanAnimation({
    super.key,
    this.size = 200,
    this.color = const Color(0xFF00BFA5),
  });

  @override
  State<RadarScanAnimation> createState() => _RadarScanAnimationState();
}

class _RadarScanAnimationState extends State<RadarScanAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RadarPainter(
              value: _controller.value,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double value;
  final Color color;

  _RadarPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final Paint paint = Paint()
      ..color = color.withOpacity(1.0 - value)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw expanding circle
    canvas.drawCircle(center, maxRadius * value, paint);

    // Draw a second expanding circle (offset)
    double secondValue = value - 0.5;
    if (secondValue < 0) secondValue += 1.0;

    final Paint paint2 = Paint()
      ..color = color.withOpacity(1.0 - secondValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, maxRadius * secondValue, paint2);

    // Scanner line
    final Paint linePaint = Paint()
      ..shader = SweepGradient(
        colors: [Colors.transparent, color.withOpacity(0.5)],
        startAngle: 0.0,
        endAngle: math.pi / 2,
        stops: const [0.0, 1.0],
        transform: GradientRotation(value * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawArc(
        Rect.fromCircle(center: center, radius: maxRadius),
        value * 2 * math.pi,
        math.pi / 2, // 90 degree sweep
        true,
        linePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}
