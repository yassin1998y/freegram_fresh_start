// lib/services/achievement_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/achievement_repository.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/models/achievement_model.dart';

/// Singleton service that listens to global repository events and updates achievement progress.
/// This centralizes achievement logic and removes direct dependencies from repositories.
class AchievementService {
  final AchievementRepository _achievementRepo;
  final PostRepository _postRepo;
  final GiftRepository _giftRepo;
  final ChatRepository _chatRepo;
  final UserRepository _userRepo;

  StreamSubscription? _postSubscription;
  StreamSubscription? _giftPurchaseSubscription;
  StreamSubscription? _giftSentSubscription;

  AchievementService({
    AchievementRepository? achievementRepo,
    PostRepository? postRepo,
    GiftRepository? giftRepo,
    ChatRepository? chatRepo,
    UserRepository? userRepo,
  })  : _achievementRepo = achievementRepo ?? locator<AchievementRepository>(),
        _postRepo = postRepo ?? locator<PostRepository>(),
        _giftRepo = giftRepo ?? locator<GiftRepository>(),
        _chatRepo = chatRepo ?? locator<ChatRepository>(),
        _userRepo = userRepo ?? locator<UserRepository>();

  /// Initialize listeners
  void init() {
    _subscribeToEvents();
    debugPrint('AchievementService: Initialized and listening for events');
  }

  void _subscribeToEvents() {
    // 1. Listen for new posts
    _postSubscription = _postRepo.onPostCreated.listen((event) {
      _handlePostCreated(event.userId, event.postId);
    });

    // 2. Listen for gift purchases (Spending achievements)
    _giftPurchaseSubscription = _giftRepo.onGiftPurchased.listen((event) {
      _handleGiftPurchased(event.userId, event.price);
    });

    // 3. Listen for gift sent (Social & Spending achievements)
    _giftSentSubscription = _giftRepo.onGiftSent.listen((event) {
      _handleGiftSent(event.senderId, event.price, event.giftId);
    });
  }

  Future<void> _handlePostCreated(String userId, String postId) async {
    try {
      final achievementId = 'content_first_post';
      final newlyCompleted = await _achievementRepo.updateProgress(
        userId,
        achievementId,
        1,
      );
      if (newlyCompleted) {
        await _broadcastAchievement(userId, achievementId);
      }
    } catch (e) {
      debugPrint('AchievementService: Error handling post created: $e');
    }
  }

  Future<void> _handleGiftPurchased(String userId, int price) async {
    try {
      final ids = ['spending_100', 'spending_1000', 'spending_10000'];
      for (final id in ids) {
        final newlyCompleted =
            await _achievementRepo.updateProgress(userId, id, price);
        if (newlyCompleted) {
          await _broadcastAchievement(userId, id);
        }
      }
    } catch (e) {
      debugPrint('AchievementService: Error handling gift purchased: $e');
    }
  }

  Future<void> _handleGiftSent(
      String senderId, int price, String giftId) async {
    try {
      // Social achievements
      final socialIds = [
        'social_first_gift',
        'social_gift_sender_10',
        'social_gift_sender_50'
      ];
      for (final id in socialIds) {
        final newlyCompleted =
            await _achievementRepo.updateProgress(senderId, id, 1);
        if (newlyCompleted) {
          await _broadcastAchievement(senderId, id);
        }
      }

      // Spending achievements
      final spendingIds = ['spending_100', 'spending_1000', 'spending_10000'];
      for (final id in spendingIds) {
        final newlyCompleted =
            await _achievementRepo.updateProgress(senderId, id, price);
        if (newlyCompleted) {
          await _broadcastAchievement(senderId, id);
        }
      }

      // Special gift achievements
      if (giftId == 'love_teddy') {
        final newlyCompleted = await _achievementRepo.updateProgress(
            senderId, 'social_teddy_bear', 1);
        if (newlyCompleted) {
          await _broadcastAchievement(senderId, 'social_teddy_bear');
        }
      } else if (giftId == 'love_rose') {
        final newlyCompleted = await _achievementRepo.updateProgress(
            senderId, 'social_red_rose', 1);
        if (newlyCompleted) {
          await _broadcastAchievement(senderId, 'social_red_rose');
        }
      }
    } catch (e) {
      debugPrint('AchievementService: Error handling gift sent: $e');
    }
  }

  /// Broadcasts achievement completion
  Future<void> _broadcastAchievement(
      String userId, String achievementId) async {
    try {
      final achievement =
          await _achievementRepo.getAchievementById(achievementId);
      if (achievement == null) return;

      final user = await _userRepo.getUser(userId);
      final username = user.username;
      final userPhotoUrl = user.photoUrl;

      debugPrint(
          'AchievementService: Broadcasting completion of ${achievement.name} for $username');

      // 1. Inject Milestone Card into Feed (Gold/Platinum only)
      if (achievement.tier == AchievementTier.gold ||
          achievement.tier == AchievementTier.platinum) {
        await _postRepo.recordMilestoneEvent(MilestoneFeedItem(
          userId: userId,
          username: username,
          userPhotoUrl: userPhotoUrl,
          achievementName: achievement.name,
          badgeUrl: achievement.iconUrl,
          timestamp: DateTime.now(),
          tier: achievement.tier.name,
        ));
      }

      // 2. Broadcast to current chat if user is in one
      await _chatRepo.broadcastSystemMilestone(userId, achievement.name);

      // 3. Update equipped badge if it has a reward
      if (achievement.rewardBadgeId != null) {
        await _userRepo.updateUserBadge(
            userId, achievement.rewardBadgeId!, achievement.iconUrl);
      }
    } catch (e) {
      debugPrint('AchievementService: Error broadcasting achievement: $e');
    }
  }

  /// Dispose subscriptions when the service is destroyed (though it's usually a singleton)
  void dispose() {
    _postSubscription?.cancel();
    _giftPurchaseSubscription?.cancel();
    _giftSentSubscription?.cancel();
  }
}
