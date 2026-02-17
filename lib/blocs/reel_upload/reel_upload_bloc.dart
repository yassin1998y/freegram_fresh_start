// lib/blocs/reel_upload/reel_upload_bloc.dart

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/services/reel_upload_manager.dart';
import 'package:freegram/services/draft_persistence_service.dart';
import 'package:freegram/blocs/unified_feed_bloc.dart';

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
  final UnifiedFeedBloc _unifiedFeedBloc;
  StreamSubscription? _progressSubscription;
  String? _currentUploadId;

  ReelUploadBloc({
    required ReelUploadManager uploadManager,
    required DraftPersistenceService draftService,
    required UnifiedFeedBloc unifiedFeedBloc,
  })  : _uploadManager = uploadManager,
        _draftService = draftService,
        _unifiedFeedBloc = unifiedFeedBloc,
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

      // Use upload ID from event (supports optimistic UI matching)
      _currentUploadId = event.uploadId;

      // Start upload via manager
      final uploadStream = _uploadManager.startUpload(
        uploadId: _currentUploadId!,
        videoPath: event.videoPath,
        caption: event.caption,
        hashtags: event.hashtags ?? [],
        mentions: event.mentions ?? [],
      );

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
        onDone: () {},
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

  Future<void> _onUpdateProgress(
    UpdateUploadProgress event,
    Emitter<ReelUploadState> emit,
  ) async {
    if (state is ReelUploadInProgress) {
      final currentState = state as ReelUploadInProgress;
      final newState = currentState.copyWith(
        progress: event.progress,
        statusText: event.statusText,
      );
      emit(newState);

      // NEW: Update ghost post progress in UnifiedFeedBloc
      try {
        _unifiedFeedBloc.add(UpdateGhostPostProgressEvent(
          uploadId: event.uploadId,
          progress: event.progress,
          statusText: event.statusText,
        ));
      } catch (e) {
        debugPrint('[ReelUploadBloc] Error updating ghost post progress: $e');
      }

      // Check if upload is complete (progress = 1.0)
      if (event.progress >= 1.0) {
        // Wait a bit for the manager to finalize and provide the reel ID
        await Future.delayed(const Duration(milliseconds: 500));
        final completedReel = _uploadManager.getCompletedReel(event.uploadId);
        if (completedReel != null) {
          add(UploadCompleted(
            uploadId: event.uploadId,
            reelId: completedReel.reelId,
          ));
        }
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

    // NEW: Remove ghost post from feed
    _unifiedFeedBloc.add(RemoveGhostPostEvent(event.uploadId));

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
        uploadId: event.uploadId,
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
    if (_currentUploadId != null) {
      _uploadManager.cancelUpload(_currentUploadId!);
    }
    return super.close();
  }
}
