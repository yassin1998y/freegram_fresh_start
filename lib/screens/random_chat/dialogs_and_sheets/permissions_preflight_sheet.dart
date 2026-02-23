import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

class PermissionsPreflightSheet extends StatelessWidget {
  const PermissionsPreflightSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PermissionsPreflightSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusXL),
        ),
        boxShadow: DesignTokens.shadowFloating,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceLG,
        vertical: DesignTokens.spaceXL,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: DesignTokens.bottomSheetHandleWidth,
            height: DesignTokens.bottomSheetHandleHeight,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXL),

          // Illustration / Icon
          Container(
            padding: const EdgeInsets.all(DesignTokens.spaceXL),
            decoration: BoxDecoration(
              color: SonarPulseTheme.primaryAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.videocam_outlined,
              size: DesignTokens.iconXXL,
              color: SonarPulseTheme.primaryAccent,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLG),

          Text(
            'Ready to meet new people?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.spaceMD),

          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: DesignTokens.spaceSM),
            child: Text(
              'To connect you with others safely, we need access to your camera and microphone. This allows for real-time interaction and helps keep our community safe.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
                height: DesignTokens.lineHeightNormal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXL),

          // Action Buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final cameraStatus = await Permission.camera.request();
                final micStatus = await Permission.microphone.request();

                if (context.mounted) {
                  Navigator.pop(
                      context, cameraStatus.isGranted && micStatus.isGranted);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SonarPulseTheme.primaryAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    vertical: DesignTokens.buttonPaddingVertical),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Grant Access',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: DesignTokens.fontSizeLG,
                ),
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMD),

          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pop(); // Go back to previous screen
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.textTheme.bodySmall?.color,
            ),
            child: const Text('Maybe Later'),
          ),
          const SizedBox(height: DesignTokens.spaceLG),
        ],
      ),
    );
  }
}
