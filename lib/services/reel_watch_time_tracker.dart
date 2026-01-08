// lib/services/reel_watch_time_tracker.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Tracks watch time for a reel and detects completion/skip events
class ReelWatchTimeTracker {
  final String reelId;
  final double duration; // Total duration in seconds
  final Function(double watchTime, double watchPercentage) onWatchTimeUpdate;
  final Function() onCompleted;
  final Function() onSkipped;

  Timer? _timer;
  double _watchTime = 0.0;
  double _currentPosition = 0.0;
  bool _isTracking = false;
  bool _hasCompleted = false;
  bool _hasSkipped = false;

  ReelWatchTimeTracker({
    required this.reelId,
    required this.duration,
    required this.onWatchTimeUpdate,
    required this.onCompleted,
    required this.onSkipped,
  });

  /// Start tracking watch time
  void start() {
    if (_isTracking) return;
    _isTracking = true;

    // Track every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _watchTime += 1.0;
      _updateWatchPercentage();
    });
  }

  /// Pause tracking
  void pause() {
    _isTracking = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Resume tracking
  void resume() {
    if (_isTracking) return;
    start();
  }

  /// Update current video position
  void updatePosition(double position) {
    _currentPosition = position;
    _updateWatchPercentage();
  }

  /// Stop tracking and record final watch time
  void stop() {
    pause();
    _recordWatchTime();
  }

  /// Dispose and cleanup
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void _updateWatchPercentage() {
    if (duration <= 0) return;

    final watchPercentage = (_currentPosition / duration) * 100;

    // Check for completion (watched >95%)
    if (watchPercentage >= 95 && !_hasCompleted) {
      _hasCompleted = true;
      onCompleted();
      debugPrint('ReelWatchTimeTracker: Reel $reelId completed');
    }

    // Check for skip (watched <3 seconds and swiped away)
    if (_watchTime < 3 && !_isTracking && !_hasSkipped) {
      _hasSkipped = true;
      onSkipped();
      debugPrint('ReelWatchTimeTracker: Reel $reelId skipped');
    }

    // Update watch time periodically
    onWatchTimeUpdate(_watchTime, watchPercentage.clamp(0, 100));
  }

  void _recordWatchTime() {
    final watchPercentage =
        duration > 0 ? (_currentPosition / duration) * 100 : 0.0;
    onWatchTimeUpdate(_watchTime, watchPercentage.clamp(0, 100));
    debugPrint(
        'ReelWatchTimeTracker: Reel $reelId - Watch time: ${_watchTime}s, Percentage: ${watchPercentage.toStringAsFixed(1)}%');
  }
}
