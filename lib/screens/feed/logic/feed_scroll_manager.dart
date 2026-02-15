// lib/screens/feed/logic/feed_scroll_manager.dart

import 'dart:async';
import 'package:flutter/material.dart';

/// Pure Dart class to handle scroll logic for feed screens.
///
/// Responsibilities:
/// - Debounce scroll events
/// - Detect scroll direction
/// - Trigger load more when near bottom
/// - Notify about scroll direction changes
///
/// Usage:
/// ```dart
/// final manager = FeedScrollManager(
///   scrollController: _scrollController,
///   onLoadMore: () => _loadMore(),
///   onScrollDown: () => _hideNavBar(),
///   onScrollUp: () => _showNavBar(),
/// );
///
/// // In dispose:
/// manager.dispose();
/// ```
class FeedScrollManager {
  final ScrollController scrollController;
  final VoidCallback? onLoadMore;
  final VoidCallback? onScrollDown;
  final VoidCallback? onScrollUp;

  // Debouncing
  Timer? _scrollDebounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 150);

  // Scroll direction tracking
  double _lastScrollOffset = 0.0;
  bool _isScrollingDown = false;
  bool _hasInitialized = false;
  static const double _scrollDeltaThreshold =
      5.0; // Minimum change to detect direction
  static const double _topThreshold = 10.0; // Consider at top if within 10px

  // Load more threshold
  static const double _loadMoreThreshold =
      200.0; // Trigger when within 200px of bottom

  // Scroll-to-top button visibility
  bool _showScrollToTop = false;
  static const double _scrollToTopThreshold =
      3.0; // Show after 3 screen heights
  final ValueNotifier<bool> showScrollToTopNotifier =
      ValueNotifier<bool>(false);

  FeedScrollManager({
    required this.scrollController,
    this.onLoadMore,
    this.onScrollDown,
    this.onScrollUp,
  }) {
    scrollController.addListener(_handleScroll);
    // Initialize immediately if controller is ready
    if (scrollController.hasClients) {
      _hasInitialized = true;
      final isAtTop = scrollController.position.pixels <= _topThreshold;
      if (isAtTop && onScrollUp != null) {
        onScrollUp!();
      }
    } else {
      // Mark as initialized on first scroll event
      _hasInitialized = false;
    }
  }

  void _handleScroll() {
    if (!scrollController.hasClients) return;

    // Mark as initialized on first scroll event
    if (!_hasInitialized) {
      _hasInitialized = true;
    }

    final currentOffset = scrollController.position.pixels;
    final position = scrollController.position;
    final viewportHeight = position.viewportDimension;

    // Check if at top
    final isAtTop = currentOffset <= _topThreshold;
    if (isAtTop) {
      if (_isScrollingDown) {
        _isScrollingDown = false;
        onScrollUp?.call();
      }
      _lastScrollOffset = currentOffset;
      _updateScrollToTopVisibility(false);
      return;
    }

    // Detect scroll direction (only if offset changed significantly)
    if (_hasInitialized) {
      final scrollDelta = currentOffset - _lastScrollOffset;

      if (scrollDelta.abs() > _scrollDeltaThreshold && _lastScrollOffset > 0) {
        final isScrollingDown = scrollDelta > 0;

        if (isScrollingDown != _isScrollingDown) {
          _isScrollingDown = isScrollingDown;

          if (_isScrollingDown) {
            onScrollDown?.call();
          } else {
            onScrollUp?.call();
          }
        }
      }

      _lastScrollOffset = currentOffset;
    } else {
      // Update last scroll offset even if not initialized yet
      _lastScrollOffset = currentOffset;
    }

    // Update scroll-to-top button visibility
    final shouldShow = currentOffset > viewportHeight * _scrollToTopThreshold;
    _updateScrollToTopVisibility(shouldShow);

    // Debounce load more check
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(_debounceDuration, () {
      if (!scrollController.hasClients) return;

      final position = scrollController.position;
      final distanceFromBottom = position.maxScrollExtent - position.pixels;

      // Trigger load more when within threshold of bottom
      if (distanceFromBottom <= _loadMoreThreshold && onLoadMore != null) {
        onLoadMore!();
      }
    });
  }

  void _updateScrollToTopVisibility(bool shouldShow) {
    if (_showScrollToTop != shouldShow) {
      _showScrollToTop = shouldShow;
      showScrollToTopNotifier.value = shouldShow;
    }
  }

  /// Scroll to top with animation
  void scrollToTop({bool animated = true}) {
    if (!scrollController.hasClients) return;

    try {
      if (animated) {
        scrollController.animateTo(
          scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        scrollController.jumpTo(scrollController.position.minScrollExtent);
      }

      // Immediately show nav bars when scrolling to top
      onScrollUp?.call();
      _updateScrollToTopVisibility(false);
    } catch (e) {
      // If animation fails, just jump to top
      scrollController.jumpTo(scrollController.position.minScrollExtent);
    }
  }

  /// Dispose and clean up resources
  void dispose() {
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = null;
    scrollController.removeListener(_handleScroll);
    showScrollToTopNotifier.dispose();
  }
}
