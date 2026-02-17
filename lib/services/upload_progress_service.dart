// lib/services/upload_progress_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/upload_progress_model.dart';
import 'package:uuid/uuid.dart';

/// Service to track story upload progress globally
/// Supports multiple concurrent uploads with detailed progress information
class UploadProgressService extends ChangeNotifier {
  static final UploadProgressService _instance =
      UploadProgressService._internal();
  factory UploadProgressService() => _instance;
  UploadProgressService._internal();

  final Map<String, UploadProgress> _uploads = {};
  final Map<String, StreamController<UploadProgress>> _uploadStreams = {};
  final _uuid = const Uuid();

  // CRITICAL FIX: Throttle notifications to prevent UI shaking
  Timer? _notificationThrottleTimer;
  bool _pendingNotification = false;
  static const Duration _throttleInterval =
      Duration(milliseconds: 150); // Max ~6.6 updates per second

  /// Get all active uploads
  Map<String, UploadProgress> get uploads => Map.unmodifiable(_uploads);

  /// Get active upload count
  int get activeUploadCount => _uploads.values
      .where((u) =>
          u.state != UploadState.completed && u.state != UploadState.failed)
      .length;

  /// Check if any upload is in progress
  bool get hasActiveUploads => activeUploadCount > 0;

  /// Start tracking an upload
  /// Returns the upload ID
  String startUpload({
    String? uploadId,
    String? currentStep,
  }) {
    final id = uploadId ?? _uuid.v4();

    _uploads[id] = UploadProgress(
      uploadId: id,
      state: UploadState.preparing,
      progress: 0.0,
      currentStep: currentStep ?? 'Preparing media...',
    );

    _uploadStreams[id] = StreamController<UploadProgress>.broadcast();
    // CRITICAL FIX: Use throttled notification for UI updates
    _throttledNotifyListeners();

    debugPrint('UploadProgressService: Started upload $id');
    return id;
  }

  /// CRITICAL FIX: Throttled notification to prevent UI shaking
  void _throttledNotifyListeners() {
    if (_notificationThrottleTimer != null &&
        _notificationThrottleTimer!.isActive) {
      _pendingNotification = true;
      return;
    }

    notifyListeners();
    _pendingNotification = false;

    _notificationThrottleTimer = Timer(_throttleInterval, () {
      if (_pendingNotification) {
        notifyListeners();
        _pendingNotification = false;
      }
      _notificationThrottleTimer = null;
    });
  }

  /// Update upload progress
  void updateProgress({
    required String uploadId,
    UploadState? state,
    double? progress,
    String? currentStep,
    int? bytesUploaded,
    int? totalBytes,
    double? uploadSpeed,
    Duration? estimatedTimeRemaining,
    String? placeholderData,
  }) {
    if (!_uploads.containsKey(uploadId)) {
      debugPrint('UploadProgressService: Upload $uploadId not found');
      return;
    }

    final current = _uploads[uploadId]!;
    _uploads[uploadId] = current.copyWith(
      state: state ?? current.state,
      progress: progress ?? current.progress,
      currentStep: currentStep ?? current.currentStep,
      bytesUploaded: bytesUploaded ?? current.bytesUploaded,
      totalBytes: totalBytes ?? current.totalBytes,
      uploadSpeed: uploadSpeed ?? current.uploadSpeed,
      estimatedTimeRemaining:
          estimatedTimeRemaining ?? current.estimatedTimeRemaining,
      placeholderData: placeholderData ?? current.placeholderData,
    );

    // Emit to stream immediately (streams need real-time updates)
    _uploadStreams[uploadId]?.add(_uploads[uploadId]!);

    // CRITICAL FIX: Use throttled notification for UI updates
    _throttledNotifyListeners();

    debugPrint(
        'UploadProgressService: Updated upload $uploadId - ${_uploads[uploadId]!.progress * 100}% - ${_uploads[uploadId]!.currentStep}');
  }

