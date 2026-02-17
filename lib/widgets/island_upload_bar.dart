// lib/widgets/island_upload_bar.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:freegram/services/upload_progress_service.dart';
import 'package:freegram/models/upload_progress_model.dart';
import 'package:provider/provider.dart';

/// A premium, dynamic island-style upload progress bar.
/// It appears at the top of the screen when an upload is active.
class IslandUploadBar extends StatelessWidget {
  const IslandUploadBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadProgressService>(
      builder: (context, service, child) {
        if (!service.hasActiveUploads) return const SizedBox.shrink();

        // Get the most recent active upload
        final uploads = service.uploads.values
            .where((u) =>
                u.state != UploadState.completed &&
                u.state != UploadState.failed)
            .toList();

        if (uploads.isEmpty) return const SizedBox.shrink();

        final upload = uploads.last;

        return Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 20,
          right: 20,
          child: _UploadIslandItem(upload: upload),
        );
      },
    );
  }
}

class _UploadIslandItem extends StatelessWidget {
  final UploadProgress upload;

  const _UploadIslandItem({required this.upload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryAccent = colorScheme.primary;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        border:
            Border.all(color: primaryAccent.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // LQIP Thumbnail
          _buildThumbnail(upload.placeholderData, primaryAccent),
          const SizedBox(width: 12),

          // Progress Info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      upload.currentStep,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${(upload.progress * 100).toInt()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: upload.progress,
                    backgroundColor: primaryAccent.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(primaryAccent),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String? base64Data, Color accentColor) {
    if (base64Data == null || base64Data.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.cloud_upload, color: accentColor, size: 20),
      );
    }

    try {
      final bytes = base64Decode(base64Data);
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: MemoryImage(bytes),
            fit: BoxFit.cover,
          ),
          border:
              Border.all(color: accentColor.withValues(alpha: 0.2), width: 1),
        ),
      );
    } catch (e) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.error_outline, color: accentColor, size: 20),
      );
    }
  }
}
