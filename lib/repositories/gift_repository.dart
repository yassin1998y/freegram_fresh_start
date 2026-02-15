import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/models/user_inventory_model.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/models/wishlist_item_model.dart';

import 'package:freegram/utils/level_calculator.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/achievement_repository.dart';

class GiftRepository {
  final FirebaseFirestore _db;

  GiftRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Helper to generate chat ID from two user IDs
  String _getChatId(String userId1, String userId2) {
    final ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  /// Get all available gifts, optionally filtered
  Stream<List<GiftModel>> getAvailableGifts({
    GiftCategory? category,
    GiftRarity? rarity,
    bool limitedOnly = false,
  }) {
    Query query = _db.collection('gifts');

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }
    if (rarity != null) {
      query = query.where('rarity', isEqualTo: rarity.name);
    }
    if (limitedOnly) {
      query = query.where('isLimited', isEqualTo: true);
    }

    // Order by price by default
    // query = query.orderBy('priceInCoins');

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => GiftModel.fromDoc(doc)).toList());
  }

  final Map<String, GiftModel> _giftCache = {};

  /// Get a specific gift by ID
  Future<GiftModel?> getGiftById(String giftId) async {
    if (_giftCache.containsKey(giftId)) {
      return _giftCache[giftId];
    }

    final doc = await _db.collection('gifts').doc(giftId).get();
    if (!doc.exists) return null;

    final gift = GiftModel.fromDoc(doc);
    _giftCache[giftId] = gift;
    return gift;
  }

  /// Purchase a gift for oneself
  Future<OwnedGift> purchaseGift(String userId, String giftId) async {
    // Determine gift price for achievement logging outside transaction
    final giftDocPreview = await _db.collection('gifts').doc(giftId).get();
    late final GiftModel gift;
    if (giftDocPreview.exists) {
      gift = GiftModel.fromDoc(giftDocPreview);
    }

    final result = await _db.runTransaction((transaction) async {
      // 1. Get gift details
      final giftDoc =
          await transaction.get(_db.collection('gifts').doc(giftId));
      if (!giftDoc.exists) {
        throw Exception('Gift not found');
      }
      final gift = GiftModel.fromDoc(giftDoc);

      // 2. Get user
      final userDoc =
          await transaction.get(_db.collection('users').doc(userId));
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      final user = UserModel.fromDoc(userDoc);

      // 3. Validate balance
      if (user.coins < gift.priceInCoins) {
        throw Exception('Insufficient coins');
      }

      // 4. Check availability (limited editions)
      if (gift.isLimited && gift.maxQuantity != null) {
        if (gift.soldCount >= gift.maxQuantity!) {
          throw Exception('Gift sold out');
        }
      }

      // 5. Create owned gift
      final ownedGiftRef =
          _db.collection('users').doc(userId).collection('inventory').doc();

      final ownedGift = OwnedGift(
        id: ownedGiftRef.id,
        giftId: giftId,
        ownerId: userId,
        receivedAt: DateTime.now(),
        receivedFrom: null, // Purchased for self
        giftMessage: null,
        isDisplayed: false,
        displayOrder: 0,
        isUpgraded: false,
        upgradeLevel: 0,
        purchasePrice: gift.priceInCoins,
        currentMarketValue: gift.priceInCoins,
        isLocked: false,
      );

      // 6. Update user (deduct coins, update stats)
      final int newLifetimeSpent = user.lifetimeCoinsSpent + gift.priceInCoins;
      final int newLevel = LevelCalculator.calculateLevel(newLifetimeSpent);

      transaction.update(userDoc.reference, {
        'coins': FieldValue.increment(-gift.priceInCoins),
        'lifetimeCoinsSpent': FieldValue.increment(gift.priceInCoins),
        'userLevel': newLevel,
        'uniqueGiftsCollected': FieldValue.increment(1), // Simplified logic
      });

      // 7. Update gift (increment sold count)
      transaction.update(giftDoc.reference, {
        'soldCount': FieldValue.increment(1),
      });

      // 8. Save owned gift
      transaction.set(ownedGiftRef, ownedGift.toMap());

      // 9. Log transaction
      final transactionRef = _db.collection('coinTransactions').doc();
      transaction.set(transactionRef, {
        'userId': userId,
        'type': 'spend',
        'amount': -gift.priceInCoins,
        'description': 'Purchased gift: ${gift.name}',
        'category': 'gift',
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {'giftId': giftId, 'ownedGiftId': ownedGift.id},
      });

      return ownedGift;
    });

    // TRIGGER ACHIEVEMENT: Spending
    try {
      final achievementRepo = locator<AchievementRepository>();
      // Spending: Count coins spent
      await achievementRepo.updateProgress(
          userId, 'spending_100', gift.priceInCoins);
      await achievementRepo.updateProgress(
          userId, 'spending_1000', gift.priceInCoins);
      await achievementRepo.updateProgress(
          userId, 'spending_10000', gift.priceInCoins);
    } catch (e) {
      // Ignore gamification errors
    }

    return result;
  }

  /// Send a gift to another user (buy and send)
  Future<void> buyAndSendGift({
    required String senderId,
    required String recipientId,
    required String giftId,
    String? message,
  }) async {
    await _db.runTransaction((transaction) async {
      // 1. Get gift details
      final giftDoc =
          await transaction.get(_db.collection('gifts').doc(giftId));
      if (!giftDoc.exists) throw Exception('Gift not found');
      final gift = GiftModel.fromDoc(giftDoc);

      // 2. Get sender
      final senderDoc =
          await transaction.get(_db.collection('users').doc(senderId));
      if (!senderDoc.exists) throw Exception('Sender not found');
      final sender = UserModel.fromDoc(senderDoc);

      // 2.1 Get recipient
      final recipientDoc =
          await transaction.get(_db.collection('users').doc(recipientId));
      if (!recipientDoc.exists) throw Exception('Recipient not found');
      final recipient = UserModel.fromDoc(recipientDoc);

      // 3. Validate balance
      if (sender.coins < gift.priceInCoins) {
        throw Exception('Insufficient coins');
      }

      // 4. Create owned gift for recipient
      final ownedGiftRef = _db
          .collection('users')
          .doc(recipientId)
          .collection('inventory')
          .doc();

      final ownedGift = OwnedGift(
        id: ownedGiftRef.id,
        giftId: giftId,
        ownerId: recipientId,
        receivedAt: DateTime.now(),
        receivedFrom: senderId,
        giftMessage: message,
        isDisplayed: false,
        displayOrder: 0,
        isUpgraded: false,
        upgradeLevel: 0,
        purchasePrice: gift.priceInCoins,
        currentMarketValue: gift.priceInCoins,
        isLocked: false,
      );

      // 5. Update sender (deduct coins)
      final int newLifetimeSpent =
          sender.lifetimeCoinsSpent + gift.priceInCoins;
      final int newLevel = LevelCalculator.calculateLevel(newLifetimeSpent);

      transaction.update(senderDoc.reference, {
        'coins': FieldValue.increment(-gift.priceInCoins),
        'lifetimeCoinsSpent': FieldValue.increment(gift.priceInCoins),
        'userLevel': newLevel,
        'totalGiftsSent': FieldValue.increment(1),
      });

      // 6. Update recipient stats
      transaction.update(recipientDoc.reference, {
        'totalGiftsReceived': FieldValue.increment(1),
        'uniqueGiftsCollected': FieldValue.increment(1),
      });

      // 7. Update gift stats
      transaction.update(giftDoc.reference, {
        'soldCount': FieldValue.increment(1),
      });

      // 8. Save owned gift
      transaction.set(ownedGiftRef, ownedGift.toMap());

      // 9. Log transaction
      final transactionRef = _db.collection('coinTransactions').doc();
      transaction.set(transactionRef, {
        'userId': senderId,
        'type': 'gift_sent',
        'amount': -gift.priceInCoins,
        'description': 'Sent gift: ${gift.name}',
        'category': 'gift',
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'giftId': giftId,
          'recipientId': recipientId,
          'ownedGiftId': ownedGift.id
        },
      });

      // 10. Create notification for recipient in their subcollection
      final notificationRef = _db
          .collection('users')
          .doc(recipientId)
          .collection('notifications')
          .doc();
      transaction.set(notificationRef, {
        'userId': recipientId,
        'type': 'gift_received',
        'fromUserId': senderId,
        'fromUsername': sender.username,
        'fromUserPhotoUrl': sender.photoUrl,
        'giftId': giftId,
        'message': message ?? 'Sent you a gift!',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // 11. Create chat message for the gift
      // Get or create chat between sender and recipient
      final chatId = _getChatId(senderId, recipientId);
      final chatRef = _db.collection('chats').doc(chatId);
      final messageRef = chatRef.collection('messages').doc();

      transaction.set(messageRef, {
        'senderId': senderId,
        'text': message ?? '🎁 Sent you a gift!',
        'timestamp': FieldValue.serverTimestamp(),
        'isSeen': false,
        'isDelivered': true,
        'reactions': {},
        'giftId': giftId,
        'isGiftMessage': true,
      });

      // Update chat document
      transaction.set(
          chatRef,
          {
            'users': [senderId, recipientId],
            'usernames': {
              senderId: sender.username,
              recipientId: recipient.username,
            },
            'lastMessage': '🎁 Gift',
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
            'unreadFor': FieldValue.arrayUnion([recipientId]),
            'chatType': 'friend',
          },
          SetOptions(merge: true));
    });

    // TRIGGER ACHIEVEMENTS: Social & Spending
    // Note: This logic should ideally be triggered by a cloud function or event listener
    // to ensure consistency, but keeping streamlined for now.
    // TRIGGER ACHIEVEMENTS: Social & Spending
    try {
      final giftDoc = await _db.collection('gifts').doc(giftId).get();
      final gift = GiftModel.fromDoc(giftDoc);
      final giftPrice = gift.priceInCoins;

      final achievementRepo = locator<AchievementRepository>();
      // Social: Count gifts sent
      achievementRepo.updateProgress(senderId, 'social_first_gift', 1);
      achievementRepo.updateProgress(senderId, 'social_gift_sender_10', 1);
      achievementRepo.updateProgress(senderId, 'social_gift_sender_50', 1);

      // Spending: Count coins spent
      achievementRepo.updateProgress(senderId, 'spending_100', giftPrice);
      achievementRepo.updateProgress(senderId, 'spending_1000', giftPrice);
      achievementRepo.updateProgress(senderId, 'spending_10000', giftPrice);
    } catch (e) {
      // Non-critical
    }

    // Track recent recipient (outside transaction)
    await trackRecentRecipient(
      senderId: senderId,
      recipientId: recipientId,
      recipientUsername: (await _db.collection('users').doc(recipientId).get())
              .data()?['username'] as String? ??
          'Unknown',
      recipientPhotoUrl: (await _db.collection('users').doc(recipientId).get())
          .data()?['photoUrl'] as String?,
      giftId: giftId,
    );
  }

  /// Get user's inventory with pagination support
  Stream<List<OwnedGift>> getUserInventory(
    String userId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    Query query = _db
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .orderBy('receivedAt', descending: true);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    if (limit > 0) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => OwnedGift.fromDoc(doc)).toList());
  }

  /// Toggle display status of a gift
  Future<void> toggleGiftDisplay({
    required String userId,
    required String giftId,
    required bool isDisplayed,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .doc(giftId)
          .update({
        'isDisplayed': !isDisplayed,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Check if user should receive display reward
      if (!isDisplayed) {
        await checkAndAwardDisplayReward(userId);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user has 3+ displayed gifts and award reward if eligible
  Future<Map<String, dynamic>?> checkAndAwardDisplayReward(
      String userId) async {
    try {
      final displayedGifts = await _db
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .where('isDisplayed', isEqualTo: true)
          .get();

      if (displayedGifts.docs.length < 3) return null;

      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      final hasReceivedReward =
          userData['hasReceivedDisplayReward'] as bool? ?? false;

      if (hasReceivedReward) return null;

      const rewardAmount = 50;

      await _db.runTransaction((transaction) async {
        transaction.update(userDoc.reference, {
          'coins': FieldValue.increment(rewardAmount),
          'hasReceivedDisplayReward': true,
          'displayRewardReceivedAt': FieldValue.serverTimestamp(),
        });

        final transactionRef = _db.collection('coinTransactions').doc();
        transaction.set(transactionRef, {
          'userId': userId,
          'type': 'earn',
          'amount': rewardAmount,
          'description': 'Display Reward: Showcased 3 gifts on profile',
          'category': 'display_reward',
          'timestamp': FieldValue.serverTimestamp(),
        });

        final achievementRef = _db
            .collection('users')
            .doc(userId)
            .collection('achievements')
            .doc('showcase_master');

        transaction.set(achievementRef, {
          'achievementId': 'showcase_master',
          'name': 'Showcase Master',
          'description': 'Displayed 3 gifts on your profile',
          'unlockedAt': FieldValue.serverTimestamp(),
          'rewardCoins': rewardAmount,
        });
      });

      return {
        'awarded': true,
        'amount': rewardAmount,
        'achievement': 'Showcase Master',
      };
    } catch (e) {
      return null;
    }
  }

  /// Track recent recipient after sending gift
  Future<void> trackRecentRecipient({
    required String senderId,
    required String recipientId,
    required String recipientUsername,
    String? recipientPhotoUrl,
    String? giftId,
  }) async {
    try {
      final recentRef = _db
          .collection('users')
          .doc(senderId)
          .collection('recentRecipients')
          .doc(recipientId);

      final doc = await recentRef.get();

      if (doc.exists) {
        await recentRef.update({
          'lastSentAt': FieldValue.serverTimestamp(),
          'giftCount': FieldValue.increment(1),
          'lastGiftId': giftId,
        });
      } else {
        await recentRef.set({
          'userId': recipientId,
          'username': recipientUsername,
          'photoUrl': recipientPhotoUrl,
          'lastSentAt': FieldValue.serverTimestamp(),
          'giftCount': 1,
          'lastGiftId': giftId,
        });
      }
    } catch (e) {
      // Non-critical, don't rethrow
    }
  }

  /// Get recent recipients for a user
  Stream<List<Map<String, dynamic>>> getRecentRecipients(String userId,
      {int limit = 10}) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('recentRecipients')
        .orderBy('lastSentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Toggle favorite status of a gift
  Future<void> toggleFavorite({
    required String userId,
    required String giftId,
    required bool isFavorite,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .doc(giftId)
          .update({
        'isFavorite': !isFavorite,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Get favorite gifts for a user
  Stream<List<OwnedGift>> getFavoriteGifts(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .where('isFavorite', isEqualTo: true)
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OwnedGift.fromDoc(doc)).toList());
  }

  // ============================================================================
  // GIFT HISTORY & TRACKING
  // ============================================================================

  /// Get gifts sent by a user
  Stream<List<OwnedGift>> getSentGifts(String userId) {
    // Query all users' inventories where receivedFrom == userId
    return _db
        .collectionGroup('inventory')
        .where('receivedFrom', isEqualTo: userId)
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OwnedGift.fromDoc(doc)).toList());
  }

  /// Get gifts received by a user
  Stream<List<OwnedGift>> getReceivedGifts(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .where('receivedFrom', isNotEqualTo: null)
        .orderBy('receivedFrom')
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OwnedGift.fromDoc(doc)).toList());
  }

  /// Get displayed gifts for a user
  Stream<List<OwnedGift>> getDisplayedGifts(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .where('isDisplayed', isEqualTo: true)
        .orderBy('displayOrder')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OwnedGift.fromDoc(doc)).toList());
  }

  /// Reorder displayed gifts
  Future<void> reorderDisplayedGifts({
    required String userId,
    required List<String> orderedGiftIds,
  }) async {
    final batch = _db.batch();

    for (int i = 0; i < orderedGiftIds.length; i++) {
      final giftRef = _db
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .doc(orderedGiftIds[i]);

      batch.update(giftRef, {
        'displayOrder': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ============================================================================
  // GIFT REACTIONS & SOCIAL
  // ============================================================================

  /// React to a received gift
  Future<void> reactToGift({
    required String userId,
    required String giftId,
    required String reaction, // emoji: ❤️, 😍, 🎉, 🙏, 😊
  }) async {
    final reactionRef = _db
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .doc(giftId)
        .collection('reactions')
        .doc();

    await reactionRef.set({
      'userId': userId,
      'reaction': reaction,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update gift with reaction count
    await _db
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .doc(giftId)
        .update({
      'reactionCount': FieldValue.increment(1),
      'lastReactionAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get reactions for a gift
  Stream<List<Map<String, dynamic>>> getGiftReactions({
    required String userId,
    required String giftId,
  }) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .doc(giftId)
        .collection('reactions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Send thank you message to gift sender
  Future<void> thankSender({
    required String recipientId,
    required String senderId,
    required String giftId,
    String? message,
  }) async {
    // Create notification for sender
    await _db.collection('notifications').add({
      'userId': senderId,
      'type': 'gift_thanked',
      'fromUserId': recipientId,
      'giftId': giftId,
      'message': message ?? 'Thanked you for the gift!',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // Mark gift as thanked
    await _db
        .collection('users')
        .doc(recipientId)
        .collection('inventory')
        .doc(giftId)
        .update({
      'hasThanked': true,
      'thankedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================================
  // DAILY FREE GIFT
  // ============================================================================

  /// Check if user can claim daily gift
  Future<Map<String, dynamic>> getDailyGiftStatus(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return {'canClaim': false, 'reason': 'User not found'};
    }

    final userData = userDoc.data()!;
    final lastClaimed = userData['lastDailyGiftClaimed'] as Timestamp?;

    if (lastClaimed == null) {
      return {'canClaim': true, 'streak': 0};
    }

    final lastClaimedDate = lastClaimed.toDate();
    final now = DateTime.now();
    final daysSinceLastClaim = now.difference(lastClaimedDate).inDays;

    if (daysSinceLastClaim >= 1) {
      final streak = daysSinceLastClaim == 1
          ? (userData['dailyGiftStreak'] as int? ?? 0)
          : 0;
      return {'canClaim': true, 'streak': streak};
    }

    final timeUntilNext = lastClaimedDate.add(const Duration(days: 1));
    return {
      'canClaim': false,
      'reason': 'Already claimed today',
      'nextClaimAt': timeUntilNext.toIso8601String(),
      'streak': userData['dailyGiftStreak'] ?? 0,
    };
  }

  /// Claim daily free gift
  Future<OwnedGift> claimDailyGift(String userId) async {
    final status = await getDailyGiftStatus(userId);
    if (status['canClaim'] != true) {
      throw Exception(status['reason'] ?? 'Cannot claim daily gift');
    }

    // Get random common gift
    final giftsSnapshot = await _db
        .collection('gifts')
        .where('rarity', isEqualTo: 'common')
        .limit(10)
        .get();

    if (giftsSnapshot.docs.isEmpty) {
      throw Exception('No gifts available');
    }

    final randomGift = giftsSnapshot
        .docs[DateTime.now().millisecond % giftsSnapshot.docs.length];
    final gift = GiftModel.fromDoc(randomGift);

    return await _db.runTransaction((transaction) async {
      final userDoc =
          await transaction.get(_db.collection('users').doc(userId));
      final userData = userDoc.data()!;

      // Calculate streak
      final lastClaimed = userData['lastDailyGiftClaimed'] as Timestamp?;
      final currentStreak = lastClaimed != null &&
              DateTime.now().difference(lastClaimed.toDate()).inDays == 1
          ? (userData['dailyGiftStreak'] as int? ?? 0) + 1
          : 1;

      // Create owned gift
      final ownedGiftRef =
          _db.collection('users').doc(userId).collection('inventory').doc();

      final ownedGift = OwnedGift(
        id: ownedGiftRef.id,
        giftId: gift.id,
        ownerId: userId,
        receivedAt: DateTime.now(),
        receivedFrom: 'daily_reward',
        giftMessage: 'Daily free gift! Streak: $currentStreak days',
        isDisplayed: false,
        displayOrder: 0,
        isUpgraded: false,
        upgradeLevel: 0,
        purchasePrice: 0,
        currentMarketValue: gift.priceInCoins,
        isLocked: false,
      );

      // Update user
      transaction.update(userDoc.reference, {
        'lastDailyGiftClaimed': FieldValue.serverTimestamp(),
        'dailyGiftStreak': currentStreak,
        'totalDailyGiftsClaimed': FieldValue.increment(1),
      });

      // Save gift
      transaction.set(ownedGiftRef, ownedGift.toMap());

      // Log transaction
      final transactionRef = _db.collection('coinTransactions').doc();
      transaction.set(transactionRef, {
        'userId': userId,
        'type': 'earn',
        'amount': 0,
        'description': 'Daily free gift claimed (Streak: $currentStreak)',
        'category': 'daily_reward',
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {'giftId': gift.id, 'streak': currentStreak},
      });

      return ownedGift;
    });
  }

  // ============================================================================
  // MARKETPLACE & DISCOVERY
  // ============================================================================

  /// Get trending gifts (most sent in last 7 days)
  Future<List<GiftModel>> getTrendingGifts({int limit = 10}) async {
    final snapshot = await _db
        .collection('gifts')
        .orderBy('soldCount', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => GiftModel.fromDoc(doc)).toList();
  }

  /// Get new arrivals (recently added gifts)
  Future<List<GiftModel>> getNewArrivals({int limit = 10}) async {
    final snapshot = await _db
        .collection('gifts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => GiftModel.fromDoc(doc)).toList();
  }

  /// Search gifts by name or description
  Future<List<GiftModel>> searchGifts(String query) async {
    final lowerQuery = query.toLowerCase();

    // Firestore doesn't support full-text search, so we get all and filter
    final snapshot = await _db.collection('gifts').get();

    return snapshot.docs
        .map((doc) => GiftModel.fromDoc(doc))
        .where((gift) =>
            gift.name.toLowerCase().contains(lowerQuery) ||
            gift.description.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Send an already owned gift to another user
  Future<void> sendOwnedGift({
    required String senderId,
    required String recipientId,
    required String ownedGiftId,
    String? message,
  }) async {
    await _db.runTransaction((transaction) async {
      // Get the owned gift
      final ownedGiftDoc = await transaction.get(_db
          .collection('users')
          .doc(senderId)
          .collection('inventory')
          .doc(ownedGiftId));

      if (!ownedGiftDoc.exists) {
        throw Exception('Gift not found in inventory');
      }

      final ownedGift = OwnedGift.fromDoc(ownedGiftDoc);

      // Check if gift is locked
      if (ownedGift.isLocked) {
        throw Exception('Gift is locked and cannot be sent');
      }

      // Get sender for notification
      final senderDoc =
          await transaction.get(_db.collection('users').doc(senderId));
      final sender = UserModel.fromDoc(senderDoc);

      // Get recipient for username
      final recipientDoc =
          await transaction.get(_db.collection('users').doc(recipientId));
      if (!recipientDoc.exists) throw Exception('Recipient not found');
      final recipient = UserModel.fromDoc(recipientDoc);

      // Create new owned gift for recipient
      final newGiftRef = _db
          .collection('users')
          .doc(recipientId)
          .collection('inventory')
          .doc();

      final newGift = OwnedGift(
        id: newGiftRef.id,
        giftId: ownedGift.giftId,
        ownerId: recipientId,
        receivedAt: DateTime.now(),
        receivedFrom: senderId,
        giftMessage: message,
        isDisplayed: false,
        displayOrder: 0,
        isUpgraded: ownedGift.isUpgraded,
        upgradeLevel: ownedGift.upgradeLevel,
        purchasePrice: ownedGift.purchasePrice,
        currentMarketValue: ownedGift.currentMarketValue,
        isLocked: false,
      );

      // Delete from sender's inventory
      transaction.delete(ownedGiftDoc.reference);

      // Add to recipient's inventory
      transaction.set(newGiftRef, newGift.toMap());

      // Update stats
      transaction.update(senderDoc.reference, {
        'totalGiftsSent': FieldValue.increment(1),
      });

      transaction.update(recipientDoc.reference, {
        'totalGiftsReceived': FieldValue.increment(1),
      });

      // Create notification in user subcollection
      final notificationRef = _db
          .collection('users')
          .doc(recipientId)
          .collection('notifications')
          .doc();
      transaction.set(notificationRef, {
        'userId': recipientId,
        'type': 'gift_received',
        'fromUserId': senderId,
        'fromUsername': sender.username,
        'fromUserPhotoUrl': sender.photoUrl,
        'giftId': ownedGift.giftId,
        'message': message ?? 'Sent you a gift from their collection!',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Create chat message for the gift
      final chatId = _getChatId(senderId, recipientId);
      final chatRef = _db.collection('chats').doc(chatId);
      final messageRef = chatRef.collection('messages').doc();

      transaction.set(messageRef, {
        'senderId': senderId,
        'text':
            message ?? '\ud83c\udf81 Sent you a gift from their collection!',
        'timestamp': FieldValue.serverTimestamp(),
        'isSeen': false,
        'isDelivered': true,
        'reactions': {},
        'giftId': ownedGift.giftId,
        'isGiftMessage': true,
      });

      // Update chat document
      transaction.set(
          chatRef,
          {
            'users': [senderId, recipientId],
            'usernames': {
              senderId: sender.username,
              recipientId: recipient.username,
            },
            'lastMessage': '\ud83c\udf81 Gift',
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
            'unreadFor': FieldValue.arrayUnion([recipientId]),
            'chatType': 'friend',
          },
          SetOptions(merge: true));
    });

    // Track recent recipient
    await trackRecentRecipient(
      senderId: senderId,
      recipientId: recipientId,
      recipientUsername: (await _db.collection('users').doc(recipientId).get())
              .data()?['username'] as String? ??
          'Unknown',
      recipientPhotoUrl: (await _db.collection('users').doc(recipientId).get())
          .data()?['photoUrl'] as String?,
      giftId: ownedGiftId,
    );
  }

  // ============================================================================
  // CATALOG SEEDING
  // ============================================================================

  /// Seed initial gifts if catalog is empty
  Future<void> seedGifts() async {
    final snapshot = await _db.collection('gifts').limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    final batch = _db.batch();
    for (final gift in _initialGifts) {
      final docRef = _db.collection('gifts').doc(gift.id);
      batch.set(docRef, gift.toMap());
    }
    await batch.commit();
  }

  /// Initial gift catalog
  static final List<GiftModel> _initialGifts = [
    // Love Category
    GiftModel(
      id: 'love_rose',
      name: 'Red Rose',
      description: 'A classic symbol of love',
      animationUrl:
          'https://assets.lottiefiles.com/packages/lf20_s2lryxtd.json',
      thumbnailUrl: '',
      priceInCoins: 10,
      rarity: GiftRarity.common,
      category: GiftCategory.love,
      createdAt: DateTime.now(),
    ),
    GiftModel(
      id: 'love_heart',
      name: 'Heart Balloon',
      description: 'Love is in the air!',
      animationUrl: 'https://assets.lottiefiles.com/packages/lf20_jR229r.json',
      thumbnailUrl: '',
      priceInCoins: 25,
      rarity: GiftRarity.common,
      category: GiftCategory.love,
      createdAt: DateTime.now(),
    ),
    GiftModel(
      id: 'love_teddy',
      name: 'Teddy Bear',
      description: 'Cuddly and cute',
      animationUrl:
          'https://assets.lottiefiles.com/private_files/lf30_1TMF5F.json',
      thumbnailUrl: '',
      priceInCoins: 50,
      rarity: GiftRarity.rare,
      category: GiftCategory.love,
      createdAt: DateTime.now(),
    ),
    GiftModel(
      id: 'love_ring',
      name: 'Diamond Ring',
      description: 'Put a ring on it!',
      animationUrl: 'https://assets.lottiefiles.com/packages/lf20_w5h9jq.json',
      thumbnailUrl: '',
      priceInCoins: 500,
      rarity: GiftRarity.legendary,
      category: GiftCategory.love,
      createdAt: DateTime.now(),
    ),

    // Celebration Category
    GiftModel(
      id: 'cel_popper',
      name: 'Party Popper',
      description: 'Let\'s celebrate!',
      animationUrl:
          'https://assets.lottiefiles.com/packages/lf20_u4jjb9bd.json',
      thumbnailUrl: '',
      priceInCoins: 10,
      rarity: GiftRarity.common,
      category: GiftCategory.celebration,
      createdAt: DateTime.now(),
    ),
    GiftModel(
      id: 'cel_cake',
      name: 'Birthday Cake',
      description: 'Make a wish!',
      animationUrl: 'https://assets.lottiefiles.com/packages/lf20_w5h9jq.json',
      thumbnailUrl: '',
      priceInCoins: 100,
      rarity: GiftRarity.rare,
      category: GiftCategory.celebration,
      createdAt: DateTime.now(),
    ),
    GiftModel(
      id: 'cel_trophy',
      name: 'Gold Trophy',
      description: 'You\'re the winner!',
      animationUrl: 'https://assets.lottiefiles.com/packages/lf20_w5h9jq.json',
      thumbnailUrl: '',
      priceInCoins: 300,
      rarity: GiftRarity.legendary,
      category: GiftCategory.celebration,
      createdAt: DateTime.now(),
    ),

    // Funny Category
    GiftModel(
      id: 'fun_pizza',
      name: 'Pizza Slice',
      description: 'Yummy!',
      animationUrl:
          'https://assets.lottiefiles.com/packages/lf20_s2lryxtd.json',
      thumbnailUrl: '',
      priceInCoins: 20,
      rarity: GiftRarity.common,
      category: GiftCategory.funny,
      createdAt: DateTime.now(),
    ),
    GiftModel(
      id: 'fun_sunglasses',
      name: 'Cool Shades',
      description: 'Deal with it',
      animationUrl: 'https://assets.lottiefiles.com/packages/lf20_jR229r.json',
      thumbnailUrl: '',
      priceInCoins: 40,
      rarity: GiftRarity.common,
      category: GiftCategory.funny,
      createdAt: DateTime.now(),
    ),
  ];

  // ==================== WISHLIST METHODS ====================

  /// Get user's wishlist items
  Stream<List<WishlistItem>> getWishlist(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .orderBy('priority')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => WishlistItem.fromDoc(doc)).toList());
  }

  /// Add gift to wishlist
  Future<void> addToWishlist({
    required String userId,
    required String giftId,
    int priority = 3,
    String? note,
  }) async {
    // Get gift details
    final gift = await getGiftById(giftId);
    if (gift == null) throw Exception('Gift not found');

    final wishlistItem = WishlistItem(
      id: '', // Will be set by Firestore
      userId: userId,
      giftId: giftId,
      giftName: gift.name,
      giftImageUrl: gift.thumbnailUrl,
      giftPrice: gift.priceInCoins,
      priority: priority,
      note: note,
      addedAt: DateTime.now(),
    );

    await _db
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .add(wishlistItem.toMap());
  }

  /// Remove gift from wishlist
  Future<void> removeFromWishlist(String userId, String wishlistItemId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .doc(wishlistItemId)
        .delete();
  }

  /// Update wishlist item priority or note
  Future<void> updateWishlistItem({
    required String userId,
    required String wishlistItemId,
    int? priority,
    String? note,
    bool? isReceived,
  }) async {
    final Map<String, dynamic> updates = {};
    if (priority != null) updates['priority'] = priority;
    if (note != null) updates['note'] = note;
    if (isReceived != null) updates['isReceived'] = isReceived;

    if (updates.isNotEmpty) {
      await _db
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .doc(wishlistItemId)
          .update(updates);
    }
  }

  /// Check if gift is in wishlist
  Future<bool> isInWishlist(String userId, String giftId) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .where('giftId', isEqualTo: giftId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Get wishlist share link
  String getWishlistShareLink(String userId) {
    // TODO: Implement deep linking
    return 'https://freegram.app/wishlist/$userId';
  }
  // ==================== LIKE SYSTEM METHODS ====================

  /// Toggle like status for a gift
  Future<bool> toggleLike(String userId, String giftId) async {
    final likeRef = _db
        .collection('users')
        .doc(userId)
        .collection('likedGifts')
        .doc(giftId);

    final doc = await likeRef.get();
    final isLiked = doc.exists;

    if (isLiked) {
      await likeRef.delete();
      // Decrement like count on gift (optional, for trending)
      await _db.collection('gifts').doc(giftId).update({
        'likeCount': FieldValue.increment(-1),
      });
      return false;
    } else {
      await likeRef.set({
        'likedAt': FieldValue.serverTimestamp(),
      });
      // Increment like count on gift
      await _db.collection('gifts').doc(giftId).update({
        'likeCount': FieldValue.increment(1),
      });
      return true;
    }
  }

  /// Check if gift is liked by user
  Future<bool> isLiked(String userId, String giftId) async {
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('likedGifts')
        .doc(giftId)
        .get();
    return doc.exists;
  }

  /// Get stream of liked gift IDs for a user
  Stream<List<String>> getLikedGiftIds(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('likedGifts')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }
  // ==================== USER COIN METHODS ====================

  /// Get current user coin balance
  Future<int> getUserCoins(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return 0;
    return doc.data()?['coins'] ?? 0;
  }

  // ==================== LEADERBOARD METHODS ====================

  /// Get top gift senders
  Future<List<UserModel>> getTopSenders({int limit = 10}) async {
    final snapshot = await _db
        .collection('users')
        .orderBy('totalGiftsSent', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => UserModel.fromDoc(doc)).toList();
  }

  /// Get top gift receivers
  Future<List<UserModel>> getTopReceivers({int limit = 10}) async {
    final snapshot = await _db
        .collection('users')
        .orderBy('totalGiftsReceived', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => UserModel.fromDoc(doc)).toList();
  }

  /// Get top collectors (by unique gifts)
  Future<List<UserModel>> getTopCollectors({int limit = 10}) async {
    final snapshot = await _db
        .collection('users')
        .orderBy('uniqueGiftsCollected', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => UserModel.fromDoc(doc)).toList();
  }

  // ==================== UPGRADE SYSTEM METHODS ====================

  /// Upgrade an owned gift to the next level
  Future<void> upgradeGift(String userId, String ownedGiftId) async {
    await _db.runTransaction((transaction) async {
      // 1. Get owned gift
      final ownedGiftRef = _db
          .collection('users')
          .doc(userId)
          .collection('ownedGifts')
          .doc(ownedGiftId);

      final ownedGiftDoc = await transaction.get(ownedGiftRef);
      if (!ownedGiftDoc.exists) {
        throw Exception('Gift not found in inventory');
      }
      final ownedGift = OwnedGift.fromDoc(ownedGiftDoc);

      // 2. Check max level (e.g., 5)
      if (ownedGift.upgradeLevel >= 5) {
        throw Exception('Gift is already at maximum level');
      }

      // 3. Calculate upgrade cost
      // Cost = Base Price * (Current Level + 1)
      // We need to fetch the original gift to get the base price if not stored
      // But OwnedGift stores purchasePrice, we can use that as base
      final upgradeCost =
          ownedGift.purchasePrice * (ownedGift.upgradeLevel + 1);

      // 4. Get user and check balance
      final userRef = _db.collection('users').doc(userId);
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw Exception('User not found');

      final currentCoins = userDoc.data()?['coins'] ?? 0;
      if (currentCoins < upgradeCost) {
        throw Exception('Insufficient coins for upgrade');
      }

      // 5. Perform upgrade
      transaction.update(userRef, {
        'coins': FieldValue.increment(-upgradeCost),
        'lifetimeCoinsSpent': FieldValue.increment(upgradeCost),
      });

      // Update gift level
      transaction.update(ownedGiftRef, {
        'upgradeLevel': FieldValue.increment(1),
        'isUpgraded': true,
        'currentMarketValue':
            FieldValue.increment(upgradeCost), // Value increases
      });
    });
  }
}