  /// Complete an upload
  void completeUpload(String uploadId) {
    if (!_uploads.containsKey(uploadId)) {
      return;
    }

    _uploads[uploadId] = _uploads[uploadId]!.copyWith(
      state: UploadState.completed,
      progress: 1.0,
      currentStep: 'Upload completed!',
    );

    _uploadStreams[uploadId]?.add(_uploads[uploadId]!);
    // CRITICAL FIX: Use throttled notification for UI updates
    _throttledNotifyListeners();

    // Clean up after a delay
    Future.delayed(const Duration(seconds: 5), () {
      _removeUpload(uploadId);
    });
  }

  /// Fail an upload
  void failUpload(String uploadId, String errorMessage) {
    if (!_uploads.containsKey(uploadId)) {
      return;
    }

    _uploads[uploadId] = _uploads[uploadId]!.copyWith(
      state: UploadState.failed,
      currentStep: 'Upload failed',
      errorMessage: errorMessage,
    );

    _uploadStreams[uploadId]?.add(_uploads[uploadId]!);
    // CRITICAL FIX: Use throttled notification for UI updates
    _throttledNotifyListeners();

    debugPrint('UploadProgressService: Upload $uploadId failed: $errorMessage');
  }

  /// Cancel an upload
  void cancelUpload(String uploadId) {
    _removeUpload(uploadId);
    debugPrint('UploadProgressService: Upload $uploadId cancelled');
  }

  /// Get upload progress stream
  Stream<UploadProgress> getUploadStream(String uploadId) {
    if (!_uploadStreams.containsKey(uploadId)) {
      return Stream.value(UploadProgress(
        uploadId: uploadId,
        state: UploadState.failed,
        progress: 0.0,
        currentStep: 'Upload not found',
      ));
    }
    return _uploadStreams[uploadId]!.stream;
  }

  /// Get current upload progress
  UploadProgress? getUploadProgress(String uploadId) {
    return _uploads[uploadId];
  }

  /// Remove an upload from tracking
  void _removeUpload(String uploadId) {
    _uploads.remove(uploadId);
    _uploadStreams[uploadId]?.close();
    _uploadStreams.remove(uploadId);
    // CRITICAL FIX: Use throttled notification for UI updates
    _throttledNotifyListeners();
  }

  /// Calculate upload speed and estimated time remaining
  void updateUploadMetrics({
    required String uploadId,
    required int bytesUploaded,
    required int totalBytes,
    required Duration elapsedTime,
  }) {
    if (totalBytes == 0) return;

    final progress = bytesUploaded / totalBytes;
    final secondsElapsed = elapsedTime.inSeconds;

    if (secondsElapsed > 0) {
      final bytesPerSecond = bytesUploaded / secondsElapsed;
      final uploadSpeed = bytesPerSecond / (1024 * 1024); // MB/s

      final remainingBytes = totalBytes - bytesUploaded;
      final estimatedSeconds =
          bytesPerSecond > 0 ? (remainingBytes / bytesPerSecond).round() : null;
      final estimatedTime =
          estimatedSeconds != null ? Duration(seconds: estimatedSeconds) : null;

      updateProgress(
        uploadId: uploadId,
        progress: progress,
        bytesUploaded: bytesUploaded,
        totalBytes: totalBytes,
        uploadSpeed: uploadSpeed,
        estimatedTimeRemaining: estimatedTime,
      );
    } else {
      updateProgress(
        uploadId: uploadId,
        progress: progress,
        bytesUploaded: bytesUploaded,
        totalBytes: totalBytes,
      );
    }
  }

  @override
  void dispose() {
    // CRITICAL FIX: Cancel throttle timer
    _notificationThrottleTimer?.cancel();
    _notificationThrottleTimer = null;

    for (final controller in _uploadStreams.values) {
      controller.close();
    }
    _uploadStreams.clear();
    _uploads.clear();
    super.dispose();
  }
}
