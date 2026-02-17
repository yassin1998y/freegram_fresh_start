import 'package:flutter/material.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';

/// A high-fidelity "Pure" progress bar for achievements.
/// Features a 1px border rule, Brand Green fill, and a subtle glow.
class AchievementProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final bool isCompleted;
  final Widget? trailing;

  const AchievementProgressBar({
    super.key,
    required this.progress,
    this.isCompleted = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primaryColor = SonarPulseTheme.primaryAccent;

    return Row(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // 1px Border Rule Background
              Container(
                height: 12, // Slightly taller for more presence
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                    width: 1.0,
                  ),
                  color: theme.colorScheme.surface.withValues(alpha: 0.05),
                ),
              ),

              // Animated Fill with Glow
              LayoutBuilder(
                builder: (context, constraints) {
                  final fillWidth =
                      constraints.maxWidth * progress.clamp(0.0, 1.0);

                  return AnimatedContainer(
                    duration: AnimationTokens.normal,
                    curve: Curves.easeOutCubic,
                    width: fillWidth,
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusXS),
                      color: primaryColor,
                      boxShadow: [
                        if (progress > 0)
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                      ],
                      gradient: LinearGradient(
                        colors: [
                          primaryColor,
                          primaryColor.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  );
                },
              ),

              // Percentage Label
              Positioned(
                left: 8,
                child: Text(
                  "${(progress * 100).toInt()}%",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: progress > 0.15
                        ? Colors.white
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: DesignTokens.spaceMD),
          trailing!,
        ],
      ],
    );
  }
}
