// lib/widgets/story_widgets/draggable_text_widget.dart

import 'package:flutter/material.dart';
import 'package:freegram/models/text_overlay_model.dart';
import 'package:freegram/theme/design_tokens.dart';

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
  Offset _pointerDownPosition = Offset.zero;
  Offset _lastPointerPosition = Offset.zero;
  double _scaleStart = 1.0;
  double _rotationStart = 0.0;
  Offset _positionStart = Offset.zero;
  bool _isDragging = false;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _x = widget.overlay.x;
    _y = widget.overlay.y;
    _scale = widget.overlay.fontSize /
        DesignTokens.fontSizeXXXL; // Normalize to base font size
    _rotation = widget.overlay.rotation;
  }

  @override
  void didUpdateWidget(DraggableTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overlay != widget.overlay) {
      _x = widget.overlay.x;
      _y = widget.overlay.y;
      _scale = widget.overlay.fontSize / DesignTokens.fontSizeXXXL;
      _rotation = widget.overlay.rotation;
    }
  }

  void _updateOverlay() {
    // Denormalize to actual font size with limits
    const baseFontSize = DesignTokens.fontSizeXXXL;
    const minFontSize = DesignTokens.fontSizeSM;
    const maxFontSize = DesignTokens.fontSizeDisplay * 3; // 96.0
    final fontSize = (_scale * baseFontSize).clamp(minFontSize, maxFontSize);

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
      // Return a default color based on theme instead of hardcoded white
      return Theme.of(context).colorScheme.onSurface;
    }
  }

  TextStyle _getTextStyle() {
    final color = _parseColor(widget.overlay.color);
    final baseStyle = TextStyle(
      color: color,
      fontSize: DesignTokens.fontSizeXXXL,
      fontWeight: FontWeight.bold,
    );

    switch (widget.overlay.style) {
      case 'outline':
        return baseStyle.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = DesignTokens.elevation1
            ..color = color,
        );
      case 'neon':
        return baseStyle.copyWith(
          shadows: [
            Shadow(
              color: color,
              blurRadius: DesignTokens.blurLight,
            ),
            Shadow(
              color: color,
              blurRadius: DesignTokens.blurMedium,
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
        behavior: HitTestBehavior.translucent,
        onLongPress: widget.onEdit,
        onScaleStart: (details) {
          // Store initial state for all gestures
          _pointerDownPosition = details.focalPoint;
          _lastPointerPosition = details.focalPoint;
          _positionStart =
              Offset(_x * screenSize.width, _y * screenSize.height);
          _isDragging = false;

          // Always prepare for scale/rotate (will be used if gesture becomes two-finger)
          _scaleStart = _scale;
          _rotationStart = _rotation;
        },
        onScaleUpdate: (details) {
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
              _updateOverlay();
            }
            // Update last pointer position and return
            _lastPointerPosition = details.focalPoint;
            return;
          }

          // Handle drag for single finger or when no scale/rotate
          // Always update position based on total delta from start
          final totalDelta = details.focalPoint - _pointerDownPosition;
          if (totalDelta.distance.abs() > 1.0 || delta.distance.abs() > 0.5) {
            _isDragging = true;
            final newX = (_positionStart.dx + totalDelta.dx) / screenSize.width;
            final newY =
                (_positionStart.dy + totalDelta.dy) / screenSize.height;

            setState(() {
              _x = newX.clamp(0.0, 1.0);
              _y = newY.clamp(0.0, 1.0);
            });
            _updateOverlay();
          }

          // Update last pointer position after processing
          _lastPointerPosition = details.focalPoint;
        },
        onScaleEnd: (details) {
          final wasDragging = _isDragging;

          // Reset state
          _pointerDownPosition = Offset.zero;
          _lastPointerPosition = Offset.zero;
          _isDragging = false;

          // Only trigger edit if it was a tap (not a drag)
          if (!wasDragging) {
            final now = DateTime.now();
            if (_lastTapTime == null ||
                now.difference(_lastTapTime!) >
                    const Duration(milliseconds: 300)) {
              Future.delayed(const Duration(milliseconds: 150), () {
                if (mounted && !_isDragging) {
                  widget.onEdit();
                }
              });
            }
            _lastTapTime = now;
          }
        },
        child: RepaintBoundary(
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
                        onTap: () {
                          // Stop event propagation to prevent triggering onTap
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
