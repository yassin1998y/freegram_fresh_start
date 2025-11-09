// lib/services/intelligent_prefetch_service.dart

import 'package:shared_preferences/shared_preferences.dart';
// NOTE: Temporarily disabled due to workmanager compatibility issues with Flutter Android embedding
// import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';

/// Phase 1.3: Intelligent Background Prefetch Service
///
/// This service learns user app usage patterns and schedules background
/// prefetching tasks to pre-load feed content before users open the app.
///
/// Features:
/// - Tracks app open times to learn usage patterns
/// - Predicts next app open time
/// - Schedules background prefetch tasks 5 minutes before predicted open time
/// - Only runs on WiFi with sufficient battery
class IntelligentPrefetchService {
  final SharedPreferences _prefs;
  static const String _prefKeyPrefix = 'app_open_hour_';

  IntelligentPrefetchService({required SharedPreferences prefs})
      : _prefs = prefs;

  /// Records an app open event for pattern learning.
  ///
  /// Call this when the app is opened (e.g., in AppLifecycleState.resumed).
  void recordAppOpen() {
    final hour = DateTime.now().hour;
    final key = '$_prefKeyPrefix$hour';
    final count = (_prefs.getInt(key) ?? 0) + 1;
    _prefs.setInt(key, count);
    debugPrint(
        'IntelligentPrefetchService: Recorded app open at hour $hour (count: $count)');
  }

  /// Gets the most common hour when the user opens the app.
  ///
  /// Returns the hour (0-23) with the highest open count, or null if no data.
  int? _getMostCommonOpenHour() {
    int? mostCommonHour;
    int maxCount = 0;

    for (int i = 0; i < 24; i++) {
      final count = _prefs.getInt('$_prefKeyPrefix$i') ?? 0;
      if (count > maxCount) {
        maxCount = count;
        mostCommonHour = i;
      }
    }

    if (mostCommonHour != null) {
      debugPrint(
          'IntelligentPrefetchService: Most common open hour is $mostCommonHour (count: $maxCount)');
    } else {
      debugPrint(
          'IntelligentPrefetchService: No app open pattern data available');
    }

    return mostCommonHour;
  }

  /// Predicts the next time the user will likely open the app.
  ///
  /// Returns a DateTime 5 minutes before the predicted open time, or null if
  /// no pattern can be determined.
  DateTime? predictNextAppOpen() {
    final commonHour = _getMostCommonOpenHour();
    if (commonHour == null) return null;

    final now = DateTime.now();
    var prefetchTime = DateTime(now.year, now.month, now.day, commonHour);

    // If the predicted time has already passed today, schedule for tomorrow
    if (prefetchTime.isBefore(now)) {
      prefetchTime = prefetchTime.add(const Duration(days: 1));
    }

    // Schedule prefetch 5 minutes before predicted open time
    prefetchTime = prefetchTime.subtract(const Duration(minutes: 5));

    debugPrint(
        'IntelligentPrefetchService: Predicted next app open at ${DateTime(prefetchTime.year, prefetchTime.month, prefetchTime.day, commonHour)}, scheduling prefetch at $prefetchTime');

    return prefetchTime;
  }

  /// Schedules a one-time background prefetch task.
  ///
  /// The task will be scheduled 5 minutes before the predicted next app open.
  /// Only schedules if:
  /// - A pattern can be determined
  /// - The predicted time is in the future
  /// - WorkManager is properly initialized
  ///
  /// NOTE: Temporarily disabled due to workmanager compatibility issues
  Future<void> scheduleBackgroundPrefetch() async {
    // NOTE: Background prefetching is temporarily disabled
    // Uncomment when workmanager compatibility is fixed or alternative solution is implemented
    debugPrint(
        'IntelligentPrefetchService: Background prefetch scheduling is temporarily disabled');
    return;
    
    // try {
    //   final prefetchTime = predictNextAppOpen();
    //   if (prefetchTime == null) {
    //     debugPrint(
    //         'IntelligentPrefetchService: Cannot schedule prefetch - no pattern data');
    //     return;
    //   }

    //   final delay = prefetchTime.difference(DateTime.now());
    //   if (delay.isNegative) {
    //     debugPrint(
    //         'IntelligentPrefetchService: Predicted time has passed, cannot schedule');
    //     return;
    //   }

    //   // Cancel any existing prefetch tasks
    //   await Workmanager().cancelByUniqueName('prefetch_feed_task');

    //   // Schedule new prefetch task
    //   await Workmanager().registerOneOffTask(
    //     'prefetch_feed_task',
    //     'prefetchFeedTask',
    //     initialDelay: delay,
    //     constraints: Constraints(
    //       networkType: NetworkType.connected,
    //       requiresBatteryNotLow: true,
    //     ),
    //     inputData: {
    //       'scheduledTime': prefetchTime.toIso8601String(),
    //     },
    //   );

    //   debugPrint(
    //       'IntelligentPrefetchService: Background prefetch scheduled for $prefetchTime (in ${delay.inMinutes} minutes)');
    // } catch (e) {
    //   debugPrint(
    //       'IntelligentPrefetchService: Error scheduling background prefetch: $e');
    // }
  }

  /// Cancels all scheduled prefetch tasks.
  ///
  /// NOTE: Temporarily disabled due to workmanager compatibility issues
  Future<void> cancelScheduledPrefetch() async {
    // NOTE: Background prefetching is temporarily disabled
    debugPrint(
        'IntelligentPrefetchService: Cancel prefetch is temporarily disabled');
    return;
    
    // try {
    //   await Workmanager().cancelByUniqueName('prefetch_feed_task');
    //   debugPrint('IntelligentPrefetchService: Cancelled scheduled prefetch');
    // } catch (e) {
    //   debugPrint(
    //       'IntelligentPrefetchService: Error cancelling prefetch: $e');
    // }
  }

  /// Gets statistics about app open patterns.
  ///
  /// Returns a map with the total opens and the most common hour.
  Map<String, dynamic> getStatistics() {
    int totalOpens = 0;
    int? mostCommonHour;
    int maxCount = 0;

    for (int i = 0; i < 24; i++) {
      final count = _prefs.getInt('$_prefKeyPrefix$i') ?? 0;
      totalOpens += count;
      if (count > maxCount) {
        maxCount = count;
        mostCommonHour = i;
      }
    }

    return {
      'totalOpens': totalOpens,
      'mostCommonHour': mostCommonHour,
      'mostCommonHourCount': maxCount,
    };
  }

  /// Clears all stored app open pattern data.
  Future<void> clearPatternData() async {
    for (int i = 0; i < 24; i++) {
      await _prefs.remove('$_prefKeyPrefix$i');
    }
    debugPrint('IntelligentPrefetchService: Cleared all pattern data');
  }
}

