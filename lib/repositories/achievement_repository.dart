import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/achievement_model.dart';
import 'dart:async';

class AchievementRepository {
  final FirebaseFirestore _db;

  AchievementRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Get all achievements
  Stream<List<AchievementModel>> getAchievements() {
    return _db
        .collection('achievements')
        .orderBy('category')
        .orderBy('tier')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AchievementModel.fromDoc(doc)).toList());
  }

  /// Get user's achievement progress
  Stream<List<UserAchievementProgress>> getUserProgress(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('achievements')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserAchievementProgress.fromMap(doc.data()))
            .toList());
  }

  /// Get single achievement by ID
  Future<AchievementModel?> getAchievementById(String id) async {
    final doc = await _db.collection('achievements').doc(id).get();
    if (!doc.exists) return null;
    return AchievementModel.fromDoc(doc);
  }

  /// Get achievement by its reward badge ID
  Future<AchievementModel?> getAchievementByBadgeId(String badgeId) async {
    final snapshot = await _db
        .collection('achievements')
        .where('rewardBadgeId', isEqualTo: badgeId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return AchievementModel.fromDoc(snapshot.docs.first);
  }

  /// Get achievement by its icon URL
  Future<AchievementModel?> getAchievementByBadgeUrl(String badgeUrl) async {
    final snapshot = await _db
        .collection('achievements')
        .where('iconUrl', isEqualTo: badgeUrl)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return AchievementModel.fromDoc(snapshot.docs.first);
  }

  /// Update achievement progress
  /// Returns true if the achievement was just completed during this increment
  Future<bool> updateProgress(
    String userId,
    String achievementId,
    int increment,
  ) async {
    final progressRef = _db
        .collection('users')
        .doc(userId)
        .collection('achievements')
        .doc(achievementId);

    final achievement =
        await _db.collection('achievements').doc(achievementId).get();
    if (!achievement.exists) return false;

    final achievementData = AchievementModel.fromDoc(achievement);

    return await _db.runTransaction((transaction) async {
      final progressDoc = await transaction.get(progressRef);

      int currentValue = 0;
      bool alreadyCompleted = false;
      if (progressDoc.exists) {
        currentValue = progressDoc.data()?['currentValue'] ?? 0;
        alreadyCompleted = progressDoc.data()?['isCompleted'] ?? false;
      }

      final newValue = currentValue + increment;
      final isCompleted = newValue >= achievementData.targetValue;
      final newlyCompleted = isCompleted && !alreadyCompleted;

      final progressData = progressDoc.exists ? progressDoc.data() : null;

      transaction.set(
        progressRef,
        {
          'achievementId': achievementId,
          'currentValue': newValue,
          'isCompleted': isCompleted,
          'completedAt': newlyCompleted
              ? FieldValue.serverTimestamp()
              : (progressData != null ? progressData['completedAt'] : null),
          'rewardClaimed': progressData != null
              ? (progressData['rewardClaimed'] ?? false)
              : false,
        },
        SetOptions(merge: true),
      );

      return newlyCompleted;
    });
  }

  /// Claim achievement reward
  Future<void> claimReward(String userId, String achievementId) async {
    final progressRef = _db
        .collection('users')
        .doc(userId)
        .collection('achievements')
        .doc(achievementId);

    final achievement =
        await _db.collection('achievements').doc(achievementId).get();
    if (!achievement.exists) throw Exception('Achievement not found');

    final achievementData = AchievementModel.fromDoc(achievement);

    await _db.runTransaction((transaction) async {
      final progressDoc = await transaction.get(progressRef);
      if (!progressDoc.exists) throw Exception('Progress not found');

      final progress = UserAchievementProgress.fromMap(progressDoc.data()!);
      if (!progress.isCompleted) throw Exception('Achievement not completed');
      if (progress.rewardClaimed) throw Exception('Reward already claimed');

      // Update progress
      transaction.update(progressRef, {'rewardClaimed': true});

      // Award coins
      final userRef = _db.collection('users').doc(userId);
      transaction.update(userRef, {
        'coins': FieldValue.increment(achievementData.rewardCoins),
      });

      // Log transaction
      final transactionRef = _db.collection('coinTransactions').doc();
      transaction.set(transactionRef, {
        'userId': userId,
        'type': 'achievement_reward',
        'amount': achievementData.rewardCoins,
        'description': 'Achievement: ${achievementData.name}',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Seed initial achievements
  Future<void> seedAchievements() async {
    final snapshot = await _db.collection('achievements').limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    final batch = _db.batch();
    for (final achievement in initialAchievements) {
      final docRef = _db.collection('achievements').doc(achievement.id);
      batch.set(docRef, achievement.toMap());
    }
    await batch.commit();
  }

  static final List<AchievementModel> initialAchievements = [
    // Social Achievements
    AchievementModel(
      id: 'social_first_gift',
      name: 'First Gift',
      description: 'Send your first gift',
      iconUrl: 'https://placeholder.com/achievement/first_gift.png',
      category: AchievementCategory.social,
      tier: AchievementTier.bronze,
      targetValue: 1,
      rewardCoins: 50,
      createdAt: DateTime.now(),
    ),
    AchievementModel(
      id: 'social_gift_sender_10',
      name: 'Gift Giver',
      description: 'Send 10 gifts',
      iconUrl: 'https://placeholder.com/achievement/gift_giver.png',
      category: AchievementCategory.social,
      tier: AchievementTier.silver,
      targetValue: 10,
      rewardCoins: 100,
      createdAt: DateTime.now(),
    ),
    AchievementModel(
      id: 'social_gift_sender_50',
      name: 'Generous Soul',
      description: 'Send 50 gifts',
      iconUrl: 'https://placeholder.com/achievement/generous.png',
      category: AchievementCategory.social,
      tier: AchievementTier.gold,
      targetValue: 50,
      rewardCoins: 500,
      rewardBadgeId: 'badge_generous',
      createdAt: DateTime.now(),
    ),

    // Spending Achievements
    AchievementModel(
      id: 'spending_100',
      name: 'Spender',
      description: 'Spend 100 coins',
      iconUrl: 'https://placeholder.com/achievement/spender.png',
      category: AchievementCategory.spending,
      tier: AchievementTier.bronze,
      targetValue: 100,
      rewardCoins: 50,
      createdAt: DateTime.now(),
    ),
    AchievementModel(
      id: 'spending_1000',
      name: 'Big Spender',
      description: 'Spend 1000 coins',
      iconUrl: 'https://placeholder.com/achievement/big_spender.png',
      category: AchievementCategory.spending,
      tier: AchievementTier.silver,
      targetValue: 1000,
      rewardCoins: 200,
      createdAt: DateTime.now(),
    ),
    AchievementModel(
      id: 'spending_10000',
      name: 'Whale',
      description: 'Spend 10,000 coins',
      iconUrl: 'https://placeholder.com/achievement/whale.png',
      category: AchievementCategory.spending,
      tier: AchievementTier.platinum,
      targetValue: 10000,
      rewardCoins: 2000,
      rewardBadgeId: 'badge_whale',
      createdAt: DateTime.now(),
    ),

    // Collection Achievements
    AchievementModel(
      id: 'collection_5_unique',
      name: 'Collector',
      description: 'Collect 5 unique gifts',
      iconUrl: 'https://placeholder.com/achievement/collector.png',
      category: AchievementCategory.collection,
      tier: AchievementTier.bronze,
      targetValue: 5,
      rewardCoins: 100,
      createdAt: DateTime.now(),
    ),
    AchievementModel(
      id: 'collection_15_unique',
      name: 'Curator',
      description: 'Collect 15 unique gifts',
      iconUrl: 'https://placeholder.com/achievement/curator.png',
      category: AchievementCategory.collection,
      tier: AchievementTier.gold,
      targetValue: 15,
      rewardCoins: 500,
      rewardBadgeId: 'badge_curator',
      createdAt: DateTime.now(),
    ),

    // Engagement Achievements
    AchievementModel(
      id: 'engagement_7_day_streak',
      name: 'Dedicated',
      description: 'Login for 7 consecutive days',
      iconUrl: 'https://placeholder.com/achievement/dedicated.png',
      category: AchievementCategory.engagement,
      tier: AchievementTier.silver,
      targetValue: 7,
      rewardCoins: 200,
      createdAt: DateTime.now(),
    ),
    AchievementModel(
      id: 'engagement_30_day_streak',
      name: 'Loyal',
      description: 'Login for 30 consecutive days',
      iconUrl: 'https://placeholder.com/achievement/loyal.png',
      category: AchievementCategory.engagement,
      tier: AchievementTier.platinum,
      targetValue: 30,
      rewardCoins: 1000,
      rewardBadgeId: 'badge_loyal',
      createdAt: DateTime.now(),
    ),

    // Content Achievements
    AchievementModel(
      id: 'content_first_post',
      name: 'First Post',
      description: 'Create your first post',
      iconUrl: 'https://placeholder.com/achievement/first_post.png',
      category: AchievementCategory.content,
      tier: AchievementTier.bronze,
      targetValue: 1,
      rewardCoins: 50,
      createdAt: DateTime.now(),
    ),
  ];
}
