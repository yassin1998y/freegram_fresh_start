// lib/blocs/story_viewer_cubit.dart

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/story_media_model.dart';
import 'package:freegram/repositories/story_repository.dart';
import 'package:freegram/repositories/user_repository.dart';

// States
abstract class StoryViewerState extends Equatable {
  const StoryViewerState();

  @override
  List<Object?> get props => [];
}

class StoryViewerInitial extends StoryViewerState {}

class StoryViewerLoading extends StoryViewerState {}

class StoryViewerLoaded extends StoryViewerState {
  final List<StoryUser> usersWithStories;
  final int currentUserIndex;
  final int currentStoryIndex;
  final Map<String, List<StoryMedia>> userStoriesMap;
  final Map<String, double> progressMap; // Story ID -> progress (0-1)
  final bool isPaused;

  const StoryViewerLoaded({
    required this.usersWithStories,
    required this.currentUserIndex,
    required this.currentStoryIndex,
    required this.userStoriesMap,
    required this.progressMap,
    this.isPaused = false,
  });

  StoryViewerLoaded copyWith({
    List<StoryUser>? usersWithStories,
    int? currentUserIndex,
    int? currentStoryIndex,
    Map<String, List<StoryMedia>>? userStoriesMap,
    Map<String, double>? progressMap,
    bool? isPaused,
  }) {
    return StoryViewerLoaded(
      usersWithStories: usersWithStories ?? this.usersWithStories,
      currentUserIndex: currentUserIndex ?? this.currentUserIndex,
      currentStoryIndex: currentStoryIndex ?? this.currentStoryIndex,
      userStoriesMap: userStoriesMap ?? this.userStoriesMap,
      progressMap: progressMap ?? this.progressMap,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  StoryMedia? get currentStory {
    if (usersWithStories.isEmpty) return null;
    final userId = usersWithStories[currentUserIndex].userId;
    final stories = userStoriesMap[userId] ?? [];
    if (currentStoryIndex >= stories.length) return null;
    return stories[currentStoryIndex];
  }

  StoryUser? get currentUser {
    if (currentUserIndex >= usersWithStories.length) return null;
    return usersWithStories[currentUserIndex];
  }

  @override
  List<Object?> get props => [
        usersWithStories,
        currentUserIndex,
        currentStoryIndex,
        userStoriesMap,
        progressMap,
        isPaused,
      ];
}

class StoryViewerError extends StoryViewerState {
  final String error;

  const StoryViewerError(this.error);

  @override
  List<Object?> get props => [error];
}

// Helper class for user info with stories
class StoryUser extends Equatable {
  final String userId;
  final String username;
  final String userAvatarUrl;

  const StoryUser({
    required this.userId,
    required this.username,
    required this.userAvatarUrl,
  });

  @override
  List<Object?> get props => [userId, username, userAvatarUrl];
}

class StoryViewerCubit extends Cubit<StoryViewerState> {
  final StoryRepository _storyRepository;
  final UserRepository _userRepository;
  Timer? _autoAdvanceTimer;
  Timer? _progressTimer;
  final String _viewerId;
  DateTime? _storyStartTime;
  Duration? _storyDuration;

  StoryViewerCubit({
    required StoryRepository storyRepository,
    required UserRepository userRepository,
    required String viewerId,
  })  : _storyRepository = storyRepository,
        _userRepository = userRepository,
        _viewerId = viewerId,
        super(StoryViewerInitial());

  /// Load stories for users in the tray
  Future<void> loadStoriesForUsers(
    List<String> userIds,
    String startingUserId,
  ) async {
    emit(StoryViewerLoading());
    debugPrint(
        'StoryViewerCubit: Loading stories for ${userIds.length} users, starting with $startingUserId');

    try {
      final Map<String, List<StoryMedia>> userStoriesMap = {};
      final List<StoryUser> usersWithStories = [];

      // Load stories for each user
      for (final userId in userIds) {
        debugPrint('StoryViewerCubit: Loading stories for user $userId');
        final stories = await _storyRepository.getUserStories(userId);
        debugPrint(
            'StoryViewerCubit: Got ${stories.length} stories for user $userId');
        if (stories.isNotEmpty) {
          userStoriesMap[userId] = stories;

          // Get user info
          try {
            final user = await _userRepository.getUser(userId);
            usersWithStories.add(StoryUser(
              userId: userId,
              username: user.username,
              userAvatarUrl: user.photoUrl,
            ));
          } catch (e) {
            debugPrint('StoryViewerCubit: Error loading user $userId: $e');
            // Skip user if can't load their info
          }
        }
      }

      debugPrint(
          'StoryViewerCubit: Total users with stories: ${usersWithStories.length}');
      if (usersWithStories.isEmpty) {
        debugPrint('StoryViewerCubit: No stories found for any user');
        emit(const StoryViewerError('No stories available'));
        return;
      }

      // Find starting user index
      int startingIndex = 0;
      for (int i = 0; i < usersWithStories.length; i++) {
        if (usersWithStories[i].userId == startingUserId) {
          startingIndex = i;
          break;
        }
      }

      // Mark first story as viewed
      final startingUserIdKey = usersWithStories[startingIndex].userId;
      final startingStories = userStoriesMap[startingUserIdKey] ?? [];
      if (startingStories.isNotEmpty) {
        await _markStoryAsViewed(startingStories[0].storyId);
      }

      emit(StoryViewerLoaded(
        usersWithStories: usersWithStories,
        currentUserIndex: startingIndex,
        currentStoryIndex: 0,
        userStoriesMap: userStoriesMap,
        progressMap: {},
      ));

      // Start auto-advance after a brief delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 100), () {
        _startAutoAdvance();
      });
    } catch (e) {
      debugPrint('StoryViewerCubit: Error loading stories: $e');
      emit(StoryViewerError(e.toString()));
    }
  }

