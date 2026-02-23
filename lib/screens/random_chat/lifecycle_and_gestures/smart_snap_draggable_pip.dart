import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/screens/random_chat/random_chat_config.dart';
import 'package:freegram/theme/design_tokens.dart';

class SmartSnapDraggablePiP extends StatefulWidget {
  final Widget cameraPreview;

  const SmartSnapDraggablePiP({super.key, required this.cameraPreview});

  @override
  State<SmartSnapDraggablePiP> createState() => _SmartSnapDraggablePiPState();
}

class _SmartSnapDraggablePiPState extends State<SmartSnapDraggablePiP> {
  Offset? _position;
  bool _isDragging = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize to bottom-right corner on first load
    if (_position == null) {
      final size = MediaQuery.of(context).size;
      const padding = DesignTokens.spaceMD;
      _position = Offset(
        size.width - RandomChatConfig.pipWindowSize.width - padding,
        size.height -
            RandomChatConfig.pipWindowSize.height -
            padding -
            120, // Adjusted for bottom bar
      );
    }
  }

  void _snapToCorner(Size screenSize) {
    if (_position == null) return;

    const padding = DesignTokens.spaceMD;
    final pipWidth = RandomChatConfig.pipWindowSize.width;
    final pipHeight = RandomChatConfig.pipWindowSize.height;

    // Define 4 anchor corners
    final List<Offset> corners = [
      const Offset(padding, padding + 100), // Top-left (below header)
      Offset(screenSize.width - pipWidth - padding, padding + 100), // Top-right
      Offset(padding,
          screenSize.height - pipHeight - padding - 120), // Bottom-left
      Offset(screenSize.width - pipWidth - padding,
          screenSize.height - pipHeight - padding - 120), // Bottom-right
    ];

    // Find closest corner
    Offset closest = corners.first;
    double minDistance = (_position! - closest).distance;

    for (final corner in corners) {
      final distance = (_position! - corner).distance;
      if (distance < minDistance) {
        minDistance = distance;
        closest = corner;
      }
    }

    setState(() {
      _position = closest;
      _isDragging = false;
    });

    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.bounceOut,
      left: _position?.dx,
      top: _position?.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position!.dx + details.delta.dx).clamp(
                  0, screenSize.width - RandomChatConfig.pipWindowSize.width),
              (_position!.dy + details.delta.dy).clamp(
                  0, screenSize.height - RandomChatConfig.pipWindowSize.height),
            );
          });
        },
        onPanEnd: (_) => _snapToCorner(screenSize),
        onDoubleTap: () {
          // Placeholder signal to swap renderers
          HapticFeedback.mediumImpact();
          // Future: context.read<RandomChatBloc>().add(RandomChatSwapRenderers());
        },
        child: PhysicalModel(
          color: Colors.black,
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: RandomChatConfig.pipWindowSize.width,
            height: RandomChatConfig.pipWindowSize.height,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24, width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: widget.cameraPreview,
          ),
        ),
      ),
    );
  }
}
