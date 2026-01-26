import 'package:hive/hive.dart';

part 'match_history_model.g.dart';

@HiveType(typeId: 200) // Ensure typeId is unique in the project
class MatchHistoryModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String nickname;

  @HiveField(2)
  final String avatarUrl;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final int durationSeconds;

  @HiveField(5)
  final bool isFriend;

  MatchHistoryModel({
    required this.id,
    required this.nickname,
    required this.avatarUrl,
    required this.timestamp,
    required this.durationSeconds,
    this.isFriend = false,
  });
}
