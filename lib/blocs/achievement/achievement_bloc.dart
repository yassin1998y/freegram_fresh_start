import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/blocs/achievement/achievement_event.dart';
import 'package:freegram/blocs/achievement/achievement_state.dart';
import 'package:freegram/repositories/achievement_repository.dart';
import 'package:freegram/models/achievement_model.dart';

class AchievementBloc extends Bloc<AchievementEvent, AchievementState> {
  final AchievementRepository _repository;
  StreamSubscription? _achievementsSubscription;
  StreamSubscription? _progressSubscription;
  StreamSubscription? _authSubscription;

  AchievementBloc({required AchievementRepository repository})
      : _repository = repository,
        super(AchievementInitial()) {
    on<LoadAchievements>(_onLoadAchievements);
    on<UpdateAchievementsInternal>(_onUpdateAchievementsInternal);
    on<ClaimAchievementReward>(_onClaimReward);
    on<ConsumeAchievementCelebration>(_onConsumeCelebration);

    // Initial load
    add(LoadAchievements());

    // Listen to Auth state to refresh achievements for the right user
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        add(LoadAchievements());
      }
    });
  }

  Future<void> _onLoadAchievements(
      LoadAchievements event, Emitter<AchievementState> emit) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      emit(const AchievementError("User not logged in"));
      return;
    }

    emit(AchievementLoading());

    // Stop previous subscriptions
    _achievementsSubscription?.cancel();
    _progressSubscription?.cancel();

    try {
      // Get static list of all achievements (first time)
      final allAchievementsList = await _repository.getAchievements().first;

      // Listen to progress stream
      _progressSubscription =
          _repository.getUserProgress(user.uid).listen((progress) {
        add(UpdateAchievementsInternal(progress));
      });

      emit(AchievementLoaded(
        allAchievements: allAchievementsList,
        userProgress: const [],
      ));
    } catch (e) {
      emit(AchievementError(e.toString()));
    }
  }

  void _onUpdateAchievementsInternal(
      UpdateAchievementsInternal event, Emitter<AchievementState> emit) {
    if (state is AchievementLoaded) {
      final loadedState = state as AchievementLoaded;

      // Check for newly completed achievements
      AchievementModel? newlyCompleted;

      if (loadedState.userProgress.isNotEmpty) {
        for (final newProgress in event.progress) {
          if (newProgress.isCompleted) {
            // Find old progress for this achievement
            final oldProgress = loadedState.userProgress.firstWhere(
              (p) => p.achievementId == newProgress.achievementId,
              orElse: () => UserAchievementProgress(
                achievementId: newProgress.achievementId,
                currentValue: 0,
                isCompleted: false,
                rewardClaimed: false,
              ),
            );

            if (!oldProgress.isCompleted) {
              // This achievement was just completed!
              newlyCompleted = loadedState.allAchievements.firstWhere(
                (a) => a.id == newProgress.achievementId,
              );
              break; // Trigger one celebration at a time
            }
          }
        }
      }

      emit(loadedState.copyWith(
        userProgress: event.progress,
        newlyCompleted: newlyCompleted,
        clearNewlyCompleted: newlyCompleted == null,
      ));
    }
  }

  Future<void> _onClaimReward(
      ClaimAchievementReward event, Emitter<AchievementState> emit) async {
    if (state is AchievementLoaded) {
      final loadedState = state as AchievementLoaded;

      emit(AchievementClaiming(
        allAchievements: loadedState.allAchievements,
        userProgress: loadedState.userProgress,
      ));

      try {
        await _repository.claimReward(event.userId, event.achievementId);

        // Success state will be naturally updated by the stream listener
        emit(AchievementClaimSuccess(
          achievementId: event.achievementId,
          allAchievements: loadedState.allAchievements,
          userProgress: loadedState.userProgress,
        ));
      } catch (e) {
        emit(AchievementError(e.toString()));
        // Recover to loaded state
        emit(loadedState);
      }
    }
  }

  void _onConsumeCelebration(
      ConsumeAchievementCelebration event, Emitter<AchievementState> emit) {
    if (state is AchievementLoaded) {
      final loadedState = state as AchievementLoaded;
      emit(loadedState.copyWith(clearNewlyCompleted: true));
    }
  }

  @override
  Future<void> close() {
    _achievementsSubscription?.cancel();
    _progressSubscription?.cancel();
    _authSubscription?.cancel();
    return super.close();
  }
}
