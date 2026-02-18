import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SonarView extends StatefulWidget {
  final bool isScanning;
  final List<Widget> foundUserAvatars;
  final Widget centerAvatar;
  final AnimationController unleashController;
  final AnimationController discoveryController;

  const SonarView({
    super.key,
    required this.isScanning,
    required this.centerAvatar,
    required this.unleashController,
    required this.discoveryController,
    this.foundUserAvatars = const [],
  });

  @override
  State<SonarView> createState() => _SonarViewState();
}

class _SonarViewState extends State<SonarView> with TickerProviderStateMixin {
  late AnimationController _sonarController;
  late Animation<double> _sonarAnimation;
  late Animation<double> _unleashAnimation;
  late Animation<double> _discoveryAnimation;

  // Track last value to detect cycle completion for haptic feedback
  double _lastHapticValue = 0.0;

  @override
  void initState() {
    super.initState();
    _sonarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Haptic Heartbeat Integration
    _sonarController.addListener(() {
      if (widget.isScanning) {
        // Trigger haptic when the loop restarts (value wraps near 0)
        if (_sonarController.value < 0.05 && _lastHapticValue > 0.95) {
          HapticFeedback.lightImpact();
        }
        _lastHapticValue = _sonarController.value;
      }
    });

    _sonarAnimation = CurvedAnimation(
      parent: _sonarController,
      curve: Curves.easeOut,
    );

    _unleashAnimation = CurvedAnimation(
      parent: widget.unleashController,
      curve: Curves.fastOutSlowIn,
    );

    _discoveryAnimation = CurvedAnimation(
      parent: widget.discoveryController,
      curve: Curves.easeInOut,
    );

    if (widget.isScanning) {
      _sonarController.repeat();
    }
  }

  @override
  void didUpdateWidget(SonarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !_sonarController.isAnimating) {
      _sonarController.repeat();
    } else if (!widget.isScanning && _sonarController.isAnimating) {
      _sonarController.stop();
    }
  }

  @override
  void dispose() {
    _sonarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      // OPTIMIZATION: RepaintBoundary prevents full screen repaints during animation
      child: RepaintBoundary(
        child: CustomPaint(
          painter: SonarPainter(
            sonarAnimation: _sonarAnimation,
            unleashAnimation: _unleashAnimation,
            discoveryAnimation: _discoveryAnimation,
            // Brand Green: 0xFF00BFA5
            primaryColor: const Color(0xFF00BFA5),
            secondaryColor: const Color(0xFF00BFA5).withValues(alpha: 0.5),
            discoveryColor: const Color(0xFF00BFA5),
          ),
          child: Stack(
            children: [
              Center(child: widget.centerAvatar),
              ...widget.foundUserAvatars,
            ],
          ),
        ),
      ),
    );
  }
}

class SonarPainter extends CustomPainter {
  final Animation<double> sonarAnimation;
  final Animation<double> unleashAnimation;
  final Animation<double> discoveryAnimation;
  final Paint _sonarPaint;
  final Color primaryColor;
  final Color secondaryColor;
  final Color discoveryColor;

  SonarPainter({
    required this.sonarAnimation,
    required this.unleashAnimation,
    required this.discoveryAnimation,
    required this.primaryColor,
    required this.secondaryColor,
    required this.discoveryColor,
  })  : _sonarPaint = Paint()
          ..color = primaryColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke,
        super(
            repaint: Listenable.merge(
                [sonarAnimation, unleashAnimation, discoveryAnimation]));

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    // Draw static circles with Brand Green low opacity
    for (int i = 1; i <= 3; i++) {
      _sonarPaint.strokeWidth = 1.0;
      _sonarPaint.color = primaryColor.withValues(alpha: 0.1);
      canvas.drawCircle(center, maxRadius * (i / 3), _sonarPaint);
    }

    // Draw scanning pulse
    if (sonarAnimation.value > 0) {
      _sonarPaint.strokeWidth = 2.5;
      _sonarPaint.color =
          primaryColor.withValues(alpha: 1.0 - sonarAnimation.value);
      canvas.drawCircle(center, maxRadius * sonarAnimation.value, _sonarPaint);
    }

    // Draw unleash pulse
    if (unleashAnimation.value > 0) {
      _sonarPaint.strokeWidth = 4.0;
      _sonarPaint.color =
          secondaryColor.withValues(alpha: 1.0 - unleashAnimation.value);
      canvas.drawCircle(
          center, maxRadius * unleashAnimation.value, _sonarPaint);
    }

    // Draw discovery pulse
    if (discoveryAnimation.value > 0) {
      _sonarPaint.strokeWidth = 5.0;
      _sonarPaint.color =
          discoveryColor.withValues(alpha: 1.0 - discoveryAnimation.value);
      canvas.drawCircle(
          center, maxRadius * discoveryAnimation.value, _sonarPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SonarPainter oldDelegate) {
    return true;
  }
}
