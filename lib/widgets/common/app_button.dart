// lib/widgets/common/app_button.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

/// Haptic feedback types for buttons
enum AppButtonHapticType {
  light,
  medium,
  heavy,
  selection,
  none,
}

/// Button style variants
enum AppButtonStyle {
  icon, // Icon-only button (for AppBar, etc.)
  action, // Icon + label button (for match screen, profile actions)
  text, // Text-only button
  elevated, // Elevated button with background
  outlined, // Outlined button
}

/// Unified button system for the app
///
/// This widget consolidates:
/// - AppBarActionButton (icon-only with badge)
/// - MatchActionButton (icon + label with animations)
/// - _buildActionButton (icon + label with loading state)
///
/// Features:
/// - Multiple style variants
/// - Badge support
/// - Loading state
/// - Disabled state
/// - Haptic feedback
/// - Animations
/// - Accessibility support
/// - Theme-aware styling
class AppButton extends StatefulWidget {
  /// Icon to display (required for icon and action styles)
  final IconData? icon;

  /// Label text (optional, shown below icon for action style)
  final String? label;

  /// Tooltip text for accessibility
  final String? tooltip;

  /// Callback when button is pressed
  final VoidCallback? onPressed;

  /// Button style variant
  final AppButtonStyle style;

  /// Custom color (if null, uses theme primary color)
  final Color? color;

  /// Badge text or number to display
  final String? badge;

  /// Whether to show badge as a dot (no text)
  final bool showBadgeDot;

  /// Whether button is disabled
  final bool isDisabled;

  /// Whether button is in loading state
  final bool isLoading;

  /// Whether button is primary (emphasized)
  final bool isPrimary;

  /// Button size (for icon and action styles)
  final double? size;

  /// Icon size
  final double? iconSize;

  /// Haptic feedback type
  final AppButtonHapticType hapticType;

  /// Animation duration
  final Duration animationDuration;

  /// Whether to show label (for action style)
  final bool showLabel;

  /// Custom child widget (overrides icon/label)
  final Widget? child;

  /// Custom background color
  final Color? backgroundColor;

  /// Border radius (defaults based on style)
  final double? borderRadius;

  /// Padding (defaults based on style)
  final EdgeInsets? padding;

  const AppButton({
    super.key,
    this.icon,
    this.label,
    this.tooltip,
    this.onPressed,
    this.style = AppButtonStyle.icon,
    this.color,
    this.badge,
    this.showBadgeDot = false,
    this.isDisabled = false,
    this.isLoading = false,
    this.isPrimary = false,
    this.size,
    this.iconSize,
    this.hapticType = AppButtonHapticType.selection,
    this.animationDuration = const Duration(milliseconds: 150),
    this.showLabel = true,
    this.child,
    this.backgroundColor,
    this.borderRadius,
    this.padding,
  });

  /// Icon-only button (replaces AppBarActionButton)
  const AppButton.icon({
    super.key,
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    Color? color,
    String? badge,
    bool showBadgeDot = false,
    bool isDisabled = false,
    bool isLoading = false,
    double? size,
    double? iconSize,
    AppButtonHapticType hapticType = AppButtonHapticType.light,
    this.animationDuration = const Duration(milliseconds: 150),
  })  : style = AppButtonStyle.icon,
        this.icon = icon,
        this.onPressed = onPressed,
        this.tooltip = tooltip,
        this.color = color,
        this.badge = badge,
        this.showBadgeDot = showBadgeDot,
        this.isDisabled = isDisabled,
        this.isLoading = isLoading,
        this.isPrimary = false,
        this.size = size,
        this.iconSize = iconSize,
        this.hapticType = hapticType,
        this.showLabel = false,
        this.label = null,
        this.child = null,
        this.backgroundColor = null,
        this.borderRadius = null,
        this.padding = null;

