import 'dart:async';
import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

class HideableControlsWrapper extends StatefulWidget {
  final Widget child;
  final Widget overlay;

  const HideableControlsWrapper({
    super.key,
    required this.child,
    required this.overlay,
  });

  @override
  State<HideableControlsWrapper> createState() =>
      _HideableControlsWrapperState();
}

class _HideableControlsWrapperState extends State<HideableControlsWrapper> {
  bool _isVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _isVisible = false);
      }
    });
  }

  void _toggleVisibility() {
    setState(() {
      _isVisible = !_isVisible;
      if (_isVisible) {
        _startHideTimer();
      } else {
        _hideTimer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleVisibility,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Underlying Content (Video)
          widget.child,

          // Controls Overlay
          AnimatedOpacity(
            opacity: _isVisible ? 1.0 : 0.0,
            duration: AnimationTokens.normal,
            child: IgnorePointer(
              ignoring: !_isVisible,
              child: widget.overlay,
            ),
          ),
        ],
      ),
    );
  }
}
