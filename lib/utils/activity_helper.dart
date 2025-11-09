// lib/utils/activity_helper.dart
// Helper utilities for user activity status

import 'package:flutter/material.dart';

class ActivityHelper {
  /// Get human-readable activity status from lastSeen DateTime
  static String getActivityStatus(DateTime lastSeen, bool isOnline) {
    if (isOnline) return 'Active now';

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 5) return 'Active just now';
    if (difference.inMinutes < 60) return 'Active ${difference.inMinutes}m ago';
    if (difference.inHours < 2) return 'Active 1h ago';
    if (difference.inHours < 24) return 'Active ${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Active yesterday';
    if (difference.inDays < 7) return 'Active ${difference.inDays}d ago';
    if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks > 0
          ? 'Active ${weeks}w ago'
          : 'Active ${difference.inDays}d ago';
    }

    // Bug #28 fix: Use proper date math for months instead of simple division
    if (difference.inDays < 365) {
      final months =
          (now.year - lastSeen.year) * 12 + now.month - lastSeen.month;
      if (months > 0) {
        return 'Active ${months}mo ago';
      }
      return 'Active ${difference.inDays}d ago';
    }

    final years = (now.year - lastSeen.year);
    if (years == 1) return 'Active 1 year ago';
    if (years > 1) return 'Active $years years ago';

    return 'Inactive';
  }

  /// Get color for activity status
  static Color getActivityColor(
      DateTime lastSeen, bool isOnline, BuildContext context) {
    if (isOnline) return Colors.green;

    final difference = DateTime.now().difference(lastSeen);

    if (difference.inHours < 24) return Colors.orange;
    if (difference.inDays < 7) return Colors.grey;

    return Theme.of(context).colorScheme.onSurface.withOpacity(0.4);
  }

  /// Get activity indicator widget
  static Widget getActivityIndicator(DateTime lastSeen, bool isOnline) {
    if (!isOnline) return const SizedBox.shrink();

    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
      ),
    );
  }
}
