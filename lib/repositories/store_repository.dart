import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/utils/level_calculator.dart';

/// A repository for all store and currency-related operations.
class StoreRepository {
  final FirebaseFirestore _db;

  StoreRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Grants a reward to a user for watching an ad.
  Future<void> grantAdReward(String userId) {
    return _db.collection('users').doc(userId).update({
      'superLikes': FieldValue.increment(1),
    });
  }

  /// Handles the purchase of an item using in-app coins.
  Future<void> purchaseWithCoins(String userId,
      {required int coinCost, required int superLikeAmount}) async {
    final userRef = _db.collection('users').doc(userId);

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) {
        throw Exception("User does not exist!");
      }
      final user = UserModel.fromDoc(snapshot);

      if (user.coins < coinCost) {
        throw Exception("Not enough coins.");
      }

      // Calculate new level
      final int newLifetimeSpent = user.lifetimeCoinsSpent + coinCost;
      final int newLevel = LevelCalculator.calculateLevel(newLifetimeSpent);

      transaction.update(userRef, {
        'coins': FieldValue.increment(-coinCost),
        'superLikes': FieldValue.increment(superLikeAmount),
        // Gamification updates
        'lifetimeCoinsSpent': FieldValue.increment(coinCost),
        'userLevel': newLevel,
      });

      // Growth Sync: Award referral commission (10%)
      if (user.referredBy != null && user.referredBy!.isNotEmpty) {
        final referrerId = user.referredBy!;
        final commission = (coinCost * 0.1).round();

        if (commission > 0) {
          final referrerRef = _db.collection('users').doc(referrerId);

          transaction.update(referrerRef, {
            'coins': FieldValue.increment(commission),
            'referralStats.boutiqueCommission':
                FieldValue.increment(commission),
          });

          // Log commission transaction for listener
          final txRef = _db.collection('coinTransactions').doc();
          transaction.set(txRef, {
            'userId': referrerId,
            'type':
                'referral_store_commission', // Key for ReferralScreen listener
            'amount': commission,
            'sourceUserId': userId,
            'description': 'Commission from referred user purchase',
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  /// Checks if the user has enough coins for a premium action (e.g., 50 coins).
  /// In a real app, this would also check for an active "Filter Pass" subscription object.
  Future<bool> hasFilterPassOrCoins(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;

      final int coins = data['coins'] ?? 0;
      // TODO: Check for 'filter_pass_expiry' timestamp if implemented
      return coins >= 50;
    } catch (e) {
      return false;
    }
  }
}
