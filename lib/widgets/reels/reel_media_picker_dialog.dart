// lib/widgets/reels/reel_media_picker_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Media picker dialog for creating reels
/// Allows user to choose between camera recording or gallery selection
class ReelMediaPickerDialog extends StatelessWidget {
  const ReelMediaPickerDialog({Key? key}) : super(key: key);

  static Future<Map<String, dynamic>?> show(BuildContext context) {
    final theme = Theme.of(context);
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusXL),
        ),
      ),
      builder: (context) => const SafeArea(
        child: ReelMediaPickerDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Container(
          width: DesignTokens.spaceXXL,
          height: DesignTokens.elevation1,
          margin: const EdgeInsets.symmetric(vertical: DesignTokens.spaceMD),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 
              DesignTokens.opacityMedium,
            ),
            borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
          ),
        ),
        // Options
        ListTile(
          leading: Icon(
            Icons.videocam,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            'Record Video',
            style: theme.textTheme.bodyMedium,
          ),
          onTap: () => Navigator.of(context).pop({
            'source': ImageSource.camera,
            'type': 'video',
          }),
        ),
        if (!kIsWeb)
          ListTile(
            leading: Icon(
              Icons.video_library,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              'Choose from Gallery',
              style: theme.textTheme.bodyMedium,
            ),
            onTap: () => Navigator.of(context).pop({
              'source': ImageSource.gallery,
              'type': 'video',
            }),
          ),
        const SizedBox(height: DesignTokens.spaceMD),
      ],
    );
  }
}
