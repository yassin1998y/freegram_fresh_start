// lib/services/loading_overlay_service.dart
import 'package:flutter/material.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

/// Professional Loading Overlay Service
/// Provides unified loading indicators with smooth animations
class LoadingOverlayService {
  static final LoadingOverlayService _instance =
      LoadingOverlayService._internal();
  factory LoadingOverlayService() => _instance;
  LoadingOverlayService._internal();

  OverlayEntry? _overlayEntry;
  bool _isShowing = false;

  /// Show loading overlay with message
  void show(
    BuildContext context, {
    String? message,
    Color? backgroundColor,
    Color? indicatorColor,
    bool barrierDismissible = false,
  }) {
    if (_isShowing) {
      debugPrint('[LoadingOverlay] Already showing, skipping');
      return;
    }

    _isShowing = true;

    _overlayEntry = OverlayEntry(
      builder: (context) => _LoadingOverlayWidget(
        message: message,
        backgroundColor: backgroundColor,
        indicatorColor: indicatorColor,
        barrierDismissible: barrierDismissible,
        onDismiss: () => hide(),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Hide loading overlay
  void hide() {
    if (!_isShowing) return;

    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
  }

  /// Check if overlay is currently showing
  bool get isShowing => _isShowing;

  /// Execute async operation with loading overlay
  Future<T> showDuring<T>(
    BuildContext context,
    Future<T> Function() operation, {
    String? message,
  }) async {
    try {
      show(context, message: message);
      final result = await operation();
      return result;
    } finally {
      hide();
    }
  }
}

/// Loading overlay widget
class _LoadingOverlayWidget extends StatefulWidget {
  final String? message;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final bool barrierDismissible;
  final VoidCallback onDismiss;

  const _LoadingOverlayWidget({
    this.message,
    this.backgroundColor,
    this.indicatorColor,
    required this.barrierDismissible,
    required this.onDismiss,
  });

  @override
  State<_LoadingOverlayWidget> createState() => _LoadingOverlayWidgetState();
}

class _LoadingOverlayWidgetState extends State<_LoadingOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.barrierDismissible ? widget.onDismiss : null,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            color: widget.backgroundColor ?? Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppProgressIndicator(
                        color: widget.indicatorColor ??
                            Theme.of(context).colorScheme.primary,
                        strokeWidth: 3,
                      ),
                      if (widget.message != null) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 200,
                          child: Text(
                            widget.message!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color,
                                ),
                          ),
                        ),
                      ],
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

/// Global shorthand functions for easier use
final loadingOverlay = LoadingOverlayService();

/// Extension for BuildContext to show loading overlay easily
extension LoadingOverlayExtension on BuildContext {
  void showLoading({String? message}) {
    loadingOverlay.show(this, message: message);
  }

  void hideLoading() {
    loadingOverlay.hide();
  }

  Future<T> showLoadingDuring<T>(
    Future<T> Function() operation, {
    String? message,
  }) {
    return loadingOverlay.showDuring(this, operation, message: message);
  }
}
