// lib/widgets/story_widgets/draggable_sticker_widget.dart

import 'package:flutter/material.dart';

/// Draggable and scalable sticker widget
class DraggableStickerWidget extends StatefulWidget {
  final String stickerId;
  final double initialX; // Normalized 0-1
  final double initialY; // Normalized 0-1
  final double initialScale;
  final double initialRotation;
  final Function(double x, double y, double scale, double rotation)
      onPositionChanged;
  final VoidCallback? onDelete;

  const DraggableStickerWidget({
    Key? key,
    required this.stickerId,
    required this.initialX,
    required this.initialY,
    this.initialScale = 1.0,
    this.initialRotation = 0.0,
    required this.onPositionChanged,
    this.onDelete,
  }) : super(key: key);

  @override
  State<DraggableStickerWidget> createState() => _DraggableStickerWidgetState();
}

class _DraggableStickerWidgetState extends State<DraggableStickerWidget> {
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
    _x = widget.initialX;
    _y = widget.initialY;
    _scale = widget.initialScale;
    _rotation = widget.initialRotation;
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

    widget.onPositionChanged(_x, _y, _scale, _rotation);
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

    widget.onPositionChanged(_x, _y, _scale, _rotation);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _scaleStart = _scale;
    _rotationStart = _rotation;
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
                // Sticker display
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    widget.stickerId,
                    style: const TextStyle(fontSize: 48),
                  ),
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
