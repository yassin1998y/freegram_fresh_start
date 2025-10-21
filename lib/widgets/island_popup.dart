import 'dart:async';
import 'package:flutter/material.dart';

// Helper function to show the popup from anywhere in the app.
void showIslandPopup({
  required BuildContext context,
  required String message,
  IconData? icon,
  Color? iconColor,
}) {
  // Overlay allows us to display this widget on top of everything else.
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => IslandPopup(
      message: message,
      icon: icon,
      iconColor: iconColor,
      onDismiss: () {
        overlayEntry.remove();
      },
    ),
  );

  overlay.insert(overlayEntry);
}

class IslandPopup extends StatefulWidget {
  final String message;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback onDismiss;

  const IslandPopup({
    super.key,
    required this.message,
    this.icon,
    this.iconColor,
    required this.onDismiss,
  });

  @override
  State<IslandPopup> createState() => _IslandPopupState();
}

class _IslandPopupState extends State<IslandPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350), // Faster animation
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -2.0), // Start above the screen
      end: const Offset(0, 0.5),   // Settle just below the status bar
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Animate in, wait, and then animate out.
    _controller.forward().then((_) {
      _dismissTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _controller.reverse().then((_) => widget.onDismiss());
        }
      });
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
    // SafeArea ensures the popup doesn't get hidden by the status bar/notch.
    return SafeArea(
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null)
                  Icon(
                    widget.icon,
                    color: widget.iconColor ?? Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                if (widget.icon != null) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}