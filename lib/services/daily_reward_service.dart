import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/locator.dart';

class DailyRewardService {
  final FirebaseFirestore _db;
  final UserRepository _userRepository;

  DailyRewardService({
    FirebaseFirestore? firestore,
    UserRepository? userRepository,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _userRepository = userRepository ?? locator<UserRepository>();

  /// Check if a daily reward is available for the user
  Future<DailyRewardStatus> checkRewardStatus(String userId) async {
    final user = await _userRepository.getUser(userId);

    final now = DateTime.now();
    final lastClaim = user.lastDailyRewardClaim;
    final lastClaimDate =
        DateTime(lastClaim.year, lastClaim.month, lastClaim.day);
    final today = DateTime(now.year, now.month, now.day);

    final difference = today.difference(lastClaimDate).inDays;

    if (difference == 0) {
      return DailyRewardStatus.claimedToday;
    } else if (difference == 1) {
      // Consecutive day
      return DailyRewardStatus.available;
    } else {
      // Streak broken (or first time)
      // If difference > 1, streak is broken
      return DailyRewardStatus.available; // Still available, but streak resets
    }
  }

  /// Get the reward for the current streak day
  DailyReward getRewardForDay(int day) {
    // Cycle every 7 days, or cap at 30? Let's do a 7-day cycle for simplicity first,
    // or a 30-day cycle as per plan. Plan said 30 days.
    // Let's implement a 7-day cycle that repeats, with big rewards at day 7.

    final int cycleDay = (day - 1) % 7 + 1;

    switch (cycleDay) {
      case 1:
        return DailyReward(day: cycleDay, coins: 10);
      case 2:
        return DailyReward(day: cycleDay, coins: 15);
      case 3:
        return DailyReward(day: cycleDay, coins: 20);
      case 4:
        return DailyReward(day: cycleDay, coins: 25);
      case 5:
        return DailyReward(day: cycleDay, coins: 30);
      case 6:
        return DailyReward(day: cycleDay, coins: 40);
      case 7:
        return DailyReward(day: cycleDay, coins: 100, isBigReward: true);
      default:
        return DailyReward(day: cycleDay, coins: 10);
    }
  }

  /// Claim the daily reward
  Future<DailyReward> claimReward(String userId) async {
    return await _db.runTransaction((transaction) async {
      final userDoc =
          await transaction.get(_db.collection('users').doc(userId));
      if (!userDoc.exists) throw Exception('User not found');

      final user = UserModel.fromDoc(userDoc);
      final now = DateTime.now();
      final lastClaim = user.lastDailyRewardClaim;
      final lastClaimDate =
          DateTime(lastClaim.year, lastClaim.month, lastClaim.day);
      final today = DateTime(now.year, now.month, now.day);

      final difference = today.difference(lastClaimDate).inDays;

      if (difference == 0) {
        throw Exception('Reward already claimed today');
      }

      int newStreak = user.dailyLoginStreak + 1;
      if (difference > 1) {
        // Streak broken
        newStreak = 1;
      }

      final reward = getRewardForDay(newStreak);

      transaction.update(userDoc.reference, {
        'coins': FieldValue.increment(reward.coins),
        'lastDailyRewardClaim': FieldValue.serverTimestamp(),
        'dailyLoginStreak': newStreak,
      });

      // Log transaction
      final transactionRef = _db.collection('coinTransactions').doc();
      transaction.set(transactionRef, {
        'userId': userId,
        'type': 'daily_reward',
        'amount': reward.coins,
        'description': 'Daily Reward Day $newStreak',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return reward;
    });
  }
}

enum DailyRewardStatus {
  available,
  claimedToday,
  error,
}

class DailyReward {
  final int day;
  final int coins;
  final bool isBigReward;

  DailyReward({
    required this.day,
    required this.coins,
    this.isBigReward = false,
  });
}
