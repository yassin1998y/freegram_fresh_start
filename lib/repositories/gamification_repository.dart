import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/season_model.dart';
import 'package:freegram/models/season_pass_reward.dart';
import 'package:freegram/models/user_model.dart';
import 'package:flutter/foundation.dart';

class GamificationRepository {
  final FirebaseFirestore _db;

  GamificationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<void> addXp(String userId, int amount, {bool isSeasonal = false}) async {
    final userRef = _db.collection('users').doc(userId);

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) throw Exception("User does not exist!");

      final user = UserModel.fromDoc(snapshot);
      Map<String, dynamic> updates = {};

      final newXp = user.xp + amount;
      final newLevel = 1 + (newXp ~/ 1000);
      updates['xp'] = newXp;
      if (newLevel > user.level) {
        updates['level'] = newLevel;
      }

      Map<String, dynamic> leaderboardData = {
        'username': user.username,
        'photoUrl': user.photoUrl,
        'country': user.country,
        'level': user.level,
        'xp': user.xp,
      };

      if (isSeasonal) {
        final newSeasonXp = user.seasonXp + amount;
        final newSeasonLevel = 1 + (newSeasonXp ~/ 500);
        updates['seasonXp'] = newSeasonXp;
        if (newSeasonLevel > user.seasonLevel) {
          updates['seasonLevel'] = newSeasonLevel;
        }
        leaderboardData['level'] = newSeasonLevel;
        leaderboardData['xp'] = newSeasonXp;
      }

      if (user.currentSeasonId.isNotEmpty) {
        final leaderboardRef = _db
            .collection('seasonal_leaderboards')
            .doc(user.currentSeasonId)
            .collection('rankings')
            .doc(userId);
        transaction.set(leaderboardRef, leaderboardData, SetOptions(merge: true));
      }

      transaction.update(userRef, updates);
    });
  }

  Future<void> incrementNearbyDiscovery(String userId) async {
    final userRef = _db.collection('users').doc(userId);
    try {
      await _db.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return;

        final user = UserModel.fromDoc(userDoc);
        final now = DateTime.now();
        final lastDiscovery = user.lastNearbyDiscoveryDate;

        // --- FIX #32: Make streak logic timezone-aware ---
        final nowUtc = now.toUtc();
        final lastDiscoveryUtc = lastDiscovery.toUtc();

        final startOfTodayUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
        final startOfLastDayUtc = DateTime.utc(lastDiscoveryUtc.year, lastDiscoveryUtc.month, lastDiscoveryUtc.day);

        // Don't update if a discovery has already happened today (in UTC)
        if (startOfTodayUtc.isAtSameMomentAs(startOfLastDayUtc)) {
          return;
        }

        final yesterdayUtc = startOfTodayUtc.subtract(const Duration(days: 1));

        int streak = user.nearbyDiscoveryStreak;
        // If the last discovery was yesterday, increment the streak. Otherwise, reset it.
        if (startOfLastDayUtc.isAtSameMomentAs(yesterdayUtc)) {
          streak++;
        } else {
          streak = 1; // Reset streak
        }

        transaction.update(userRef, {
          'nearbyDiscoveryStreak': streak,
          'lastNearbyDiscoveryDate': now,
          'xp': FieldValue.increment(10 * streak), // Bonus XP for maintaining streak
        });
      });
    } catch (e) {
      debugPrint("Error incrementing nearby discovery: $e");
    }
  }

  Future<void> grantFirstContactBonus(String userId, String discoveredUserId) async {
    final userRef = _db.collection('users').doc(userId);
    try {
      final userDoc = await userRef.get();
      if (!userDoc.exists) return;

      final user = UserModel.fromDoc(userDoc);
      if (!user.friends.contains(discoveredUserId)) {
        await addXp(userId, 50, isSeasonal: true); // Grant 50 bonus XP
      }
    } catch (e) {
      debugPrint("Error granting first contact bonus: $e");
    }
  }

  Future<Season?> getCurrentSeason() async {
    final now = DateTime.now();
    final snapshot = await _db
        .collection('seasons')
        .where('startDate', isLessThanOrEqualTo: now)
        .orderBy('startDate', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final season = Season.fromDoc(snapshot.docs.first);

    if (now.isAfter(season.endDate)) return null;

    return season;
  }

  Future<List<SeasonPassReward>> getRewardsForSeason(String seasonId) async {
    final snapshot = await _db
        .collection('seasons')
        .doc(seasonId)
        .collection('rewards')
        .orderBy('level')
        .get();
    return snapshot.docs.map((doc) => SeasonPassReward.fromDoc(doc)).toList();
  }

  Future<void> checkAndResetSeason(String userId, Season currentSeason) async {
    final userRef = _db.collection('users').doc(userId);
    final userDoc = await userRef.get();
    final user = UserModel.fromDoc(userDoc);

    if (user.currentSeasonId != currentSeason.id) {
      await userRef.update({
        'currentSeasonId': currentSeason.id,
        'seasonXp': 0,
        'seasonLevel': 0,
        'claimedSeasonRewards': [],
      });
    }
  }

  Future<void> claimSeasonReward(String userId, SeasonPassReward reward) async {
    final userRef = _db.collection('users').doc(userId);

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) throw Exception("User does not exist!");

      final user = UserModel.fromDoc(snapshot);

      if (user.seasonLevel < reward.level) {
        throw Exception("You have not reached the required level yet.");
      }
      if (user.claimedSeasonRewards.contains(reward.level)) {
        throw Exception("You have already claimed this reward.");
      }

      Map<String, dynamic> updates = {
        'claimedSeasonRewards': FieldValue.arrayUnion([reward.level])
      };

      switch (reward.type) {
        case RewardType.coins:
          updates['coins'] = FieldValue.increment(reward.amount);
          break;
        case RewardType.superLikes:
          updates['superLikes'] = FieldValue.increment(reward.amount);
          break;
        case RewardType.badge:
        case RewardType.profileBoost:
          break;
      }

      transaction.update(userRef, updates);
    });
  }

  Future<QuerySnapshot> getGlobalLeaderboard(String seasonId, {int limit = 100}) {
    return _db
        .collection('seasonal_leaderboards')
        .doc(seasonId)
        .collection('rankings')
        .orderBy('level', descending: true)
        .orderBy('xp', descending: true)
        .limit(limit)
        .get();
  }

  Future<QuerySnapshot> getCountryLeaderboard(String seasonId, String country, {int limit = 100}) {
    return _db
        .collection('seasonal_leaderboards')
        .doc(seasonId)
        .collection('rankings')
        .where('country', isEqualTo: country)
        .orderBy('level', descending: true)
        .orderBy('xp', descending: true)
        .limit(limit)
        .get();
  }

  Future<List<DocumentSnapshot>> getFriendsLeaderboard(String seasonId, List<String> friendIds) async {
    if (friendIds.isEmpty) {
      return [];
    }
    final rankingsRef = _db.collection('seasonal_leaderboards').doc(seasonId).collection('rankings');
    final List<Future<DocumentSnapshot>> futures = [];

    for (String id in friendIds) {
      futures.add(rankingsRef.doc(id).get());
    }
    final results = await Future.wait(futures);
    return results.where((doc) => doc.exists).toList();
  }

  Future<DocumentSnapshot> getUserRanking(String seasonId, String userId) {
    return _db
        .collection('seasonal_leaderboards')
        .doc(seasonId)
        .collection('rankings')
        .doc(userId)
        .get();
  }
}