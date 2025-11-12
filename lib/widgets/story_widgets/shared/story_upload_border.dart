// lib/widgets/story_widgets/shared/story_upload_border.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Animated upload progress border for story cards
/// Displays a radial progress arc around the card to show upload progress
class StoryUploadBorder extends StatefulWidget {
  /// Upload progress value (0.0 - 1.0)
  final double progress;

  /// Whether upload is currently in progress
  final bool isUploading;

  /// Child widget to wrap with border
  final Widget child;

  /// Border width (default: 4px)
  final double borderWidth;

  /// Whether to show pulse effect when uploading
  final bool showPulse;

  const StoryUploadBorder({
    Key? key,
    required this.progress,
    required this.isUploading,
    required this.child,
    this.borderWidth = 4.0,
    this.showPulse = true,
  }) : super(key: key);

  @override
  State<StoryUploadBorder> createState() => _StoryUploadBorderState();
}

class _StoryUploadBorderState extends State<StoryUploadBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for upload active state
    _pulseController = AnimationController(
      duration: AnimationTokens.slow,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isUploading && widget.showPulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StoryUploadBorder oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start/stop pulse animation based on upload state
    if (widget.isUploading && widget.showPulse) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Only show border when uploading
    if (!widget.isUploading || widget.progress <= 0.0) {
      return widget.child;
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: UploadBorderPainter(
              progress: widget.progress,
              isUploading: widget.isUploading,
              borderWidth: widget.borderWidth,
              pulseOpacity: widget.showPulse ? _pulseAnimation.value : 1.0,
              activeColors: SonarPulseTheme.appLinearGradient.colors,
              inactiveColor: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
            child: widget.child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Custom painter for drawing the upload progress border
class UploadBorderPainter extends CustomPainter {
  final double progress;
  final bool isUploading;
  final double borderWidth;
  final double pulseOpacity;
  final List<Color> activeColors;
  final Color inactiveColor;

  UploadBorderPainter({
    required this.progress,
    required this.isUploading,
    required this.borderWidth,
    required this.pulseOpacity,
    required this.activeColors,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isUploading || progress <= 0.0) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - borderWidth / 2;

    // Draw inactive background arc (full circle)
    final backgroundPaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw active progress arc with gradient
    if (progress > 0.0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeCap = StrokeCap.round;

      // Create gradient shader for the progress arc
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        colors: activeColors,
        startAngle: -math.pi / 2, // Start from top (0°)
        endAngle: -math.pi / 2 + (2 * math.pi * progress), // Progress clockwise
        tileMode: TileMode.clamp,
      );

      progressPaint.shader = gradient.createShader(rect);
      progressPaint.color = progressPaint.color.withOpacity(pulseOpacity);

      // Draw progress arc
      // Start from top (-π/2), sweep clockwise
      final startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(UploadBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isUploading != isUploading ||
        oldDelegate.pulseOpacity != pulseOpacity ||
        oldDelegate.borderWidth != borderWidth;
  }
}
