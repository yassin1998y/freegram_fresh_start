// lib/widgets/story_widgets/creator/story_media_picker_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Media picker dialog for story creator
/// Shows options for camera, photo gallery, and video gallery
class StoryMediaPickerDialog {
  static Future<Map<String, dynamic>?> show(BuildContext context) async {
    final theme = Theme.of(context);

    return showModalBottomSheet<Map<String, dynamic>>(
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
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: theme.colorScheme.onSurface,
              ),
              title: Text(
                'Camera',
                style: theme.textTheme.bodyMedium,
              ),
              onTap: () => Navigator.of(context).pop({
                'source': ImageSource.camera,
                'type': 'image',
              }),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: theme.colorScheme.onSurface,
              ),
              title: Text(
                'Photo from Gallery',
                style: theme.textTheme.bodyMedium,
              ),
              onTap: () => Navigator.of(context).pop({
                'source': ImageSource.gallery,
                'type': 'image',
              }),
            ),
            if (!kIsWeb)
              ListTile(
                leading: Icon(
                  Icons.video_library,
                  color: theme.colorScheme.onSurface,
                ),
                title: Text(
                  'Video from Gallery',
                  style: theme.textTheme.bodyMedium,
                ),
                onTap: () => Navigator.of(context).pop({
                  'source': ImageSource.gallery,
                  'type': 'video',
                }),
              ),
            const SizedBox(height: DesignTokens.spaceMD),
          ],
        ),
      ),
    );
  }
}
