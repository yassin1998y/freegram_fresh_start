// lib/blocs/reel_upload/reel_upload_bloc.dart

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/services/reel_upload_manager.dart';
import 'package:freegram/services/draft_persistence_service.dart';

part 'reel_upload_event.dart';
part 'reel_upload_state.dart';

/// BLoC for managing reel upload state
///
/// Handles:
/// - Upload progress tracking
/// - Retry logic
/// - Draft persistence
/// - State management for optimistic UI
class ReelUploadBloc extends Bloc<ReelUploadEvent, ReelUploadState> {
  final ReelUploadManager _uploadManager;
  final DraftPersistenceService _draftService;

  StreamSubscription<UploadProgress>? _progressSubscription;
  String? _currentUploadId;

  ReelUploadBloc({
    required ReelUploadManager uploadManager,
    required DraftPersistenceService draftService,
  })  : _uploadManager = uploadManager,
        _draftService = draftService,
        super(const ReelUploadIdle()) {
    on<StartReelUpload>(_onStartUpload);
    on<UpdateUploadProgress>(_onUpdateProgress);
    on<UploadCompleted>(_onUploadCompleted);
    on<UploadFailed>(_onUploadFailed);
    on<RetryUpload>(_onRetryUpload);
    on<CancelUpload>(_onCancelUpload);
    on<LoadDrafts>(_onLoadDrafts);
    on<ClearDrafts>(_onClearDrafts);

    // Load drafts on initialization
    add(const LoadDrafts());
  }

  Future<void> _onStartUpload(
    StartReelUpload event,
    Emitter<ReelUploadState> emit,
  ) async {
    try {
      debugPrint('[ReelUploadBloc] Starting upload: ${event.videoPath}');

      // Generate unique upload ID
      _currentUploadId = DateTime.now().millisecondsSinceEpoch.toString();

      // Start upload via manager
      final uploadStream = _uploadManager.startUpload(
        uploadId: _currentUploadId!,
        videoPath: event.videoPath,
        caption: event.caption,
        hashtags: event.hashtags ?? [],
        mentions: event.mentions ?? [],
      );

      // Store the upload future for completion check
      // Note: We'll check completion via the stream's onDone callback

      // Listen to progress updates
      _progressSubscription?.cancel();
      final subscription = uploadStream.listen(
        (progress) {
          add(UpdateUploadProgress(
            uploadId: _currentUploadId!,
            progress: progress.progress,
            statusText: progress.statusText,
          ));
        },
        onError: (error) {
          add(UploadFailed(
            uploadId: _currentUploadId!,
            error: error.toString(),
            shouldSaveAsDraft: true,
          ));
        },
        onDone: () {
          // Stream completed - upload manager handles completion
          // The UploadCompleted event will be emitted by the manager
          // For now, we rely on the stream completion
        },
        cancelOnError: false,
      );
      _progressSubscription = subscription;

      // Emit initial progress state
      emit(ReelUploadInProgress(
        uploadId: _currentUploadId!,
        progress: 0.0,
        statusText: 'Preparing...',
        caption: event.caption,
      ));
    } catch (e) {
      debugPrint('[ReelUploadBloc] Error starting upload: $e');
      emit(ReelUploadFailed(
        uploadId: _currentUploadId ?? 'unknown',
        error: e.toString(),
        canRetry: true,
      ));
    }
  }

