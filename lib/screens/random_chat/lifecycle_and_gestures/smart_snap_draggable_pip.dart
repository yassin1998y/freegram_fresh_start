import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:freegram/screens/random_chat/random_chat_config.dart';
import 'package:freegram/theme/design_tokens.dart';

class SmartSnapDraggablePiP extends StatefulWidget {
  final Widget cameraPreview;

  const SmartSnapDraggablePiP({super.key, required this.cameraPreview});

  @override
  State<SmartSnapDraggablePiP> createState() => _SmartSnapDraggablePiPState();
}

class _SmartSnapDraggablePiPState extends State<SmartSnapDraggablePiP>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  Offset _position = Offset.zero;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addListener(() {
      setState(() {
        _position = _animation.value;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final size = MediaQuery.of(context).size;
      const padding = DesignTokens.spaceMD;
      const pipSize = RandomChatConfig.pipWindowSize;

      // Default to bottom-right
      _position = Offset(
        size.width - pipSize.width - padding,
        size.height - pipSize.height - padding - 120, // Bottom bar offset
      );
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runAnimation(Offset target, Offset velocity) {
    _animation = _controller.drive(
      Tween<Offset>(
        begin: _position,
        end: target,
      ),
    );

    // Calculate velocity relative to pixels per second
    final Simulation simulation = SpringSimulation(
      const SpringDescription(
        mass: 1.0,
        stiffness: 180.0,
        damping: 20.0,
      ),
      0.0,
      1.0,
      velocity.distance / 1000, // Normalized velocity
    );

    _controller.animateWith(simulation);
    HapticFeedback.selectionClick();
  }

  void _onPanEnd(DragEndDetails details, Size screenSize) {
    const padding = DesignTokens.spaceMD;
    const pipSize = RandomChatConfig.pipWindowSize;

    // Boundary math including top/bottom offsets
    final List<Offset> corners = [
      const Offset(padding, padding + 100), // Top-Left
      Offset(screenSize.width - pipSize.width - padding,
          padding + 100), // Top-Right
      Offset(padding,
          screenSize.height - pipSize.height - padding - 120), // Bottom-Left
      Offset(screenSize.width - pipSize.width - padding,
          screenSize.height - pipSize.height - padding - 120), // Bottom-Right
    ];

    // Find nearest corner via Euclidean distance
    Offset closest = corners.first;
    double minDistance = (_position - closest).distance;

    for (final corner in corners) {
      final distance = (_position - corner).distance;
      if (distance < minDistance) {
        minDistance = distance;
        closest = corner;
      }
    }

    _runAnimation(closest, details.velocity.pixelsPerSecond);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const pipSize = RandomChatConfig.pipWindowSize;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          if (_controller.isAnimating) _controller.stop();
          setState(() {
            _position += details.delta;
          });
        },
        onPanEnd: (details) => _onPanEnd(details, screenSize),
        onDoubleTap: () => HapticFeedback.mediumImpact(),
        child: PhysicalModel(
          color: Colors.black,
          elevation: 12,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: pipSize.width,
            height: pipSize.height,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24, width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: widget.cameraPreview,
          ),
        ),
      ),
    );
  }
}
