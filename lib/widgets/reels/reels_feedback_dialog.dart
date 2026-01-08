// lib/widgets/reels/reels_feedback_dialog.dart

import 'package:flutter/material.dart';

/// Dialog for user feedback on reels content
/// Allows users to specify why they're not interested in content
class ReelsFeedbackDialog extends StatelessWidget {
  final String reelId;
  final String creatorId;
  final String creatorUsername;
  final Function(String reason) onFeedbackSelected;

  const ReelsFeedbackDialog({
    Key? key,
    required this.reelId,
    required this.creatorId,
    required this.creatorUsername,
    required this.onFeedbackSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Not interested?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tell us why so we can improve your recommendations',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),

            // Options
            _buildOption(
              context,
              icon: Icons.person_off,
              title: 'Not interested in @$creatorUsername',
              subtitle: 'See fewer reels from this creator',
              onTap: () {
                Navigator.pop(context);
                onFeedbackSelected('creator');
              },
            ),
            const Divider(height: 1),
            _buildOption(
              context,
              icon: Icons.topic_outlined,
              title: 'Not interested in this topic',
              subtitle: 'See fewer reels like this',
              onTap: () {
                Navigator.pop(context);
                onFeedbackSelected('topic');
              },
            ),
            const Divider(height: 1),
            _buildOption(
              context,
              icon: Icons.repeat,
              title: 'Seen too many like this',
              subtitle: 'Show more variety',
              onTap: () {
                Navigator.pop(context);
                onFeedbackSelected('repetitive');
              },
            ),
            const Divider(height: 1),
            _buildOption(
              context,
              icon: Icons.flag_outlined,
              title: 'Report content',
              subtitle: 'Inappropriate or harmful',
              onTap: () {
                Navigator.pop(context);
                onFeedbackSelected('report');
              },
              isDestructive: true,
            ),

            const SizedBox(height: 12),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.grey[700],
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDestructive ? Colors.red : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Show the feedback dialog
  static Future<void> show({
    required BuildContext context,
    required String reelId,
    required String creatorId,
    required String creatorUsername,
    required Function(String reason) onFeedbackSelected,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ReelsFeedbackDialog(
        reelId: reelId,
        creatorId: creatorId,
        creatorUsername: creatorUsername,
        onFeedbackSelected: onFeedbackSelected,
      ),
    );
  }
}
