// lib/models/upload_progress_model.dart

import 'package:equatable/equatable.dart';

enum UploadState {
  preparing,
  processing,
  merging,
  uploading,
  finalizing,
  completed,
  failed,
}

class UploadProgress extends Equatable {
  final String uploadId;
  final UploadState state;
  final double progress; // 0.0 - 1.0
  final String currentStep;
  final int? bytesUploaded;
  final int? totalBytes;
  final double? uploadSpeed; // MB/s
  final Duration? estimatedTimeRemaining;
  final String? errorMessage;

  final String? placeholderData; // Base64 ultra-low-res preview (LQIP)

  const UploadProgress({
    required this.uploadId,
    required this.state,
    required this.progress,
    required this.currentStep,
    this.bytesUploaded,
    this.totalBytes,
    this.uploadSpeed,
    this.estimatedTimeRemaining,
    this.errorMessage,
    this.placeholderData,
  });

  UploadProgress copyWith({
    String? uploadId,
    UploadState? state,
    double? progress,
    String? currentStep,
    int? bytesUploaded,
    int? totalBytes,
    double? uploadSpeed,
    Duration? estimatedTimeRemaining,
    String? errorMessage,
    String? placeholderData,
  }) {
    return UploadProgress(
      uploadId: uploadId ?? this.uploadId,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      bytesUploaded: bytesUploaded ?? this.bytesUploaded,
      totalBytes: totalBytes ?? this.totalBytes,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      estimatedTimeRemaining:
          estimatedTimeRemaining ?? this.estimatedTimeRemaining,
      errorMessage: errorMessage ?? this.errorMessage,
      placeholderData: placeholderData ?? this.placeholderData,
    );
  }

  @override
  List<Object?> get props => [
        uploadId,
        state,
        progress,
        currentStep,
        bytesUploaded,
        totalBytes,
        uploadSpeed,
        estimatedTimeRemaining,
        errorMessage,
      ];
}
