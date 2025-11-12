// lib/widgets/core/hide_on_scroll_wrapper.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Reusable wrapper that animates a child widget off-screen when scrolling down
/// and back in when scrolling up.
///
/// Features:
/// - Listens to scroll direction from ScrollController OR ValueNotifier
/// - Smooth animations using DesignTokens
/// - Prevents unnecessary rebuilds with const child
///
/// Usage with ScrollController:
/// ```dart
/// HideOnScrollWrapper(
///   scrollController: _scrollController,
///   height: 80,
///   child: BottomNavigationBar(...),
/// )
/// ```
///
/// Usage with ValueNotifier (for callback-based scroll detection):
/// ```dart
/// HideOnScrollWrapper(
///   scrollDirection: _isScrollingDownNotifier,
///   height: 80,
///   child: BottomNavigationBar(...),
/// )
/// ```
class HideOnScrollWrapper extends StatefulWidget {
  /// The widget to show/hide
  final Widget child;

  /// ScrollController to listen to for scroll direction (if provided)
  final ScrollController? scrollController;

  /// ValueNotifier<bool> for scroll direction (true = scrolling down, false = scrolling up)
  /// Alternative to scrollController for callback-based scroll detection
  final ValueNotifier<bool>? scrollDirection;

  /// Height of the child widget (for calculating translation offset)
  final double height;

  /// Optional: Minimum scroll offset before hiding starts (default: 0)
  /// Only used when scrollController is provided
  final double minScrollOffset;

  /// Optional: Custom animation duration (defaults to AnimationTokens.normal)
  final Duration? duration;

  /// Optional: Custom animation curve (defaults to AnimationTokens.easeOutCubic)
  final Curve? curve;

  const HideOnScrollWrapper({
    super.key,
    required this.child,
    required this.height,
    this.scrollController,
    this.scrollDirection,
    this.minScrollOffset = 0.0,
    this.duration,
    this.curve,
  }) : assert(
          scrollController != null || scrollDirection != null,
          'Either scrollController or scrollDirection must be provided',
        );

  @override
  State<HideOnScrollWrapper> createState() => _HideOnScrollWrapperState();
}

class _HideOnScrollWrapperState extends State<HideOnScrollWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translationAnimation;
  late Animation<double> _opacityAnimation;

  double _lastScrollOffset = 0.0;
  bool _isScrollingDown = false;
  bool _isHidden = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? AnimationTokens.normal,
    );

    // Create translation animation (moves widget down by its height)
    _translationAnimation = Tween<double>(
      begin: 0.0,
      end: widget.height,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve ?? AnimationTokens.easeOutCubic,
    ));

    // Create opacity animation (fades out when hiding)
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve ?? AnimationTokens.easeOutCubic,
    ));

    // Listen to scroll controller or ValueNotifier
    if (widget.scrollController != null) {
      widget.scrollController!.addListener(_onScroll);
    } else if (widget.scrollDirection != null) {
      widget.scrollDirection!.addListener(_onScrollDirectionChanged);
    }
  }

  @override
  void dispose() {
    if (widget.scrollController != null) {
      widget.scrollController!.removeListener(_onScroll);
    } else if (widget.scrollDirection != null) {
      widget.scrollDirection!.removeListener(_onScrollDirectionChanged);
    }
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.scrollController == null ||
        !widget.scrollController!.hasClients) {
      return;
    }

    final currentOffset = widget.scrollController!.position.pixels;
    final scrollDelta = currentOffset - _lastScrollOffset;

    // Check if at top of scroll
    final isAtTop = currentOffset <= widget.minScrollOffset + 10;

    // Show widget if at top
    if (isAtTop) {
      if (_isHidden) {
        _show();
      }
      _lastScrollOffset = currentOffset;
      return;
    }

    // Only process if scroll offset changed significantly (to avoid jitter)
    if (scrollDelta.abs() > 5) {
      final isScrollingDown = scrollDelta > 0;

      // Only update if direction changed
      if (isScrollingDown != _isScrollingDown) {
        _isScrollingDown = isScrollingDown;

        if (_isScrollingDown && !_isHidden) {
          _hide();
        } else if (!_isScrollingDown && _isHidden) {
          _show();
        }
      }

      _lastScrollOffset = currentOffset;
    }
  }

  void _onScrollDirectionChanged() {
    if (widget.scrollDirection == null) return;

    final isScrollingDown = widget.scrollDirection!.value;

    // Only update if direction changed
    if (isScrollingDown != _isScrollingDown) {
      _isScrollingDown = isScrollingDown;

      if (_isScrollingDown && !_isHidden) {
        _hide();
      } else if (!_isScrollingDown && _isHidden) {
        _show();
      }
    }
  }

  void _hide() {
    if (!_isHidden) {
      setState(() => _isHidden = true);
      _controller.forward();
    }
  }

  void _show() {
    if (_isHidden) {
      setState(() => _isHidden = false);
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translationAnimation.value),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}
