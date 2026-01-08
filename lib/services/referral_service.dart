import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReferralService {
  final FirebaseFirestore _db;

  ReferralService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static const int referrerReward = 100; // Coins for referrer
  static const int refereeReward = 50; // Coins for new user

  /// Generate a unique referral code for a user
  Future<String> generateReferralCode(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) throw Exception('User not found');

    // Check if user already has a code
    final existingCode = userDoc.data()?['referralCode'];
    if (existingCode != null) return existingCode as String;

    // Generate new code
    String code;
    bool isUnique = false;
    int attempts = 0;

    do {
      code = _generateCode();
      final existing = await _db
          .collection('users')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();
      isUnique = existing.docs.isEmpty;
      attempts++;
    } while (!isUnique && attempts < 10);

    if (!isUnique) throw Exception('Failed to generate unique code');

    // Save code to user
    await _db.collection('users').doc(userId).update({
      'referralCode': code,
      'referralStats': {
        'totalReferrals': 0,
        'successfulReferrals': 0,
        'coinsEarned': 0,
      },
    });

    return code;
  }

  /// Apply a referral code when a new user signs up
  Future<void> applyReferralCode(String newUserId, String referralCode) async {
    // Find referrer by code
    final referrerQuery = await _db
        .collection('users')
        .where('referralCode', isEqualTo: referralCode)
        .limit(1)
        .get();

    if (referrerQuery.docs.isEmpty) {
      throw Exception('Invalid referral code');
    }

    final referrerId = referrerQuery.docs.first.id;

    // Check if new user already used a code
    final newUserDoc = await _db.collection('users').doc(newUserId).get();
    if (newUserDoc.data()?['referredBy'] != null) {
      throw Exception('User already used a referral code');
    }

    // Can't refer yourself
    if (referrerId == newUserId) {
      throw Exception('Cannot use your own referral code');
    }

    await _db.runTransaction((transaction) async {
      // Update new user
      transaction.update(_db.collection('users').doc(newUserId), {
        'referredBy': referrerId,
        'referralCodeUsed': referralCode,
      });

      // Award coins to new user
      transaction.update(_db.collection('users').doc(newUserId), {
        'coins': FieldValue.increment(refereeReward),
      });

      // Award coins to referrer
      transaction.update(_db.collection('users').doc(referrerId), {
        'coins': FieldValue.increment(referrerReward),
        'referralStats.totalReferrals': FieldValue.increment(1),
        'referralStats.successfulReferrals': FieldValue.increment(1),
        'referralStats.coinsEarned': FieldValue.increment(referrerReward),
      });

      // Log transactions
      final referrerTxRef = _db.collection('coinTransactions').doc();
      transaction.set(referrerTxRef, {
        'userId': referrerId,
        'type': 'referral_reward',
        'amount': referrerReward,
        'description': 'Referral reward for inviting user',
        'timestamp': FieldValue.serverTimestamp(),
      });

      final refereeTxRef = _db.collection('coinTransactions').doc();
      transaction.set(refereeTxRef, {
        'userId': newUserId,
        'type': 'referral_bonus',
        'amount': refereeReward,
        'description': 'Welcome bonus for using referral code',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Create referral record
      final referralRef = _db.collection('referrals').doc();
      transaction.set(referralRef, {
        'referrerId': referrerId,
        'refereeId': newUserId,
        'referralCode': referralCode,
        'timestamp': FieldValue.serverTimestamp(),
        'referrerReward': referrerReward,
        'refereeReward': refereeReward,
      });
    });
  }

  /// Get referral stats for a user
  Future<ReferralStats> getReferralStats(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) throw Exception('User not found');

    final data = userDoc.data();
    final statsData = data?['referralStats'] as Map<String, dynamic>?;

    return ReferralStats(
      referralCode: data?['referralCode'] as String?,
      totalReferrals: statsData?['totalReferrals'] ?? 0,
      successfulReferrals: statsData?['successfulReferrals'] ?? 0,
      coinsEarned: statsData?['coinsEarned'] ?? 0,
    );
  }

  /// Get list of users referred by this user
  Stream<List<ReferralRecord>> getReferrals(String userId) {
    return _db
        .collection('referrals')
        .where('referrerId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReferralRecord.fromMap(doc.id, doc.data()))
            .toList());
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Removed ambiguous chars
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)])
        .join();
  }
}

class ReferralStats {
  final String? referralCode;
  final int totalReferrals;
  final int successfulReferrals;
  final int coinsEarned;

  ReferralStats({
    this.referralCode,
    required this.totalReferrals,
    required this.successfulReferrals,
    required this.coinsEarned,
  });
}

class ReferralRecord {
  final String id;
  final String referrerId;
  final String refereeId;
  final String referralCode;
  final DateTime timestamp;
  final int referrerReward;
  final int refereeReward;

  ReferralRecord({
    required this.id,
    required this.referrerId,
    required this.refereeId,
    required this.referralCode,
    required this.timestamp,
    required this.referrerReward,
    required this.refereeReward,
  });

  factory ReferralRecord.fromMap(String id, Map<String, dynamic> data) {
    return ReferralRecord(
      id: id,
      referrerId: data['referrerId'] ?? '',
      refereeId: data['refereeId'] ?? '',
      referralCode: data['referralCode'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      referrerReward: data['referrerReward'] ?? 0,
      refereeReward: data['refereeReward'] ?? 0,
    );
  }
}
