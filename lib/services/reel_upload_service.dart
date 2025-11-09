// lib/services/reel_upload_service.dart

import 'package:flutter/foundation.dart';

/// Service to track reel upload progress globally
/// This allows showing upload progress in the app bar while user can scroll the feed
class ReelUploadService extends ChangeNotifier {
  static final ReelUploadService _instance = ReelUploadService._internal();
  factory ReelUploadService() => _instance;
  ReelUploadService._internal();

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadCaption;

  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String? get uploadCaption => _uploadCaption;

  /// Start tracking an upload
  void startUpload({String? caption}) {
    _isUploading = true;
    _uploadProgress = 0.0;
    _uploadCaption = caption;
    notifyListeners();
  }

  /// Update upload progress (0.0 to 1.0)
  void updateProgress(double progress) {
    if (_isUploading) {
      _uploadProgress = progress.clamp(0.0, 1.0);
      notifyListeners();
    }
  }

  /// Complete the upload
  void completeUpload() {
    _isUploading = false;
    _uploadProgress = 0.0;
    _uploadCaption = null;
    notifyListeners();
  }

  /// Cancel or fail the upload
  void cancelUpload() {
    _isUploading = false;
    _uploadProgress = 0.0;
    _uploadCaption = null;
    notifyListeners();
  }
}