  /// Navigate to next story
  void nextStory() {
    final state = this.state;
    if (state is! StoryViewerLoaded) return;

    _stopAutoAdvance();

    final userId = state.usersWithStories[state.currentUserIndex].userId;
    final stories = state.userStoriesMap[userId] ?? [];

    if (state.currentStoryIndex < stories.length - 1) {
      // Next story in current user's reel
      final nextIndex = state.currentStoryIndex + 1;
      _markStoryAsViewed(stories[nextIndex].storyId);
      emit(state.copyWith(currentStoryIndex: nextIndex, progressMap: {}));
      Future.delayed(const Duration(milliseconds: 100), () {
        _startAutoAdvance();
      });
    } else {
      // Move to next user
      nextUser();
    }
  }

  /// Navigate to previous story
  void previousStory() {
    final state = this.state;
    if (state is! StoryViewerLoaded) return;

    _stopAutoAdvance();

    if (state.currentStoryIndex > 0) {
      // Previous story in current user's reel
      emit(state.copyWith(
          currentStoryIndex: state.currentStoryIndex - 1, progressMap: {}));
      Future.delayed(const Duration(milliseconds: 100), () {
        _startAutoAdvance();
      });
    } else {
      // Move to previous user
      previousUser();
    }
  }

  /// Navigate to next user
  void nextUser() {
    final state = this.state;
    if (state is! StoryViewerLoaded) return;

    _stopAutoAdvance();

    if (state.currentUserIndex < state.usersWithStories.length - 1) {
      final nextUserIndex = state.currentUserIndex + 1;
      final nextUserId = state.usersWithStories[nextUserIndex].userId;
      final nextStories = state.userStoriesMap[nextUserId] ?? [];

      if (nextStories.isNotEmpty) {
        _markStoryAsViewed(nextStories[0].storyId);
        emit(state.copyWith(
          currentUserIndex: nextUserIndex,
          currentStoryIndex: 0,
          progressMap: {},
        ));
        Future.delayed(const Duration(milliseconds: 100), () {
          _startAutoAdvance();
        });
      }
    } else {
      // Reached end, close viewer
      // This will be handled by the UI
    }
  }

  /// Navigate to previous user
  void previousUser() {
    final state = this.state;
    if (state is! StoryViewerLoaded) return;

    _stopAutoAdvance();

    if (state.currentUserIndex > 0) {
      final prevUserIndex = state.currentUserIndex - 1;
      final prevUserId = state.usersWithStories[prevUserIndex].userId;
      final prevStories = state.userStoriesMap[prevUserId] ?? [];

      if (prevStories.isNotEmpty) {
        final lastStoryIndex = prevStories.length - 1;
        emit(state.copyWith(
          currentUserIndex: prevUserIndex,
          currentStoryIndex: lastStoryIndex,
          progressMap: {},
        ));
        Future.delayed(const Duration(milliseconds: 100), () {
          _startAutoAdvance();
        });
      } else {
        // If previous user has no stories, skip to next previous user
        if (prevUserIndex > 0) {
          previousUser(); // Recursive call
        }
      }
    }
  }

  /// Pause story (for videos)
  void pauseStory() {
    final state = this.state;
    if (state is! StoryViewerLoaded) return;

    // Pause progress timer but keep current progress
    _progressTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;

    emit(state.copyWith(isPaused: true));
    debugPrint('StoryViewerCubit: Story paused');
  }

