// lib/widgets/story_widgets/viewer/story_overlays_widget.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:freegram/models/story_media_model.dart';
import 'package:freegram/models/text_overlay_model.dart';
import 'package:freegram/models/drawing_path_model.dart';
import 'package:freegram/models/sticker_overlay_model.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Overlays widget for story viewer
/// Renders text, drawing, and sticker overlays on top of story media
class StoryOverlaysWidget extends StatelessWidget {
  final StoryMedia story;

  const StoryOverlaysWidget({
    Key? key,
    required this.story,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Text overlays
        if (story.textOverlays != null && story.textOverlays!.isNotEmpty)
          ..._buildTextOverlays(context, story.textOverlays!),

        // Drawing overlays
        if (story.drawings != null && story.drawings!.isNotEmpty)
          _buildDrawingOverlay(context, story.drawings!),

        // Sticker overlays
        if (story.stickerOverlays != null && story.stickerOverlays!.isNotEmpty)
          ..._buildStickerOverlays(context, story.stickerOverlays!),
      ],
    );
  }

  List<Widget> _buildTextOverlays(
    BuildContext context,
    List<TextOverlay> textOverlays,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return textOverlays.map((overlay) {
      final x = overlay.x * screenSize.width;
      final y = overlay.y * screenSize.height;

      // Parse color from hex string
      Color textColor;
      try {
        textColor = Color(int.parse(overlay.color.replaceFirst('#', '0xFF')));
      } catch (e) {
        textColor = theme.colorScheme.onSurface; // Use theme color as fallback
      }

      // Apply text style based on overlay.style
      TextStyle textStyle = TextStyle(
        color: textColor,
        fontSize: overlay.fontSize,
        fontWeight: FontWeight.bold,
      );

      // Apply outline effect if style is 'outline'
      if (overlay.style == 'outline') {
        final outlineColor = theme.brightness == Brightness.dark
            ? theme.colorScheme.surface
            : theme.colorScheme.primary;
        textStyle = textStyle.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = DesignTokens.elevation1
            ..color = outlineColor,
        );
      }

      // Apply neon effect if style is 'neon'
      if (overlay.style == 'neon') {
        textStyle = textStyle.copyWith(
          shadows: [
            Shadow(
              color: textColor,
              blurRadius: DesignTokens.blurLight,
            ),
            Shadow(
              color: textColor,
              blurRadius: DesignTokens.blurMedium,
            ),
          ],
        );
      }

      return Positioned(
        left: x,
        top: y,
        child: Transform.rotate(
          angle: overlay.rotation * 3.14159 / 180,
          child: Text(
            overlay.text,
            style: textStyle,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildDrawingOverlay(
      BuildContext context, List<DrawingPath> drawings) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: CustomPaint(
        painter: _DrawingPainter(
          drawings,
          fallbackColor: theme.colorScheme.onSurface,
        ),
        size: Size.infinite,
      ),
    );
  }

  List<Widget> _buildStickerOverlays(
    BuildContext context,
    List<StickerOverlay> stickerOverlays,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return stickerOverlays.map((sticker) {
      final position = Offset(
        sticker.x * screenSize.width,
        sticker.y * screenSize.height,
      );

      return Positioned(
        left: position.dx,
        top: position.dy,
        child: Transform.rotate(
          angle: sticker.rotation * 3.14159 / 180,
          child: Transform.scale(
            scale: sticker.scale,
            child: Text(
              sticker.stickerId,
              style: TextStyle(
                fontSize: DesignTokens.iconXXL,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

/// Custom painter for rendering drawing paths on stories
class _DrawingPainter extends CustomPainter {
  final List<DrawingPath> drawings;
  final Color fallbackColor;

  const _DrawingPainter(this.drawings, {this.fallbackColor = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    for (final drawingPath in drawings) {
      // Parse color from hex string
      Color pathColor;
      try {
        pathColor =
            Color(int.parse(drawingPath.color.replaceFirst('#', '0xFF')));
      } catch (e) {
        pathColor = fallbackColor; // Use provided fallback color
      }

      final paint = Paint()
        ..color = pathColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = drawingPath.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Create path from points
      final path = ui.Path();
      if (drawingPath.points.isNotEmpty) {
        final firstPoint = drawingPath.points.first;
        path.moveTo(firstPoint.x * size.width, firstPoint.y * size.height);

        for (int i = 1; i < drawingPath.points.length; i++) {
          final point = drawingPath.points[i];
          path.lineTo(point.x * size.width, point.y * size.height);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter oldDelegate) {
    return oldDelegate.drawings != drawings;
  }
}
