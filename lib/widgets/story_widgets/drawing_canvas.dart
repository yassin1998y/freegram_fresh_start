// lib/widgets/story_widgets/drawing_canvas.dart

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:freegram/models/drawing_path_model.dart';

/// Canvas widget for drawing on stories
class DrawingCanvas extends StatefulWidget {
  final List<DrawingPath> drawings;
  final Function(List<DrawingPath>) onDrawingsChanged;
  final Color currentColor;
  final double currentStrokeWidth;
  final bool isDrawingEnabled;

  const DrawingCanvas({
    Key? key,
    required this.drawings,
    required this.onDrawingsChanged,
    required this.currentColor,
    required this.currentStrokeWidth,
    this.isDrawingEnabled = true,
  }) : super(key: key);

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  DrawingPath? _currentPath;
  List<OffsetPoint> _currentPoints = [];

  void _onPanStart(DragStartDetails details) {
    if (!widget.isDrawingEnabled) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(details.globalPosition);
    final Size size = box.size;

    // Normalize coordinates (0-1)
    final normalizedX = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final normalizedY = (localPosition.dy / size.height).clamp(0.0, 1.0);

    _currentPath = DrawingPath(
      points: [
        OffsetPoint(x: normalizedX, y: normalizedY),
      ],
      color: _colorToHex(widget.currentColor),
      strokeWidth: widget.currentStrokeWidth,
    );
    _currentPoints = [OffsetPoint(x: normalizedX, y: normalizedY)];
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.isDrawingEnabled || _currentPath == null) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(details.globalPosition);
    final Size size = box.size;

    // Normalize coordinates (0-1)
    final normalizedX = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final normalizedY = (localPosition.dy / size.height).clamp(0.0, 1.0);

    setState(() {
      _currentPoints.add(OffsetPoint(x: normalizedX, y: normalizedY));
      _currentPath = _currentPath!.copyWith(points: _currentPoints);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isDrawingEnabled || _currentPath == null) return;

    final updatedDrawings = List<DrawingPath>.from(widget.drawings)
      ..add(_currentPath!);

    widget.onDrawingsChanged(updatedDrawings);

    setState(() {
      _currentPath = null;
      _currentPoints = [];
    });
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: widget.isDrawingEnabled ? _onPanStart : null,
      onPanUpdate: widget.isDrawingEnabled ? _onPanUpdate : null,
      onPanEnd: widget.isDrawingEnabled ? _onPanEnd : null,
      behavior: HitTestBehavior.translucent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: DrawingPainter(
              drawings: widget.drawings,
              currentPath: _currentPath,
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter for drawing paths
class DrawingPainter extends CustomPainter {
  final List<DrawingPath> drawings;
  final DrawingPath? currentPath;

  DrawingPainter({
    required this.drawings,
    this.currentPath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all completed paths
    for (final drawingPath in drawings) {
      _drawPath(canvas, size, drawingPath);
    }

    // Draw current path being drawn
    if (currentPath != null) {
      _drawPath(canvas, size, currentPath!);
    }
  }

  void _drawPath(Canvas canvas, Size size, DrawingPath drawingPath) {
    if (drawingPath.points.isEmpty) return;

    // Parse color from hex string
    Color pathColor;
    try {
      pathColor = Color(
        int.parse(drawingPath.color.replaceFirst('#', '0xFF')),
      );
    } catch (e) {
      pathColor = Colors.white; // Default to white if parsing fails
    }

    final paint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = drawingPath.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Create path from points
    final path = ui.Path();
    final firstPoint = drawingPath.points.first;
    path.moveTo(firstPoint.x * size.width, firstPoint.y * size.height);

    for (int i = 1; i < drawingPath.points.length; i++) {
      final point = drawingPath.points[i];
      path.lineTo(point.x * size.width, point.y * size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return oldDelegate.drawings != drawings ||
        oldDelegate.currentPath != currentPath;
  }
}