  /// Resume story
  void resumeStory() {
    final state = this.state;
    if (state is! StoryViewerLoaded || !state.isPaused) return;

    emit(state.copyWith(isPaused: false));

    // Resume from current progress
    final story = state.currentStory;
    if (story != null && _storyStartTime != null && _storyDuration != null) {
      // Calculate remaining time
      final elapsed = DateTime.now().difference(_storyStartTime!);
      final remaining = _storyDuration! - elapsed;

      if (remaining.isNegative) {
        // Already finished, move to next
        nextStory();
      } else {
        // Resume progress timer
        _progressTimer?.cancel();
        _progressTimer =
            Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (this.state is! StoryViewerLoaded ||
              (this.state as StoryViewerLoaded).isPaused ||
              _storyStartTime == null ||
              _storyDuration == null) {
            timer.cancel();
            return;
          }

          final elapsed = DateTime.now().difference(_storyStartTime!);
          final progress =
              (elapsed.inMilliseconds / _storyDuration!.inMilliseconds)
                  .clamp(0.0, 1.0);

          updateProgress(story.storyId, progress);

          if (progress >= 1.0) {
            timer.cancel();
          }
        });

        // Resume auto-advance timer
        _autoAdvanceTimer = Timer(remaining, () {
          if (this.state is StoryViewerLoaded) {
            nextStory();
          }
        });
      }
    } else {
      // Restart if no timing info
      _startAutoAdvance();
    }

    debugPrint('StoryViewerCubit: Story resumed');
  }

  /// Update progress for current story
  void updateProgress(String storyId, double progress) {
    final state = this.state;
    if (state is StoryViewerLoaded) {
      final updatedProgress = Map<String, double>.from(state.progressMap);
      updatedProgress[storyId] = progress;
      emit(state.copyWith(progressMap: updatedProgress));
    }
  }

  /// Send reply to current story
  Future<void> sendReply(String content, String replyType) async {
    final state = this.state;
    if (state is StoryViewerLoaded) {
      final story = state.currentStory;
      if (story == null) return;

      try {
        await _storyRepository.replyToStory(
          storyId: story.storyId,
          replierId: _viewerId,
          content: content,
          replyType: replyType,
        );
      } catch (e) {
        debugPrint('StoryViewerCubit: Error sending reply: $e');
        rethrow;
      }
    }
  }

  /// Mark story as viewed
  Future<void> _markStoryAsViewed(String storyId) async {
    try {
      await _storyRepository.markStoryAsViewed(storyId, _viewerId);
    } catch (e) {
      debugPrint('StoryViewerCubit: Error marking story as viewed: $e');
    }
  }

  /// Start auto-advance timer
  void _startAutoAdvance() {
    final state = this.state;
    if (state is! StoryViewerLoaded || state.isPaused) return;

    final story = state.currentStory;
    if (story == null) return;

    // Image stories: 5 seconds, Video stories: use duration (max 15s)
    _storyDuration = story.mediaType == 'video' && story.duration != null
        ? Duration(seconds: story.duration!.toInt().clamp(1, 15))
        : const Duration(seconds: 5);

    _storyStartTime = DateTime.now();

    // Reset progress
    updateProgress(story.storyId, 0.0);

    // Start progress timer (updates every 100ms for smooth animation)
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (this.state is! StoryViewerLoaded ||
          (this.state as StoryViewerLoaded).isPaused ||
          _storyStartTime == null ||
          _storyDuration == null) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_storyStartTime!);
      final progress = (elapsed.inMilliseconds / _storyDuration!.inMilliseconds)
          .clamp(0.0, 1.0);

      updateProgress(story.storyId, progress);

      if (progress >= 1.0) {
        timer.cancel();
      }
    });

    // Start auto-advance timer
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(_storyDuration!, () {
      if (this.state is StoryViewerLoaded) {
        nextStory();
      }
    });
  }

  /// Stop auto-advance timer
  void _stopAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    _progressTimer?.cancel();
    _progressTimer = null;
    _storyStartTime = null;
    _storyDuration = null;
  }

  /// Delete current story (only if owner)
  Future<void> deleteCurrentStory() async {
    final state = this.state;
    if (state is! StoryViewerLoaded) return;

    final story = state.currentStory;
    if (story == null) return;

    // Check if viewer is the owner
    if (story.authorId != _viewerId) {
      throw Exception('Only story owner can delete');
    }

    try {
      await _storyRepository.deleteStory(story.storyId, _viewerId);

      // Remove story from state and navigate
      final userId = state.usersWithStories[state.currentUserIndex].userId;
      final stories = state.userStoriesMap[userId] ?? [];
      final updatedStories =
          stories.where((s) => s.storyId != story.storyId).toList();

      if (updatedStories.isEmpty) {
        // No more stories for this user, move to next user
        nextUser();
      } else {
        // Update stories map and adjust current index
        final updatedMap =
            Map<String, List<StoryMedia>>.from(state.userStoriesMap);
        updatedMap[userId] = updatedStories;

        final newIndex = state.currentStoryIndex >= updatedStories.length
            ? updatedStories.length - 1
            : state.currentStoryIndex;

        emit(state.copyWith(
          userStoriesMap: updatedMap,
          currentStoryIndex: newIndex,
        ));

        _startAutoAdvance();
      }
    } catch (e) {
      debugPrint('StoryViewerCubit: Error deleting story: $e');
      rethrow;
    }
  }

  @override
  Future<void> close() {
    _stopAutoAdvance();
    _progressTimer?.cancel();
    return super.close();
  }
}
