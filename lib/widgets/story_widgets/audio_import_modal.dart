// lib/widgets/story_widgets/audio_import_modal.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Modal for importing audio from device
class AudioImportModal extends StatelessWidget {
  final Function(String audioPath) onAudioSelected;
  final VoidCallback? onRemoveAudio;

  const AudioImportModal({
    Key? key,
    required this.onAudioSelected,
    this.onRemoveAudio,
  }) : super(key: key);

  Future<void> _pickAudioFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac'],
        withData: false,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final audioPath = result.files.single.path!;
        Navigator.of(context).pop();
        onAudioSelected(audioPath);
      }
    } catch (e) {
      debugPrint('AudioImportModal: Error picking audio file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting audio: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusXL),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSM),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceMD,
                vertical: DesignTokens.spaceSM,
              ),
              child: Row(
                children: [
                  Text(
                    'Add Music',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            // Options
            ListTile(
              leading: Icon(
                Icons.music_note,
                color: SonarPulseTheme.primaryAccent,
              ),
              title: const Text('Import from Device'),
              subtitle: const Text('MP3, M4A, WAV, AAC'),
              onTap: () => _pickAudioFile(context),
            ),
            if (onRemoveAudio != null) ...[
              Divider(height: 1, color: theme.dividerColor),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
                title: const Text(
                  'Remove Audio',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onRemoveAudio?.call();
                },
              ),
            ],
            const SizedBox(height: DesignTokens.spaceSM),
          ],
        ),
      ),
    );
  }

  static Future<void> show({
    required BuildContext context,
    required Function(String audioPath) onAudioSelected,
    VoidCallback? onRemoveAudio,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AudioImportModal(
        onAudioSelected: onAudioSelected,
        onRemoveAudio: onRemoveAudio,
      ),
    );
  }
}

