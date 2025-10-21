import 'package:flutter/material.dart';
import 'package:freegram/theme/app_theme.dart';

class GradientProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final BorderRadius borderRadius;

  const GradientProgressBar({
    super.key,
    required this.progress,
    this.height = 12.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor,
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            decoration: const BoxDecoration(
              gradient: SonarPulseTheme.appLinearGradient,
            ),
          ),
        ),
      ),
    );
  }
}