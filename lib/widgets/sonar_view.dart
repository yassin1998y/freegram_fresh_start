import 'dart:math';
import 'package:flutter/material.dart';

class SonarView extends StatefulWidget {
  final bool isScanning;
  final List<Widget> foundUserAvatars;
  final Widget centerAvatar;
  final AnimationController unleashController;
  // **NEW**: A controller for the "user found" ripple effect.
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
  // **NEW**: Animation for the discovery ripple.
  late Animation<double> _discoveryAnimation;

  @override
  void initState() {
    super.initState();
    _sonarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _sonarAnimation = CurvedAnimation(
      parent: _sonarController,
      curve: Curves.easeOut,
    );

    _unleashAnimation = CurvedAnimation(
      parent: widget.unleashController,
      curve: Curves.fastOutSlowIn,
    );

    // **NEW**: Set up the discovery animation.
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
    final theme = Theme.of(context);
    
    return AspectRatio(
      aspectRatio: 1.0,
      child: CustomPaint(
        painter: SonarPainter(
          sonarAnimation: _sonarAnimation,
          unleashAnimation: _unleashAnimation,
          discoveryAnimation: _discoveryAnimation,
          primaryColor: theme.colorScheme.primary,
          secondaryColor: theme.colorScheme.secondary,
          discoveryColor: theme.colorScheme.tertiary ?? theme.colorScheme.primary,
        ),
        child: Stack(
          children: [
            Center(child: widget.centerAvatar),
            ...widget.foundUserAvatars,
          ],
        ),
      ),
    );
  }
}

class SonarPainter extends CustomPainter {
  final Animation<double> sonarAnimation;
  final Animation<double> unleashAnimation;
  // **NEW**: The discovery animation is now a parameter.
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
    ..color = primaryColor.withOpacity(0.5)
    ..style = PaintingStyle.stroke,
        super(repaint: Listenable.merge([sonarAnimation, unleashAnimation, discoveryAnimation]));

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2;

    // Draw static circles
    for (int i = 1; i <= 3; i++) {
      _sonarPaint.strokeWidth = 1.0;
      _sonarPaint.color = primaryColor.withOpacity(0.3);
      canvas.drawCircle(center, maxRadius * (i / 3), _sonarPaint);
    }

    // Draw scanning pulse
    if (sonarAnimation.value > 0) {
      _sonarPaint.strokeWidth = 2.5;
      _sonarPaint.color = primaryColor.withOpacity(1.0 - sonarAnimation.value);
      canvas.drawCircle(center, maxRadius * sonarAnimation.value, _sonarPaint);
    }

    // Draw unleash pulse
    if (unleashAnimation.value > 0) {
      _sonarPaint.strokeWidth = 4.0;
      _sonarPaint.color = secondaryColor.withOpacity(1.0 - unleashAnimation.value);
      canvas.drawCircle(center, maxRadius * unleashAnimation.value, _sonarPaint);
    }

    // Draw discovery pulse
    if (discoveryAnimation.value > 0) {
      _sonarPaint.strokeWidth = 5.0;
      _sonarPaint.color = discoveryColor.withOpacity(1.0 - discoveryAnimation.value);
      canvas.drawCircle(center, maxRadius * discoveryAnimation.value, _sonarPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SonarPainter oldDelegate) {
    return true;
  }
}
