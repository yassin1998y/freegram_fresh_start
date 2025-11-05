// lib/widgets/story_widgets/draggable_text_widget.dart

import 'package:flutter/material.dart';
import 'package:freegram/models/text_overlay_model.dart';

/// Draggable and scalable text overlay widget
class DraggableTextWidget extends StatefulWidget {
  final TextOverlay overlay;
  final Function(TextOverlay) onOverlayChanged;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const DraggableTextWidget({
    Key? key,
    required this.overlay,
    required this.onOverlayChanged,
    required this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  State<DraggableTextWidget> createState() => _DraggableTextWidgetState();
}

class _DraggableTextWidgetState extends State<DraggableTextWidget> {
  late double _x;
  late double _y;
  late double _scale;
  late double _rotation;
  Offset? _panStart;
  double _scaleStart = 1.0;
  double _rotationStart = 0.0;

  @override
  void initState() {
    super.initState();
    _x = widget.overlay.x;
    _y = widget.overlay.y;
    _scale = widget.overlay.fontSize / 24.0; // Normalize to base font size
    _rotation = widget.overlay.rotation;
  }

  @override
  void didUpdateWidget(DraggableTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overlay != widget.overlay) {
      _x = widget.overlay.x;
      _y = widget.overlay.y;
      _scale = widget.overlay.fontSize / 24.0;
      _rotation = widget.overlay.rotation;
    }
  }

  void _onPanStart(DragStartDetails details, Size screenSize) {
    _panStart = details.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails details, Size screenSize) {
    if (_panStart == null) return;

    final delta = details.localPosition - _panStart!;
    final newX = (_x * screenSize.width + delta.dx) / screenSize.width;
    final newY = (_y * screenSize.height + delta.dy) / screenSize.height;

    setState(() {
      _x = newX.clamp(0.0, 1.0);
      _y = newY.clamp(0.0, 1.0);
    });

    _updateOverlay();
  }

  void _onPanEnd(DragEndDetails details) {
    _panStart = null;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _scaleStart = _scale;
    _rotationStart = _rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size screenSize) {
    setState(() {
      _scale = (_scaleStart * details.scale).clamp(0.5, 3.0);
      _rotation = _rotationStart + details.rotation;
    });

    _updateOverlay();
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _scaleStart = _scale;
    _rotationStart = _rotation;
  }

  void _updateOverlay() {
    final fontSize = _scale * 24.0; // Denormalize to actual font size
    widget.onOverlayChanged(
      widget.overlay.copyWith(
        x: _x,
        y: _y,
        fontSize: fontSize,
        rotation: _rotation,
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.white;
    }
  }

  TextStyle _getTextStyle() {
    final color = _parseColor(widget.overlay.color);
    final baseStyle = TextStyle(
      color: color,
      fontSize: 24.0,
      fontWeight: FontWeight.bold,
    );

    switch (widget.overlay.style) {
      case 'outline':
        return baseStyle.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color,
        );
      case 'neon':
        return baseStyle.copyWith(
          shadows: [
            Shadow(
              color: color,
              blurRadius: 10,
            ),
            Shadow(
              color: color,
              blurRadius: 20,
            ),
          ],
        );
      case 'bold':
      default:
        return baseStyle;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery to get screen size since we're in a Stack
    final screenSize = MediaQuery.of(context).size;
    final position = Offset(_x * screenSize.width, _y * screenSize.height);

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onTap: widget.onEdit,
        onPanStart: (details) => _onPanStart(details, screenSize),
        onPanUpdate: (details) => _onPanUpdate(details, screenSize),
        onPanEnd: _onPanEnd,
        onScaleStart: _onScaleStart,
        onScaleUpdate: (details) => _onScaleUpdate(details, screenSize),
        onScaleEnd: _onScaleEnd,
        child: Transform.rotate(
          angle: _rotation,
          child: Transform.scale(
            scale: _scale,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Text display
                Text(
                  widget.overlay.text,
                  style: _getTextStyle(),
                ),
                // Delete button
                if (widget.onDelete != null)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
