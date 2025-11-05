// lib/services/navigation_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Professional Navigation Service with smooth transitions
/// Provides centralized navigation control and consistent animations
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  BuildContext? get context => navigatorKey.currentContext;
  NavigatorState? get navigator => navigatorKey.currentState;

  // --- Duplicate navigation prevention ---
  DateTime _lastNavigationAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _navigationInProgress = false;
  Duration _debounceInterval = const Duration(milliseconds: 500);

  void setDebounceInterval(Duration interval) {
    _debounceInterval = interval;
  }

  bool _canNavigate() {
    final now = DateTime.now();
    if (_navigationInProgress) return false;
    if (now.difference(_lastNavigationAt) < _debounceInterval) return false;
    _lastNavigationAt = now;
    _navigationInProgress = true;
    // Release the in-flight flag shortly after push completes
    Future.microtask(() => _navigationInProgress = false);
    return true;
  }

  /// Navigation with slide transition (default)
  Future<T?> navigateTo<T>(
    Widget page, {
    PageTransition transition = PageTransition.slide,
    Duration duration = const Duration(milliseconds: 300),
    bool replace = false,
    bool clearStack = false,
  }) {
    if (navigator == null) {
      debugPrint('[NavigationService] Navigator not ready');
      return Future.value(null);
    }

    if (!_canNavigate()) {
      debugPrint('[NavigationService] Navigation debounced');
      return Future.value(null);
    }

    try {
      final route = _buildRoute<T>(page, transition, duration);
      if (clearStack) {
        return navigator!.pushAndRemoveUntil(route, (route) => false);
      } else if (replace) {
        return navigator!.pushReplacement(route);
      } else {
        return navigator!.push(route);
      }
    } catch (e, st) {
      debugPrint('[NavigationService] Error during navigateTo: $e');
      debugPrint('$st');
      return Future.value(null);
    }
  }

  /// Navigate with fade transition (for overlays and modals)
  Future<T?> navigateToFade<T>(Widget page) {
    return navigateTo<T>(
      page,
      transition: PageTransition.fade,
      duration: const Duration(milliseconds: 250),
    );
  }

  /// Navigate with scale transition (for profile cards, modals)
  Future<T?> navigateToScale<T>(Widget page) {
    return navigateTo<T>(
      page,
      transition: PageTransition.scale,
      duration: const Duration(milliseconds: 300),
    );
  }

  /// Navigate with iOS-style Cupertino transition
  Future<T?> navigateToCupertino<T>(Widget page) {
    return navigateTo<T>(
      page,
      transition: PageTransition.cupertino,
      duration: const Duration(milliseconds: 350),
    );
  }

  /// Navigate with bottom sheet style slide up
  Future<T?> navigateToBottomSheet<T>(Widget page) {
    return navigateTo<T>(
      page,
      transition: PageTransition.slideUp,
      duration: const Duration(milliseconds: 350),
    );
  }

  /// Navigate using route name and optional arguments (centralized)
  Future<T?> navigateNamed<T>(
    String routeName, {
    Map<String, dynamic>? arguments,
    bool replace = false,
    bool clearStack = false,
  }) {
    if (navigator == null) {
      debugPrint('[NavigationService] Navigator not ready');
      return Future.value(null);
    }

    if (!_canNavigate()) {
      debugPrint('[NavigationService] Navigation (named) debounced');
      return Future.value(null);
    }

    try {
      if (clearStack) {
        return navigator!.pushNamedAndRemoveUntil<T>(
          routeName,
          (route) => false,
          arguments: arguments,
        );
      } else if (replace) {
        return navigator!.pushReplacementNamed<T, T>(
          routeName,
          arguments: arguments,
        );
      } else {
        return navigator!.pushNamed<T>(
          routeName,
          arguments: arguments,
        );
      }
    } catch (e, st) {
      debugPrint('[NavigationService] Error during navigateNamed: $e');
      debugPrint('$st');
      return Future.value(null);
    }
  }

  /// Show modal bottom sheet with smooth animation
  Future<T?> showModalSheet<T>({
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
  }) {
    if (context == null) return Future.value(null);

    return showModalBottomSheet<T>(
      context: context!,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      backgroundColor: backgroundColor ?? Colors.transparent,
      builder: (_) => child,
    );
  }

  /// Show dialog with fade animation
  Future<T?> showDialogWithFade<T>({
    required Widget child,
    bool barrierDismissible = true,
  }) {
    if (context == null) return Future.value(null);

    return showGeneralDialog<T>(
      context: context!,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }

  /// Go back with optional result
  void goBack<T>([T? result]) {
    if (navigator?.canPop() ?? false) {
      navigator!.pop(result);
    }
  }

  /// Go back to root (clear all navigation stack)
  void goBackToRoot() {
    if (navigator == null) {
      debugPrint(
          '[NavigationService] Cannot go back to root: Navigator not ready');
      return;
    }

    try {
      // Clear the navigation in-progress flag to allow this operation
      _navigationInProgress = false;

      // Pop all routes until we reach the first route (home/AuthWrapper)
      navigator!.popUntil((route) {
        final isFirst = route.isFirst;
        if (isFirst) {
          debugPrint(
              '[NavigationService] Cleared navigation stack. Reached root route.');
        }
        return isFirst;
      });

      debugPrint('[NavigationService] Navigation stack cleared successfully');
    } catch (e, st) {
      debugPrint('[NavigationService] Error clearing navigation stack: $e');
      debugPrint('$st');
    }
  }

  /// Pop until a specific route name
  void popUntilRoute(String routeName) {
    if (navigator == null) return;
    navigator!.popUntil((route) {
      return route.settings.name == routeName || route.isFirst;
    });
  }

  /// Build custom route based on transition type
  PageRoute<T> _buildRoute<T>(
    Widget page,
    PageTransition transition,
    Duration duration,
  ) {
    switch (transition) {
      case PageTransition.fade:
        return _FadePageRoute<T>(child: page, duration: duration);
      case PageTransition.scale:
        return _ScalePageRoute<T>(child: page, duration: duration);
      case PageTransition.slideUp:
        return _SlideUpPageRoute<T>(child: page, duration: duration);
      case PageTransition.cupertino:
        return CupertinoPageRoute<T>(builder: (_) => page);
      case PageTransition.slide:
        return _SlidePageRoute<T>(child: page, duration: duration);
    }
  }
}

/// Page transition types
enum PageTransition {
  slide,
  fade,
  scale,
  slideUp,
  cupertino,
}

/// Custom slide page route (default - slides from right)
class _SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Duration duration;

  _SlidePageRoute({required this.child, required this.duration})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            var offsetAnimation = animation.drive(tween);

            // Add fade for secondary animation (previous page)
            var fadeAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.easeOut,
              ),
            );

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: child,
              ),
            );
          },
        );
}

/// Fade page route
class _FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Duration duration;

  _FadePageRoute({required this.child, required this.duration})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
        );
}

/// Scale page route (zoom in/out)
class _ScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Duration duration;

  _ScalePageRoute({required this.child, required this.duration})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          opaque: false,
          barrierColor: Colors.black54,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            );

            var fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
        );
}

/// Slide up page route (for bottom sheets/modals)
class _SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Duration duration;

  _SlideUpPageRoute({required this.child, required this.duration})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        );
}
