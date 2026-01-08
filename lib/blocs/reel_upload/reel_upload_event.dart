// lib/blocs/reel_upload/reel_upload_event.dart

part of 'reel_upload_bloc.dart';

/// Base class for all reel upload events
@immutable
abstract class ReelUploadEvent extends Equatable {
  const ReelUploadEvent();

  @override
  List<Object?> get props => [];
}

/// Start uploading a reel
class StartReelUpload extends ReelUploadEvent {
  final String videoPath;
  final String? caption;
  final List<String>? hashtags;
  final List<String>? mentions;

  const StartReelUpload({
    required this.videoPath,
    this.caption,
    this.hashtags,
    this.mentions,
  });

  @override
  List<Object?> get props => [videoPath, caption, hashtags, mentions];
}

/// Update upload progress
class UpdateUploadProgress extends ReelUploadEvent {
  final String uploadId;
  final double progress; // 0.0 to 1.0
  final String? statusText; // e.g., "Compressing...", "Uploading..."

  const UpdateUploadProgress({
    required this.uploadId,
    required this.progress,
    this.statusText,
  });

  @override
  List<Object?> get props => [uploadId, progress, statusText];
}

/// Upload completed successfully
class UploadCompleted extends ReelUploadEvent {
  final String uploadId;
  final String reelId; // The created reel ID

  const UploadCompleted({
    required this.uploadId,
    required this.reelId,
  });

  @override
  List<Object?> get props => [uploadId, reelId];
}

/// Upload failed
class UploadFailed extends ReelUploadEvent {
  final String uploadId;
  final String error;
  final bool shouldSaveAsDraft;

  const UploadFailed({
    required this.uploadId,
    required this.error,
    this.shouldSaveAsDraft = true,
  });

  @override
  List<Object?> get props => [uploadId, error, shouldSaveAsDraft];
}

/// Retry a failed upload
class RetryUpload extends ReelUploadEvent {
  final String uploadId;

  const RetryUpload({required this.uploadId});

  @override
  List<Object?> get props => [uploadId];
}

/// Cancel an ongoing upload
class CancelUpload extends ReelUploadEvent {
  final String uploadId;

  const CancelUpload({required this.uploadId});

  @override
  List<Object?> get props => [uploadId];
}

/// Load drafts (failed uploads saved for retry)
class LoadDrafts extends ReelUploadEvent {
  const LoadDrafts();
}

/// Clear all drafts
class ClearDrafts extends ReelUploadEvent {
  const ClearDrafts();
}
