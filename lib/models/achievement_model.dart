import 'package:cloud_firestore/cloud_firestore.dart';

enum AchievementCategory {
  social,
  spending,
  collection,
  engagement,
  content,
}

enum AchievementTier {
  bronze,
  silver,
  gold,
  platinum,
}

class AchievementModel {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final AchievementCategory category;
  final AchievementTier tier;
  final int targetValue; // e.g., send 10 gifts
  final int rewardCoins;
  final String? rewardBadgeId; // Optional badge reward
  final DateTime createdAt;

  AchievementModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.category,
    required this.tier,
    required this.targetValue,
    required this.rewardCoins,
    this.rewardBadgeId,
    required this.createdAt,
  });

  factory AchievementModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AchievementModel.fromMap(doc.id, data);
  }

  factory AchievementModel.fromMap(String id, Map<String, dynamic> data) {
    return AchievementModel(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      iconUrl: data['iconUrl'] ?? '',
      category: AchievementCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => AchievementCategory.engagement,
      ),
      tier: AchievementTier.values.firstWhere(
        (e) => e.name == data['tier'],
        orElse: () => AchievementTier.bronze,
      ),
      targetValue: data['targetValue'] ?? 0,
      rewardCoins: data['rewardCoins'] ?? 0,
      rewardBadgeId: data['rewardBadgeId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'category': category.name,
      'tier': tier.name,
      'targetValue': targetValue,
      'rewardCoins': rewardCoins,
      'rewardBadgeId': rewardBadgeId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// User's progress on a specific achievement
class UserAchievementProgress {
  final String achievementId;
  final int currentValue;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool rewardClaimed;

  UserAchievementProgress({
    required this.achievementId,
    required this.currentValue,
    required this.isCompleted,
    this.completedAt,
    required this.rewardClaimed,
  });

  factory UserAchievementProgress.fromMap(Map<String, dynamic> data) {
    return UserAchievementProgress(
      achievementId: data['achievementId'] ?? '',
      currentValue: data['currentValue'] ?? 0,
      isCompleted: data['isCompleted'] ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      rewardClaimed: data['rewardClaimed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'achievementId': achievementId,
      'currentValue': currentValue,
      'isCompleted': isCompleted,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'rewardClaimed': rewardClaimed,
    };
  }

  double getProgress(int targetValue) {
    if (targetValue == 0) return 0.0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }
}
