// lib/widgets/story_widgets/editor/story_drawing_tools.dart

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

/// Drawing tools panel with color picker and stroke width selector
/// Uses theme integration and glassmorphic design
class StoryDrawingTools extends StatelessWidget {
  final Color selectedColor;
  final double selectedStrokeWidth;
  final Function(Color) onColorSelected;
  final Function(double) onStrokeWidthSelected;

  const StoryDrawingTools({
    Key? key,
    required this.selectedColor,
    required this.selectedStrokeWidth,
    required this.onColorSelected,
    required this.onStrokeWidthSelected,
  }) : super(key: key);

  static const List<Color> _colors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Color(0xFF00BFA5), // Primary accent
    Color(0xFF5DF2D6), // Primary accent light
  ];

  static const List<double> _strokeWidths = [3.0, 5.0, 8.0, 12.0];

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: DesignTokens.blurMedium,
              sigmaY: DesignTokens.blurMedium,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: DesignTokens.spaceMD,
                horizontal: DesignTokens.spaceLG,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.1),
                  width: 1.0,
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Color swatches
                    ..._colors.map((color) => _buildColorSwatch(color)),
                    const SizedBox(width: DesignTokens.spaceMD),
                    // Divider
                    Container(
                      width: DesignTokens.elevation1,
                      height: DesignTokens.spaceXXL,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.2),
                    ),
                    const SizedBox(width: DesignTokens.spaceMD),
                    // Stroke width options
                    ..._strokeWidths.map(
                        (width) => _buildStrokeWidthOption(context, width)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorSwatch(Color color) {
    final isSelected = color == selectedColor;
    return GestureDetector(
      onTap: () => onColorSelected(color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceXS),
        width: DesignTokens.avatarSize,
        height: DesignTokens.avatarSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color:
                isSelected ? SonarPulseTheme.primaryAccent : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: SonarPulseTheme.primaryAccent.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Widget _buildStrokeWidthOption(BuildContext context, double width) {
    final isSelected = (width - selectedStrokeWidth).abs() < 0.1;
    return GestureDetector(
      onTap: () => onStrokeWidthSelected(width),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceXS),
        width: isSelected ? DesignTokens.iconLG : DesignTokens.iconMD,
        height: isSelected ? DesignTokens.iconLG : DesignTokens.iconMD,
        decoration: BoxDecoration(
          color: isSelected
              ? SonarPulseTheme.primaryAccent.withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: SonarPulseTheme.primaryAccent,
                  width: DesignTokens.elevation1,
                )
              : null,
        ),
        child: Center(
          child: Container(
            width: width,
            height: width,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
