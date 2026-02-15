import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:lottie/lottie.dart';

/// Task 3: Memory & Asset Optimization
/// A global mixin to track and evict video controllers and Lottie caches
/// when leaving memory-intensive screens like ReelsFeed or MatchScreen.
mixin GlobalMemoryManager {
  static final Set<VideoPlayerController> _activeControllers = {};

  /// Registers a controller to be tracked for global eviction
  void registerController(VideoPlayerController controller) {
    _activeControllers.add(controller);
    debugPrint(
        '🧠 [MEMORY] Registered video controller. Active: ${_activeControllers.length}');
  }

  /// Unregisters a controller
  void unregisterController(VideoPlayerController controller) {
    _activeControllers.remove(controller);
  }

  /// Evicts all tracked resources and clears Lottie cache.
  /// Should be called on dispose() of main containers (ReelsFeedScreen, MatchScreen).
  Future<void> evictResources() async {
    debugPrint('🧠 [MEMORY] Evicting resources for $runtimeType...');

    // 1. Evict Video Controllers
    int evictedCount = 0;
    for (final controller in _activeControllers) {
      if (controller.value.isInitialized) {
        await controller.pause();
        await controller.dispose();
        evictedCount++;
      }
    }
    _activeControllers.clear();
    debugPrint('🧠 [MEMORY] Evicted $evictedCount video controllers.');

    // 2. Clear Lottie Cache (to free up memory from animations)
    Lottie.cache.clear();
    debugPrint('🧠 [MEMORY] Lottie cache cleared.');
  }
}
