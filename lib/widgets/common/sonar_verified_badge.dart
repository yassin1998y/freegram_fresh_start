// lib/widgets/common/sonar_verified_badge.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Sonar Pulse Verified Badge
/// A pulsing animation badge that indicates verified accounts
class SonarVerifiedBadge extends StatefulWidget {
  final double? size;

  const SonarVerifiedBadge({
    Key? key,
    this.size,
  }) : super(key: key);

  @override
  State<SonarVerifiedBadge> createState() => _SonarVerifiedBadgeState();
}

class _SonarVerifiedBadgeState extends State<SonarVerifiedBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? DesignTokens.iconSM;
    final coreRadius = size / 2;

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // The Pulse - animated outer ring
              Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SonarPulseTheme.primaryAccent.withOpacity(0.2),
                  ),
                ),
              ),
              // The Core - static checkmark
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SonarPulseTheme.primaryAccent,
                ),
                child: Icon(
                  Icons.check,
                  size: coreRadius,
                  color: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
