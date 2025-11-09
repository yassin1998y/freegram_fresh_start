import 'dart:async';
import 'package:flutter/material.dart';

// === Entry Function (with optional tap callback) ===
void showIslandPopup({
  required BuildContext context,
  required String message,
  IconData? icon,
  VoidCallback? onTap, // Optional tap callback for navigation
}) {
  // CRITICAL FIX: Use Navigator's overlay instead of searching for MaterialApp's overlay
  // This ensures we always have access to an overlay when we have a Navigator context
  try {
    // Try to get the Navigator's overlay state
    final NavigatorState? navigator = Navigator.maybeOf(context);

    if (navigator == null) {
      debugPrint(
          '[Island Popup] No Navigator found in context, cannot show popup');
      return;
    }

    final OverlayState? overlayState = navigator.overlay;

    if (overlayState == null) {
      debugPrint(
          '[Island Popup] Navigator overlay not available, cannot show popup');
      return;
    }

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => IslandPopup(
        message: message,
        icon: icon,
        onDismiss: () {
          try {
            overlayEntry.remove();
          } catch (e) {
            debugPrint('[Island Popup] Error removing overlay: $e');
          }
        },
        onTap: onTap,
      ),
    );

    overlayState.insert(overlayEntry);
    debugPrint('[Island Popup] Successfully shown: $message');
  } catch (e) {
    debugPrint('[Island Popup] Error showing popup: $e');
    // Silently fail - don't crash the app
  }
}

// === THEME-AWARE ISLAND POPUP (Width-only Expansion) ===
class IslandPopup extends StatefulWidget {
  final String message;
  final IconData? icon;
  final VoidCallback onDismiss;
  final VoidCallback? onTap; // NEW: Optional tap callback

  const IslandPopup({
    super.key,
    required this.message,
    this.icon,
    required this.onDismiss,
    this.onTap, // NEW: Optional tap callback
  });

  @override
  State<IslandPopup> createState() => _IslandPopupState();
}

class _IslandPopupState extends State<IslandPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  Timer? _dismissTimer;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _controller.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _expanded = true);
    });

    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _closeIsland();
    });
  }

  void _closeIsland() {
    setState(() => _expanded = false);
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final backgroundColor = colorScheme.surface.withOpacity(0.95);
    final textColor = colorScheme.onSurface;
    final primaryAccent = colorScheme.primary;

    final screenWidth = MediaQuery.of(context).size.width;
    const collapsedWidth = 120.0;
    final expandedWidth = screenWidth * 0.85;

    return Positioned(
      top: 50,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: () {
            if (widget.onTap != null) {
              _closeIsland();
              widget.onTap!();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            width: _expanded ? expandedWidth : collapsedWidth,
            height: 55, // Slimmer height
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: theme.brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.6)
                      : Colors.grey.withOpacity(0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: primaryAccent.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Center(
              child: AnimatedOpacity(
                opacity: _expanded ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: primaryAccent.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(5),
                          child: Icon(
                            widget.icon,
                            color: primaryAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
