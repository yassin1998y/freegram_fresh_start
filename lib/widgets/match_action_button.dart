import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Configuration for match screen action buttons
class MatchActionButtonConfig {
  final IconData icon;
  final Color color;
  final String label;
  final String tooltip;
  final double size;
  final double iconSize;
  final VoidCallback? onPressed;
  final String? badge;
  final bool isDisabled;
  final bool isPrimary;
  final HapticFeedbackType hapticType;

  const MatchActionButtonConfig({
    required this.icon,
    required this.color,
    required this.label,
    required this.tooltip,
    this.size = 56.0,
    this.iconSize = 24.0,
    this.onPressed,
    this.badge,
    this.isDisabled = false,
    this.isPrimary = false,
    this.hapticType = HapticFeedbackType.selection,
  });
}

enum HapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
}

/// Professional action button component for match screen
///
/// Features:
/// - Smooth press animations with proper feedback
/// - Accessibility support with semantic labels
/// - Haptic feedback variations
/// - Disabled state handling
/// - Badge support for counters
/// - Theme-aware styling
class MatchActionButton extends StatefulWidget {
  final MatchActionButtonConfig config;
  final Duration animationDuration;
  final bool showLabel;

  const MatchActionButton({
    super.key,
    required this.config,
    this.animationDuration = const Duration(milliseconds: 150),
    this.showLabel = true,
  });

  @override
  State<MatchActionButton> createState() => _MatchActionButtonState();
}

class _MatchActionButtonState extends State<MatchActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isPressed = false;

  // Design constants
  static const double _pressedScale = 0.90;
  static const double _normalScale = 1.0;
  static const double _normalElevation = 8.0;
  static const double _pressedElevation = 2.0;
  static const double _shadowSpread = 2.0;
  static const double _borderWidth = 2.5;
  static const double _badgeBorderWidth = 2.5;
  static const double _badgePadding = 7.0;
  static const double _badgeTopOffset = -6.0;
  static const double _badgeRightOffset = -6.0;
  static const double _labelSpacing = 6.0;
  static const double _labelFontSize = 12.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _scaleAnimation = Tween<double>(
      begin: _normalScale,
      end: _pressedScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _elevationAnimation = Tween<double>(
      begin: _normalElevation,
      end: _pressedElevation,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.config.onPressed != null && !widget.config.isDisabled) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.config.onPressed != null && !widget.config.isDisabled) {
      setState(() => _isPressed = false);
      _controller.reverse();
      _triggerHaptic();
      widget.config.onPressed!();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  void _triggerHaptic() {
    switch (widget.config.hapticType) {
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.selection:
        HapticFeedback.selectionClick();
        break;
    }
  }

  Color _getButtonColor() {
    if (widget.config.isDisabled) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[800]!
          : Colors.grey[300]!;
    }
    return Theme.of(context).colorScheme.surface;
  }

  Color _getIconColor() {
    if (widget.config.isDisabled) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[600]!
          : Colors.grey[500]!;
    }
    return widget.config.color;
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled =
        widget.config.isDisabled || widget.config.onPressed == null;
    final displayIcon = isDisabled && widget.config.badge == null
        ? Icons.lock_outline
        : widget.config.icon;

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: widget.config.tooltip,
      hint: isDisabled ? 'Disabled: ${widget.config.tooltip}' : null,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Main button container
                      Container(
                        width: widget.config.size,
                        height: widget.config.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getButtonColor(),
                          border: widget.config.isPrimary
                              ? Border.all(
                                  color: widget.config.color.withOpacity(0.3),
                                  width: _borderWidth,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: _getIconColor().withOpacity(0.25),
                              spreadRadius: _shadowSpread,
                              blurRadius: _elevationAnimation.value,
                              offset: Offset(0, _elevationAnimation.value / 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            displayIcon,
                            color: _getIconColor(),
                            size: widget.config.iconSize,
                          ),
                        ),
                      ),

                      // Badge indicator
                      if (widget.config.badge != null && !isDisabled)
                        Positioned(
                          top: _badgeTopOffset,
                          right: _badgeRightOffset,
                          child: Container(
                            padding: const EdgeInsets.all(_badgePadding),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.config.color,
                                  widget.config.color.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: _badgeBorderWidth,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.config.color.withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.config.badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),

                      // Primary indicator (subtle pulse)
                      if (widget.config.isPrimary && !isDisabled)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.config.color.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            // Label
            if (widget.showLabel) ...[
              const SizedBox(height: _labelSpacing),
              AnimatedOpacity(
                opacity: isDisabled ? 0.5 : 1.0,
                duration: widget.animationDuration,
                child: Text(
                  widget.config.label,
                  style: TextStyle(
                    fontSize: _labelFontSize,
                    fontWeight: FontWeight.w600,
                    color: isDisabled
                        ? Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.5)
                        : widget.config.color,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Debouncer utility to prevent rapid button presses
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
