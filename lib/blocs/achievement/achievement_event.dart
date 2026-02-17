import 'package:equatable/equatable.dart';
import 'package:freegram/models/achievement_model.dart';

abstract class AchievementEvent extends Equatable {
  const AchievementEvent();

  @override
  List<Object?> get props => [];
}

class LoadAchievements extends AchievementEvent {}

class UpdateAchievementsInternal extends AchievementEvent {
  final List<UserAchievementProgress> progress;

  const UpdateAchievementsInternal(this.progress);

  @override
  List<Object?> get props => [progress];
}

class ClaimAchievementReward extends AchievementEvent {
  final String userId;
  final String achievementId;

  const ClaimAchievementReward(
      {required this.userId, required this.achievementId});

  @override
  List<Object?> get props => [userId, achievementId];
}

class ConsumeAchievementCelebration extends AchievementEvent {}