  /// Icon + label button (replaces MatchActionButton and _buildActionButton)
  const AppButton.action({
    super.key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    String? tooltip,
    Color? color,
    String? badge,
    bool isDisabled = false,
    bool isLoading = false,
    bool isPrimary = false,
    double? size,
    double? iconSize,
    AppButtonHapticType hapticType = AppButtonHapticType.selection,
    Duration animationDuration = const Duration(milliseconds: 150),
    bool showLabel = true,
    Color? backgroundColor,
    double? borderRadius,
  })  : style = AppButtonStyle.action,
        this.icon = icon,
        this.label = label,
        this.onPressed = onPressed,
        this.tooltip = tooltip,
        this.color = color,
        this.badge = badge,
        this.showBadgeDot = false,
        this.isDisabled = isDisabled,
        this.isLoading = isLoading,
        this.isPrimary = isPrimary,
        this.size = size,
        this.iconSize = iconSize,
        this.hapticType = hapticType,
        this.animationDuration = animationDuration,
        this.showLabel = showLabel,
        this.child = null,
        this.backgroundColor = backgroundColor,
        this.borderRadius = borderRadius,
        this.padding = null;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.90,
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
    if (_canPress()) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_canPress()) {
      setState(() => _isPressed = false);
      _controller.reverse();
      _triggerHaptic();
      widget.onPressed?.call();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  bool _canPress() {
    return widget.onPressed != null && !widget.isDisabled && !widget.isLoading;
  }

  void _triggerHaptic() {
    if (widget.hapticType == AppButtonHapticType.none) return;

    switch (widget.hapticType) {
      case AppButtonHapticType.light:
        HapticFeedback.lightImpact();
        break;
      case AppButtonHapticType.medium:
        HapticFeedback.mediumImpact();
        break;
      case AppButtonHapticType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case AppButtonHapticType.selection:
        HapticFeedback.selectionClick();
        break;
      case AppButtonHapticType.none:
        break;
    }
  }

  Color _getButtonColor(BuildContext context) {
    if (widget.isDisabled) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[800]!
          : Colors.grey[300]!;
    }
    return widget.backgroundColor ?? Theme.of(context).colorScheme.surface;
  }

  Color _getIconColor(BuildContext context) {
    if (widget.isDisabled) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[600]!
          : Colors.grey[500]!;
    }
    return widget.color ?? Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.style) {
      case AppButtonStyle.icon:
        return _buildIconButton(context);
      case AppButtonStyle.action:
        return _buildActionButton(context);
      case AppButtonStyle.text:
        return _buildTextButton(context);
      case AppButtonStyle.elevated:
        return _buildElevatedButton(context);
      case AppButtonStyle.outlined:
        return _buildOutlinedButton(context);
    }
  }

  /// Icon-only button (AppBar style)
  Widget _buildIconButton(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = widget.color ?? theme.colorScheme.onSurface;
    final size = widget.size ?? 40.0;
    final iconSize = widget.iconSize ?? 22.0;

    return Semantics(
      button: true,
      enabled: _canPress(),
      label: widget.tooltip ?? '',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _canPress()
                    ? () {
                        _triggerHaptic();
                        widget.onPressed?.call();
                      }
                    : null,
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: buttonColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  ),
                  child: widget.isLoading
                      ? Center(
                          child: AppProgressIndicator(
                            size: iconSize * 0.6,
                            strokeWidth: 2,
                            color: buttonColor,
                          ),
                        )
                      : Icon(
                          widget.icon,
                          size: iconSize,
                          color: buttonColor,
                        ),
                ),
              ),
            ),
            if (widget.badge != null || widget.showBadgeDot)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.badge != null ? 6 : 8,
                    vertical: widget.badge != null ? 2 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    shape: widget.badge != null
                        ? BoxShape.rectangle
                        : BoxShape.circle,
                    borderRadius:
                        widget.badge != null ? BorderRadius.circular(10) : null,
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  child: widget.badge != null
                      ? Text(
                          widget.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Icon + label button (Match/Action style)
  Widget _buildActionButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = widget.isDisabled || widget.onPressed == null;
    final buttonSize = widget.size ?? 56.0;
    final iconSize = widget.iconSize ?? 24.0;
    final iconColor = _getIconColor(context);
    final buttonColor = _getButtonColor(context);

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: widget.tooltip ?? widget.label ?? '',
      hint: isDisabled ? 'Disabled: ${widget.tooltip ?? widget.label}' : null,
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
                        width: buttonSize,
                        height: buttonSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: buttonColor,
                          border: widget.isPrimary
                              ? Border.all(
                                  color: iconColor.withOpacity(0.3),
                                  width: 2.5,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: iconColor.withOpacity(0.25),
                              spreadRadius: 2.0,
                              blurRadius: 8.0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: widget.isLoading
                            ? Center(
                                child: AppProgressIndicator(
                                  size: iconSize * 0.6,
                                  strokeWidth: 2,
                                  color: iconColor,
                                ),
                              )
                            : Icon(
                                widget.icon,
                                color: iconColor,
                                size: iconSize,
                              ),
                      ),

                      // Badge indicator
                      if (widget.badge != null && !isDisabled)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  iconColor,
                                  iconColor.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: iconColor.withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),

                      // Primary indicator
                      if (widget.isPrimary && !isDisabled)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: iconColor.withOpacity(0.2),
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
            if (widget.showLabel && widget.label != null) ...[
              const SizedBox(height: 6),
              AnimatedOpacity(
                opacity: isDisabled ? 0.5 : 1.0,
                duration: widget.animationDuration,
                child: Text(
                  widget.label!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDisabled
                        ? theme.textTheme.bodySmall?.color?.withOpacity(0.5)
                        : iconColor,
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

  /// Text-only button
  Widget _buildTextButton(BuildContext context) {
    // TODO: Implement text button style
    return const SizedBox.shrink();
  }

  /// Elevated button
  Widget _buildElevatedButton(BuildContext context) {
    // TODO: Implement elevated button style
    return const SizedBox.shrink();
  }

  /// Outlined button
  Widget _buildOutlinedButton(BuildContext context) {
    // TODO: Implement outlined button style
    return const SizedBox.shrink();
  }
}

/// Convenience widget for icon-only buttons (replaces AppBarActionButton)
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;
  final String? badge;
  final bool showBadgeDot;
  final bool isDisabled;
  final bool isLoading;
  final double? size;
  final double? iconSize;
  final AppButtonHapticType hapticType;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.badge,
    this.showBadgeDot = false,
    this.isDisabled = false,
    this.isLoading = false,
    this.size,
    this.iconSize,
    this.hapticType = AppButtonHapticType.light,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton.icon(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      color: color,
      badge: badge,
      showBadgeDot: showBadgeDot,
      isDisabled: isDisabled,
      isLoading: isLoading,
      size: size,
      iconSize: iconSize,
      hapticType: hapticType,
    );
  }
}

/// Convenience widget for action buttons (replaces MatchActionButton)
class AppActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final String? badge;
  final bool isDisabled;
  final bool isLoading;
  final bool isPrimary;
  final double? size;
  final double? iconSize;
  final AppButtonHapticType hapticType;
  final Duration animationDuration;
  final bool showLabel;
  final Color? backgroundColor;
  final double? borderRadius;

  const AppActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.badge,
    this.isDisabled = false,
    this.isLoading = false,
    this.isPrimary = false,
    this.size,
    this.iconSize,
    this.hapticType = AppButtonHapticType.selection,
    this.animationDuration = const Duration(milliseconds: 150),
    this.showLabel = true,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton.action(
      icon: icon,
      label: label,
      onPressed: onPressed,
      tooltip: tooltip,
      color: color,
      badge: badge,
      isDisabled: isDisabled,
      isLoading: isLoading,
      isPrimary: isPrimary,
      size: size,
      iconSize: iconSize,
      hapticType: hapticType,
      animationDuration: animationDuration,
      showLabel: showLabel,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
    );
  }
}
