import 'package:flutter/material.dart';
import 'package:freegram/theme/app_theme.dart';

class GradientSpinner extends StatelessWidget {
  final double size;
  final double strokeWidth;

  const GradientSpinner({
    super.key,
    this.size = 24.0,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        // Use the new radial gradient from our theme file
        return SonarPulseTheme.appRadialGradient.createShader(bounds);
      },
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}