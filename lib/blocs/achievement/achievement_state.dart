import 'package:equatable/equatable.dart';
import 'package:freegram/models/achievement_model.dart';

abstract class AchievementState extends Equatable {
  const AchievementState();

  @override
  List<Object?> get props => [];
}

class AchievementInitial extends AchievementState {}

class AchievementLoading extends AchievementState {}

class AchievementLoaded extends AchievementState {
  final List<AchievementModel> allAchievements;
  final List<UserAchievementProgress> userProgress;
  final AchievementModel?
      newlyCompleted; // Transient: only non-null for a single emission

  const AchievementLoaded({
    required this.allAchievements,
    required this.userProgress,
    this.newlyCompleted,
  });

  @override
  List<Object?> get props => [allAchievements, userProgress, newlyCompleted];

  AchievementLoaded copyWith({
    List<AchievementModel>? allAchievements,
    List<UserAchievementProgress>? userProgress,
    AchievementModel? newlyCompleted,
    bool clearNewlyCompleted = false,
  }) {
    return AchievementLoaded(
      allAchievements: allAchievements ?? this.allAchievements,
      userProgress: userProgress ?? this.userProgress,
      newlyCompleted:
          clearNewlyCompleted ? null : (newlyCompleted ?? this.newlyCompleted),
    );
  }
}

class AchievementError extends AchievementState {
  final String message;

  const AchievementError(this.message);

  @override
  List<Object?> get props => [message];
}

class AchievementClaiming extends AchievementLoaded {
  const AchievementClaiming({
    required super.allAchievements,
    required super.userProgress,
    super.newlyCompleted,
  });
}

class AchievementClaimSuccess extends AchievementLoaded {
  final String achievementId;

  const AchievementClaimSuccess({
    required String achievementId,
    required super.allAchievements,
    required super.userProgress,
    super.newlyCompleted,
  }) : achievementId = achievementId;

  @override
  List<Object?> get props =>
      [achievementId, allAchievements, userProgress, newlyCompleted];
}
