// lib/widgets/story_widgets/draggable_sticker_widget.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

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
  Offset _pointerDownPosition = Offset.zero;
  Offset _lastPointerPosition = Offset.zero;
  double _scaleStart = 1.0;
  double _rotationStart = 0.0;
  Offset _positionStart = Offset.zero;

  @override
  void initState() {
    super.initState();
    _x = widget.initialX;
    _y = widget.initialY;
    _scale = widget.initialScale;
    _rotation = widget.initialRotation;
  }

  @override
  void didUpdateWidget(DraggableStickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialX != widget.initialX ||
        oldWidget.initialY != widget.initialY) {
      _x = widget.initialX;
      _y = widget.initialY;
    }
    if (oldWidget.initialScale != widget.initialScale) {
      _scale = widget.initialScale;
    }
    if (oldWidget.initialRotation != widget.initialRotation) {
      _rotation = widget.initialRotation;
    }
  }

  void _onScaleStart(ScaleStartDetails details, Size screenSize) {
    // Store initial state for all gestures
    _pointerDownPosition = details.focalPoint;
    _lastPointerPosition = details.focalPoint;
    _positionStart = Offset(_x * screenSize.width, _y * screenSize.height);

    // Always prepare for scale/rotate (in case it becomes a two-finger gesture)
    _scaleStart = _scale;
    _rotationStart = _rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size screenSize) {
    // Calculate delta before updating last pointer position
    final delta = details.focalPoint - _lastPointerPosition;

    // Check for scale/rotate changes
    final hasScaleChange = (details.scale - 1.0).abs() > 0.01;
    final hasRotationChange = details.rotation.abs() > 0.01;
    final isTwoFingers = details.pointerCount == 2;

    // Handle scale/rotate first (if applicable)
    if (isTwoFingers && (hasScaleChange || hasRotationChange)) {
      bool needsUpdate = false;

      if (hasScaleChange) {
        setState(() {
          _scale = (_scaleStart * details.scale).clamp(0.5, 3.0);
        });
        needsUpdate = true;
      }

      if (hasRotationChange) {
        setState(() {
          _rotation = _rotationStart + details.rotation;
        });
        needsUpdate = true;
      }

      if (needsUpdate) {
        widget.onPositionChanged(_x, _y, _scale, _rotation);
      }
      // Update last pointer position and return
      _lastPointerPosition = details.focalPoint;
      return;
    }

    // Handle drag for single finger or when no scale/rotate
    // Always update position based on total delta from start
    final totalDelta = details.focalPoint - _pointerDownPosition;
    if (totalDelta.distance.abs() > 1.0 || delta.distance.abs() > 0.5) {
      final newX = (_positionStart.dx + totalDelta.dx) / screenSize.width;
      final newY = (_positionStart.dy + totalDelta.dy) / screenSize.height;

      setState(() {
        _x = newX.clamp(0.0, 1.0);
        _y = newY.clamp(0.0, 1.0);
      });
      widget.onPositionChanged(_x, _y, _scale, _rotation);
    }

    // Update last pointer position after processing
    _lastPointerPosition = details.focalPoint;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _pointerDownPosition = Offset.zero;
    _lastPointerPosition = Offset.zero;
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
        behavior: HitTestBehavior.translucent,
        onScaleStart: (details) {
          _onScaleStart(details, screenSize);
        },
        onScaleUpdate: (details) {
          _onScaleUpdate(details, screenSize);
        },
        onScaleEnd: (details) {
          _onScaleEnd(details);
        },
        child: RepaintBoundary(
          child: Transform.rotate(
            angle: _rotation,
            child: Transform.scale(
              scale: _scale,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Sticker display
                  Container(
                    padding: const EdgeInsets.all(DesignTokens.spaceXS),
                    child: Text(
                      widget.stickerId,
                      style: TextStyle(fontSize: DesignTokens.fontSizeDisplay),
                    ),
                  ),
                  // Delete button
                  if (widget.onDelete != null)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: GestureDetector(
                        onTap: () {
                          // Stop event propagation to prevent triggering scale gesture
                          widget.onDelete?.call();
                        },
                        child: Container(
                          width: DesignTokens.iconLG,
                          height: DesignTokens.iconLG,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Theme.of(context).colorScheme.onError,
                            size: DesignTokens.iconSM,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
