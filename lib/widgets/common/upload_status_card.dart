// lib/widgets/common/upload_status_card.dart

import 'package:flutter/material.dart';
import 'package:freegram/models/upload_progress_model.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Expandable card showing detailed upload information
class UploadStatusCard extends StatelessWidget {
  final UploadProgress progress;
  final VoidCallback? onCancel;

  const UploadStatusCard({
    Key? key,
    required this.progress,
    this.onCancel,
  }) : super(key: key);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '';
    final seconds = duration.inSeconds;
    if (seconds < 60) return '$seconds seconds';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  IconData _getStepIcon(UploadState state) {
    switch (state) {
      case UploadState.preparing:
        return Icons.settings;
      case UploadState.processing:
        return Icons.build;
      case UploadState.merging:
        return Icons.merge_type;
      case UploadState.uploading:
        return Icons.cloud_upload;
      case UploadState.finalizing:
        return Icons.check_circle_outline;
      case UploadState.completed:
        return Icons.check_circle;
      case UploadState.failed:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFailed = progress.state == UploadState.failed;
    final isCompleted = progress.state == UploadState.completed;

    return Card(
      margin: const EdgeInsets.all(DesignTokens.spaceMD),
      color: theme.colorScheme.surface,
      elevation: DesignTokens.elevation2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _getStepIcon(progress.state),
                  color: isFailed
                      ? theme.colorScheme.error
                      : isCompleted
                          ? Colors.green
                          : SonarPulseTheme.primaryAccent,
                  size: DesignTokens.iconLG,
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                Expanded(
                  child: Text(
                    isFailed
                        ? 'Upload Failed'
                        : isCompleted
                            ? 'Upload Complete'
                            : 'Uploading Story',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!isCompleted && !isFailed && onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onCancel,
                    iconSize: DesignTokens.iconMD,
                  ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            // Progress bar
            if (!isCompleted && !isFailed) ...[
              LinearProgressIndicator(
                value: progress.progress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(
                  SonarPulseTheme.primaryAccent,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceSM),
            ],
            // Current step
            Text(
              progress.currentStep,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            // Details
            if (progress.bytesUploaded != null && progress.totalBytes != null) ...[
              const SizedBox(height: DesignTokens.spaceSM),
              Row(
                children: [
                  Icon(
                    Icons.data_usage,
                    size: DesignTokens.iconSM,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: DesignTokens.spaceXS),
                  Text(
                    '${_formatBytes(progress.bytesUploaded!)} / ${_formatBytes(progress.totalBytes!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
            // Upload speed
            if (progress.uploadSpeed != null) ...[
              const SizedBox(height: DesignTokens.spaceXS),
              Row(
                children: [
                  Icon(
                    Icons.speed,
                    size: DesignTokens.iconSM,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: DesignTokens.spaceXS),
                  Text(
                    '${progress.uploadSpeed!.toStringAsFixed(1)} MB/s',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
            // Estimated time remaining
            if (progress.estimatedTimeRemaining != null) ...[
              const SizedBox(height: DesignTokens.spaceXS),
              Row(
                children: [
                  Icon(
                    Icons.timer,
                    size: DesignTokens.iconSM,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: DesignTokens.spaceXS),
                  Text(
                    '~${_formatDuration(progress.estimatedTimeRemaining)} remaining',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
            // Error message
            if (isFailed && progress.errorMessage != null) ...[
              const SizedBox(height: DesignTokens.spaceSM),
              Container(
                padding: const EdgeInsets.all(DesignTokens.spaceSM),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: DesignTokens.iconSM,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: DesignTokens.spaceXS),
                    Expanded(
                      child: Text(
                        progress.errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

