// lib/widgets/story_widgets/drawing_toolbar.dart

import 'package:flutter/material.dart';

/// Toolbar for drawing tool with color and stroke width options
class DrawingToolbar extends StatelessWidget {
  final Color selectedColor;
  final double selectedStrokeWidth;
  final Function(Color) onColorSelected;
  final Function(double) onStrokeWidthSelected;

  const DrawingToolbar({
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
  ];

  static const List<double> _strokeWidths = [3.0, 5.0, 8.0, 12.0];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color swatches
          ..._colors.map((color) => _buildColorSwatch(color)),
          const SizedBox(width: 16),
          // Stroke width options
          ..._strokeWidths.map((width) => _buildStrokeWidthOption(width)),
        ],
      ),
    );
  }

  Widget _buildColorSwatch(Color color) {
    final isSelected = color == selectedColor;
    return GestureDetector(
      onTap: () => onColorSelected(color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
        ),
      ),
    );
  }

  Widget _buildStrokeWidthOption(double width) {
    final isSelected = (width - selectedStrokeWidth).abs() < 0.1;
    return GestureDetector(
      onTap: () => onStrokeWidthSelected(width),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: isSelected ? 40 : 32,
        height: isSelected ? 40 : 32,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: width,
            height: width,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
