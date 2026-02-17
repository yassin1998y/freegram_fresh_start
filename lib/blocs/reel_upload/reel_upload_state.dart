// lib/blocs/reel_upload/reel_upload_state.dart

part of 'reel_upload_bloc.dart';

/// Base class for all reel upload states
@immutable
abstract class ReelUploadState extends Equatable {
  const ReelUploadState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no uploads in progress
class ReelUploadIdle extends ReelUploadState {
  const ReelUploadIdle();
}

/// Upload is in progress
class ReelUploadInProgress extends ReelUploadState {
  final String uploadId;
  final double progress; // 0.0 to 1.0
  final String? statusText; // e.g., "Compressing...", "Uploading..."
  final String? caption;

  const ReelUploadInProgress({
    required this.uploadId,
    required this.progress,
    this.statusText,
    this.caption,
  });

  @override
  List<Object?> get props => [uploadId, progress, statusText, caption];

  ReelUploadInProgress copyWith({
    String? uploadId,
    double? progress,
    String? statusText,
    String? caption,
  }) {
    return ReelUploadInProgress(
      uploadId: uploadId ?? this.uploadId,
      progress: progress ?? this.progress,
      statusText: statusText ?? this.statusText,
      caption: caption ?? this.caption,
    );
  }
}

/// Upload completed successfully
class ReelUploadSuccess extends ReelUploadState {
  final String uploadId;
  final String reelId;

  const ReelUploadSuccess({
    required this.uploadId,
    required this.reelId,
  });

  @override
  List<Object?> get props => [uploadId, reelId];
}

/// Upload failed (with retry option)
class ReelUploadFailed extends ReelUploadState {
  final String uploadId;
  final String error;
  final bool canRetry;

  const ReelUploadFailed({
    required this.uploadId,
    required this.error,
    this.canRetry = true,
  });

  @override
  List<Object?> get props => [uploadId, error, canRetry];
}

/// Upload saved as draft (will auto-retry on network restore)
class ReelUploadDraft extends ReelUploadState {
  final String uploadId;
  final String error;
  final DateTime createdAt;

  const ReelUploadDraft({
    required this.uploadId,
    required this.error,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [uploadId, error, createdAt];
}

/// Multiple uploads state (for future batch upload support)
class ReelUploadMultiple extends ReelUploadState {
  final List<ReelUploadInProgress> activeUploads;
  final List<ReelUploadDraft> drafts;

  const ReelUploadMultiple({
    required this.activeUploads,
    required this.drafts,
  });

  @override
  List<Object?> get props => [activeUploads, drafts];
}
