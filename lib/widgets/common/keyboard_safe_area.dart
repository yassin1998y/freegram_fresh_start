// lib/widgets/common/keyboard_safe_area.dart
// Utility widget to handle keyboard and system UI overlays properly

import 'package:flutter/material.dart';

/// Wrapper widget that ensures content is not hidden by keyboard or system UI
/// Use this around input fields and bottom-aligned content
class KeyboardSafeArea extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;

  const KeyboardSafeArea({
    Key? key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewInsets = mediaQuery.viewInsets;
    final padding = mediaQuery.padding;

    return Padding(
      padding: EdgeInsets.only(
        top: top ? padding.top : 0,
        bottom: bottom ? (padding.bottom + viewInsets.bottom) : 0,
        left: left ? padding.left : 0,
        right: right ? padding.right : 0,
      ),
      child: child,
    );
  }
}

/// Wrapper for bottom-aligned input fields that need keyboard padding
class KeyboardAwareInput extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const KeyboardAwareInput({
    Key? key,
    required this.child,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final bottomPadding = mediaQuery.padding.bottom;

    return AnimatedPadding(
      padding: padding ??
          EdgeInsets.only(
            bottom: keyboardHeight > 0 ? keyboardHeight : bottomPadding,
          ),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: SafeArea(
        top: false,
        child: child,
      ),
    );
  }
}

