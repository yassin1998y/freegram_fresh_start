import 'package:flutter/material.dart';
import 'package:freegram/theme/app_theme.dart';

class GradientOutlinedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final double strokeWidth;
  final BorderRadius borderRadius;

  const GradientOutlinedButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.strokeWidth = 2.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(12.0)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: SonarPulseTheme.appLinearGradient,
        borderRadius: borderRadius,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: Container(
            margin: EdgeInsets.all(strokeWidth),
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            decoration: BoxDecoration(
              // Use the scaffold background color to create the "hollow" effect
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: borderRadius,
            ),
            child: Center(
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return SonarPulseTheme.appLinearGradient.createShader(
                    Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                  );
                },
                child: Text(
                  text,
                  // Use a white color for the text which will be masked by the gradient
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}