  void _onUpdateProgress(
    UpdateUploadProgress event,
    Emitter<ReelUploadState> emit,
  ) {
    if (state is ReelUploadInProgress) {
      final currentState = state as ReelUploadInProgress;

      // Check if upload is complete (progress = 1.0)
      if (event.progress >= 1.0) {
        // Upload completed - get the reel ID from the manager
        final completedReel = _uploadManager.getCompletedReel(event.uploadId);
        if (completedReel != null) {
          emit(ReelUploadSuccess(
            uploadId: event.uploadId,
            reelId: completedReel.reelId,
          ));

          // Auto-transition to idle after delay
          Future.delayed(const Duration(seconds: 2), () {
            if (state is ReelUploadSuccess) {
              emit(const ReelUploadIdle());
            }
          });
        } else {
          // Reel not found yet, wait a bit
          Future.delayed(const Duration(milliseconds: 500), () {
            final reel = _uploadManager.getCompletedReel(event.uploadId);
            if (reel != null) {
              add(UploadCompleted(
                uploadId: event.uploadId,
                reelId: reel.reelId,
              ));
            }
          });
        }
      } else {
        emit(ReelUploadInProgress(
          uploadId: event.uploadId,
          progress: event.progress,
          statusText: event.statusText ?? currentState.statusText,
          caption: currentState.caption,
        ));
      }
    }
  }

  Future<void> _onUploadCompleted(
    UploadCompleted event,
    Emitter<ReelUploadState> emit,
  ) async {
    debugPrint('[ReelUploadBloc] Upload completed: ${event.reelId}');

    _progressSubscription?.cancel();
    _currentUploadId = null;

    emit(ReelUploadSuccess(
      uploadId: event.uploadId,
      reelId: event.reelId,
    ));

    // Auto-transition to idle after 2 seconds (for success animation)
    await Future.delayed(const Duration(seconds: 2));
    if (state is ReelUploadSuccess) {
      emit(const ReelUploadIdle());
    }
  }

  Future<void> _onUploadFailed(
    UploadFailed event,
    Emitter<ReelUploadState> emit,
  ) async {
    debugPrint('[ReelUploadBloc] Upload failed: ${event.error}');

    _progressSubscription?.cancel();

    // Save as draft if requested
    if (event.shouldSaveAsDraft) {
      await _draftService.saveDraft(
        uploadId: event.uploadId,
        videoPath: '', // Will be retrieved from upload manager
        error: event.error,
      );
    }

    emit(ReelUploadFailed(
      uploadId: event.uploadId,
      error: event.error,
      canRetry: true,
    ));
  }

  Future<void> _onRetryUpload(
    RetryUpload event,
    Emitter<ReelUploadState> emit,
  ) async {
    try {
      debugPrint('[ReelUploadBloc] Retrying upload: ${event.uploadId}');

      // Load draft data
      final draft = await _draftService.getDraft(event.uploadId);
      if (draft == null) {
        emit(ReelUploadFailed(
          uploadId: event.uploadId,
          error: 'Draft not found',
          canRetry: false,
        ));
        return;
      }

      // Retry upload
      add(StartReelUpload(
        videoPath: draft.videoPath,
        caption: draft.caption,
        hashtags: draft.hashtags,
        mentions: draft.mentions,
      ));
    } catch (e) {
      debugPrint('[ReelUploadBloc] Error retrying upload: $e');
      emit(ReelUploadFailed(
        uploadId: event.uploadId,
        error: e.toString(),
        canRetry: true,
      ));
    }
  }

  Future<void> _onCancelUpload(
    CancelUpload event,
    Emitter<ReelUploadState> emit,
  ) async {
    debugPrint('[ReelUploadBloc] Cancelling upload: ${event.uploadId}');

    await _uploadManager.cancelUpload(event.uploadId);
    _progressSubscription?.cancel();
    _currentUploadId = null;

    emit(const ReelUploadIdle());
  }

  Future<void> _onLoadDrafts(
    LoadDrafts event,
    Emitter<ReelUploadState> emit,
  ) async {
    try {
      final drafts = await _draftService.getAllDrafts();
      if (drafts.isNotEmpty) {
        debugPrint('[ReelUploadBloc] Loaded ${drafts.length} drafts');
        // For now, just log. Future: Show drafts in UI
      }
    } catch (e) {
      debugPrint('[ReelUploadBloc] Error loading drafts: $e');
    }
  }

  Future<void> _onClearDrafts(
    ClearDrafts event,
    Emitter<ReelUploadState> emit,
  ) async {
    await _draftService.clearAllDrafts();
  }

  @override
  Future<void> close() {
    _progressSubscription?.cancel();
    return super.close();
  }
}
