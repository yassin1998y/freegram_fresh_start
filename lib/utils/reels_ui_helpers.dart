// lib/utils/reels_ui_helpers.dart

import 'package:flutter/material.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/widgets/reels/reels_feedback_dialog.dart';

/// Helper methods for reels UI interactions
class ReelsUIHelpers {
  /// Show "Not Interested" feedback dialog
  static Future<void> showNotInterestedDialog({
    required BuildContext context,
    required ReelModel reel,
    required Function(String creatorId, String reason) onFeedbackSubmitted,
  }) async {
    await ReelsFeedbackDialog.show(
      context: context,
      reelId: reel.reelId,
      creatorId: reel.uploaderId,
      creatorUsername: reel.uploaderUsername,
      onFeedbackSelected: (reason) {
        onFeedbackSubmitted(reel.uploaderId, reason);

        // Show confirmation snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getFeedbackMessage(reason, reel.uploaderUsername)),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  /// Get confirmation message based on feedback reason
  static String _getFeedbackMessage(String reason, String username) {
    switch (reason) {
      case 'creator':
        return 'You\'ll see fewer reels from @$username';
      case 'topic':
        return 'We\'ll show you less of this type of content';
      case 'repetitive':
        return 'We\'ll add more variety to your feed';
      case 'report':
        return 'Content reported. Thank you for your feedback';
      default:
        return 'Thanks for your feedback';
    }
  }

  /// Show recommendation reason tooltip
  static void showRecommendationReason({
    required BuildContext context,
    required String reason,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }

  /// Format watch time for display
  static String formatWatchTime(double seconds) {
    if (seconds < 60) {
      return '${seconds.toInt()}s';
    }
    final minutes = (seconds / 60).floor();
    final remainingSeconds = (seconds % 60).toInt();
    return '${minutes}m ${remainingSeconds}s';
  }

  /// Format watch percentage for display
  static String formatWatchPercentage(double percentage) {
    return '${percentage.toStringAsFixed(0)}%';
  }

  /// Get completion badge text
  static String getCompletionBadge(double watchPercentage) {
    if (watchPercentage >= 95) {
      return 'Completed';
    } else if (watchPercentage >= 50) {
      return 'In Progress';
    } else {
      return 'Started';
    }
  }

  /// Get completion badge color
  static Color getCompletionBadgeColor(double watchPercentage) {
    if (watchPercentage >= 95) {
      return Colors.green;
    } else if (watchPercentage >= 50) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }
}
