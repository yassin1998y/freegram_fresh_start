import 'dart:math';
import 'package:flutter/material.dart';
import 'package:freegram/blocs/game_bloc/game_bloc.dart';

class SpecialEffectsOverlay extends StatefulWidget {
  const SpecialEffectsOverlay({super.key, required this.child});
  final Widget child;

  @override
  SpecialEffectsOverlayState createState() => SpecialEffectsOverlayState();
}

class SpecialEffectsOverlayState extends State<SpecialEffectsOverlay> with TickerProviderStateMixin {
  final List<_Effect> _effects = [];

  void playEffect(AnimationEffect effect, Point<int> start, {List<Point<int>>? targets, double gemSize = 0}) {
    final startOffset = Offset(start.x * gemSize + gemSize / 2, start.y * gemSize + gemSize / 2);
    final targetOffsets = targets?.map((p) => Offset(p.x * gemSize + gemSize / 2, p.y * gemSize + gemSize / 2)).toList();

    final controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    final effectWidget = _Effect(
      key: UniqueKey(),
      type: effect,
      controller: controller,
      startOffset: startOffset,
      targets: targetOffsets,
      onCompleted: () {
        if (mounted) {
          setState(() {
            _effects.removeWhere((e) => e.controller == controller);
            controller.dispose();
          });
        } else {
          controller.dispose();
        }
      },
    );

    setState(() {
      _effects.add(effectWidget);
    });

    controller.forward();
  }

  void playScore(int score, Point<int> start, double gemSize) {
    final startOffset = Offset(start.x * gemSize + gemSize / 2, start.y * gemSize / 2); // Pop up from top of gem
    final controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this); // Faster animation
    final effectWidget = _Effect(
        key: UniqueKey(),
        type: AnimationEffect.score,
        controller: controller,
        startOffset: startOffset,
        score: score,
        onCompleted: () {
          if (mounted) {
            setState(() {
              _effects.removeWhere((e) => e.controller == controller);
              controller.dispose();
            });
          } else {
            controller.dispose();
          }
        }
    );
    setState(() => _effects.add(effectWidget));
    controller.forward();
  }


  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._effects,
      ],
    );
  }
}

class _Effect extends StatefulWidget {
  final AnimationEffect type;
  final AnimationController controller;
  final Offset startOffset;
  final List<Offset>? targets;
  final int? score;
  final VoidCallback onCompleted;

  const _Effect({
    super.key,
    required this.type,
    required this.controller,
    required this.startOffset,
    this.targets,
    this.score,
    required this.onCompleted,
  });

  @override
  __EffectState createState() => __EffectState();
}

class __EffectState extends State<_Effect> {
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animation = CurvedAnimation(parent: widget.controller, curve: Curves.easeInOut);
    widget.controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.type) {
      case AnimationEffect.bomb:
        return CustomPaint(
          painter: _BombPainter(animation: _animation, center: widget.startOffset),
          child: const SizedBox.expand(),
        );
      case AnimationEffect.lightning:
        return CustomPaint(
          painter: _LightningPainter(animation: _animation, start: widget.startOffset, targets: widget.targets ?? []),
          child: const SizedBox.expand(),
        );
      case AnimationEffect.score:
        return _ScorePainterWidget(
          animation: _animation,
          startOffset: widget.startOffset,
          score: widget.score ?? 0,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _BombPainter extends CustomPainter {
  final Animation<double> animation;
  final Offset center;
  _BombPainter({required this.animation, required this.center}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // Smoother curve for explosion
    final progress = Curves.easeOut.transform(animation.value);
    final radius = 100 * progress;
    final opacity = 1.0 - progress;

    final paint = Paint()
      ..color = Colors.orangeAccent.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15.0 * (1 - progress);

    final glowPaint = Paint()
      ..color = Colors.amber.withOpacity(opacity * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawCircle(center, radius, glowPaint);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _LightningPainter extends CustomPainter {
  final Animation<double> animation;
  final Offset start;
  final List<Offset> targets;
  _LightningPainter({required this.animation, required this.start, required this.targets}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    final paint = Paint()
      ..color = Colors.yellowAccent
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    for(final target in targets) {
      final currentPos = Offset.lerp(start, target, progress)!;
      canvas.drawLine(start, currentPos, glowPaint);
      canvas.drawLine(start, currentPos, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


class _ScorePainterWidget extends AnimatedWidget {
  final Offset startOffset;
  final int score;

  const _ScorePainterWidget({
    required Animation<double> animation,
    required this.startOffset,
    required this.score,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final value = animation.value;

    final curvedValue = Curves.easeOut.transform(value);
    final yOffset = -40 * curvedValue;
    final opacity = 1.0 - (value * 1.5).clamp(0.0, 1.0); // Fade out faster

    return Positioned(
      left: startOffset.dx - 10, // Center the text
      top: startOffset.dy + yOffset,
      child: Opacity(
        opacity: opacity,
        child: Text(
          '+$score',
          style: TextStyle(
              color: Colors.white,
              fontSize: 18, // Smaller text
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(blurRadius: 4, color: Colors.black54)
              ]
          ),
        ),
      ),
    );
  }
}