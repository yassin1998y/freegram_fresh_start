import 'package:flutter/material.dart';
import 'dart:ui';

class GuideStep {
  final GlobalKey? targetKey;
  final String description;
  final Alignment fallbackAlignment;

  const GuideStep({
    required this.description,
    this.targetKey,
    this.fallbackAlignment = Alignment.center,
  });
}

class GuidedOverlay extends StatefulWidget {
  final List<GuideStep> steps;
  final VoidCallback onFinish;

  const GuidedOverlay({super.key, required this.steps, required this.onFinish});

  @override
  State<GuidedOverlay> createState() => _GuidedOverlayState();
}

class _GuidedOverlayState extends State<GuidedOverlay>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Offset _targetCenter(Size screenSize) {
    final step = widget.steps[_index];
    final key = step.targetKey;
    if (key != null && key.currentContext != null) {
      final box = key.currentContext!.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final offset = box.localToGlobal(Offset.zero);
        final size = box.size;
        return offset + Offset(size.width / 2, size.height / 2);
      }
    }
    final align = step.fallbackAlignment;
    return Offset(
      (align.x + 1) / 2 * screenSize.width,
      (align.y + 1) / 2 * screenSize.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final center = _targetCenter(screenSize);

    return Positioned.fill(
      child: Stack(
        children: [
          // Blur only OUTSIDE the circular hole
          Positioned.fill(
            child: ClipPath(
              clipper: _HoleInverseClipper(center: center, radius: 60),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // Dim scrim with circular cutout at the focus center (no blur inside)
          Positioned.fill(
            child: CustomPaint(
              painter: _ScrimWithHolePainter(center: center, radius: 60),
            ),
          ),
          // Tap handler + content
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () {
                  if (_index < widget.steps.length - 1) {
                    setState(() => _index++);
                  } else {
                    widget.onFinish();
                  }
                },
                child: Stack(
                  children: [
                    // Pulsing focus outline
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) {
                        final radius = 60 + 6 * _pulse.value;
                        return CustomPaint(
                          painter: _PulseCirclePainter(
                              center: center, radius: radius),
                          child: const SizedBox.expand(),
                        );
                      },
                    ),
                    // Centered, box-less description text
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.steps[_index].description,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w600,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tap anywhere to continue',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: Colors.white70,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black45,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrimWithHolePainter extends CustomPainter {
  final Offset center;
  final double radius;

  _ScrimWithHolePainter({required this.center, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPath = Path()
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    scrimPath.fillType = PathFillType.evenOdd;

    final paint = Paint()..color = Colors.black.withOpacity(0.55);
    canvas.drawPath(scrimPath, paint);
  }

  @override
  bool shouldRepaint(covariant _ScrimWithHolePainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.radius != radius;
  }
}

class _HoleInverseClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  _HoleInverseClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    path.fillType = PathFillType.evenOdd; // keep outside, cut the circle
    return path;
  }

  @override
  bool shouldReclip(covariant _HoleInverseClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}

class _PulseCirclePainter extends CustomPainter {
  final Offset center;
  final double radius;

  _PulseCirclePainter({required this.center, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withOpacity(0.9);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = Colors.white.withOpacity(0.2);

    canvas.drawCircle(center, radius + 2, glowPaint);
    canvas.drawCircle(center, radius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _PulseCirclePainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.radius != radius;
  }
}
