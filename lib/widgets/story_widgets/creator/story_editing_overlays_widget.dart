// lib/widgets/story_widgets/creator/story_editing_overlays_widget.dart

import 'package:flutter/material.dart';
import 'package:freegram/models/text_overlay_model.dart';
import 'package:freegram/models/drawing_path_model.dart';
import 'package:freegram/models/sticker_overlay_model.dart';
import 'package:freegram/widgets/story_widgets/drawing_canvas.dart';
import 'package:freegram/widgets/story_widgets/draggable_sticker_widget.dart';
import 'package:freegram/widgets/story_widgets/draggable_text_widget.dart';
import 'package:freegram/widgets/story_widgets/editor/story_drawing_tools.dart';

/// Editing overlays widget for story creator
/// Manages text overlays, drawings, and stickers on top of media
class StoryEditingOverlaysWidget extends StatelessWidget {
  final String activeTool;
  final List<TextOverlay> textOverlays;
  final List<DrawingPath> drawings;
  final List<StickerOverlay> stickerOverlays;
  final Color drawingColor;
  final double drawingStrokeWidth;
  final ValueChanged<List<DrawingPath>> onDrawingsChanged;
  final void Function(int index, TextOverlay overlay) onTextOverlayChanged;
  final ValueChanged<int> onEditTextOverlay;
  final ValueChanged<int> onDeleteTextOverlay;
  final void Function(int index, StickerOverlay sticker)
      onStickerOverlayChanged;
  final ValueChanged<int> onDeleteStickerOverlay;
  final ValueChanged<Color> onDrawingColorChanged;
  final ValueChanged<double> onDrawingStrokeWidthChanged;

  const StoryEditingOverlaysWidget({
    Key? key,
    required this.activeTool,
    required this.textOverlays,
    required this.drawings,
    required this.stickerOverlays,
    required this.drawingColor,
    required this.drawingStrokeWidth,
    required this.onDrawingsChanged,
    required this.onTextOverlayChanged,
    required this.onEditTextOverlay,
    required this.onDeleteTextOverlay,
    required this.onStickerOverlayChanged,
    required this.onDeleteStickerOverlay,
    required this.onDrawingColorChanged,
    required this.onDrawingStrokeWidthChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Drawing canvas (only when drawing tool is active)
        if (activeTool == 'draw')
          Positioned.fill(
            child: DrawingCanvas(
              drawings: drawings,
              onDrawingsChanged: onDrawingsChanged,
              currentColor: drawingColor,
              currentStrokeWidth: drawingStrokeWidth,
              isDrawingEnabled: activeTool == 'draw',
            ),
          ),

        // Draggable text overlays
        ...textOverlays.asMap().entries.map((entry) {
          final index = entry.key;
          final overlay = entry.value;
          return DraggableTextWidget(
            key: ValueKey('text_$index'),
            overlay: overlay,
            onOverlayChanged: (updated) => onTextOverlayChanged(index, updated),
            onEdit: () => onEditTextOverlay(index),
            onDelete: () => onDeleteTextOverlay(index),
          );
        }),

        // Draggable stickers
        ...stickerOverlays.asMap().entries.map((entry) {
          final index = entry.key;
          final sticker = entry.value;
          return DraggableStickerWidget(
            key: ValueKey('sticker_$index'),
            stickerId: sticker.stickerId,
            initialX: sticker.x,
            initialY: sticker.y,
            initialScale: sticker.scale,
            initialRotation: sticker.rotation,
            onPositionChanged: (x, y, scale, rotation) {
              onStickerOverlayChanged(
                index,
                sticker.copyWith(
                  x: x,
                  y: y,
                  scale: scale,
                  rotation: rotation,
                ),
              );
            },
            onDelete: () => onDeleteStickerOverlay(index),
          );
        }),

        // Drawing tools (when drawing tool is active)
        if (activeTool == 'draw')
          StoryDrawingTools(
            selectedColor: drawingColor,
            selectedStrokeWidth: drawingStrokeWidth,
            onColorSelected: onDrawingColorChanged,
            onStrokeWidthSelected: onDrawingStrokeWidthChanged,
          ),
      ],
    );
  }
}
