// lib/widgets/story_widgets/viewer/story_options_dialog.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Story options dialog widget
/// Shows delete/report options for story owners/viewers
class StoryOptionsDialog {
  static void show(
    BuildContext context, {
    required bool isOwner,
    required VoidCallback onDelete,
    required VoidCallback onReport,
    required VoidCallback onClose,
  }) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusXL),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: DesignTokens.spaceXXXL - DesignTokens.spaceMD,
              height: DesignTokens.elevation1,
              margin:
                  const EdgeInsets.symmetric(vertical: DesignTokens.spaceMD),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 
                  DesignTokens.opacityMedium,
                ),
                borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
              ),
            ),
            if (isOwner)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Delete Story',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
              )
            else
              ListTile(
                leading: Icon(
                  Icons.report_outlined,
                  color: theme.colorScheme.onSurface,
                ),
                title: Text(
                  'Report Story',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onReport();
                },
              ),
            ListTile(
              leading: Icon(
                Icons.close,
                color: theme.colorScheme.onSurface,
              ),
              title: Text(
                'Close',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                onClose();
              },
            ),
            const SizedBox(height: DesignTokens.spaceMD),
          ],
        ),
      ),
    );
  }

  static Future<bool> showDeleteConfirmation(BuildContext context) async {
    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Delete Story?',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          'This story will be deleted permanently. This action cannot be undone.',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 
              DesignTokens.opacityHigh,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 
                  DesignTokens.opacityHigh,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
