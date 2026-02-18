// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/utils/level_calculator.dart';

// Helper function remains the same
String _uidShortFromFull(String fullId) {
  if (fullId.isEmpty) return '';
  final bytes = utf8.encode(fullId);
  final digest = sha256.convert(bytes);
  return digest.toString().substring(0, 8);
}

class UserModel extends Equatable {
  final String id;
  final String uidShort; // Derived from id
  final String username;
  final String email;
  final String photoUrl;
  final int pictureVersion;
  final String bio;
  final String fcmToken;
  final bool presence;
  final DateTime lastSeen;
  final String country;
  final GeoPoint? location; // User's current location (for nearby features)
  final int age;
  final String gender;
  final List<String> interests;
  final DateTime createdAt;
  final List<String> friends;
  final List<String> friendRequestsSent;
  final List<String> friendRequestsReceived;
  final List<String> blockedUsers;
  final List<String> followedPages; // Pages this user follows
  /// Affinity scores for users and pages this user interacts with
  /// Key: userId or pageId, Value: affinity score (0.0 to 10.0)
  /// Example: {'user_123': 5.2, 'page_456': 1.5, 'user_789': 3.8}
  /// Max 200 entries (enforced in Cloud Functions)
  final Map<String, double> userAffinities;
  final int coins;
  final int superLikes; // Keep this field
  final DateTime lastFreeSuperLike;
  final String? referredBy; // ID of the user who referred this user

  // --- GAMIFICATION FIELDS ---
  final int lifetimeCoinsSpent; // For level calculation
  final int userLevel; // Calculated from spending
  final String? equippedBorderId; // Currently equipped border
  final String? equippedBadgeId; // Currently equipped badge
  final String? equippedBadgeUrl; // URL for the equipped badge

  // Inventory stats
  final int totalGiftsReceived;
  final int totalGiftsSent;
  final int uniqueGiftsCollected;
  final int totalMessagesSent;
  final int socialPoints;

  // Engagement
  final DateTime lastDailyRewardClaim;
  final int dailyLoginStreak;
  // ---------------------------
  // Removed equippedProfileFrameId
  // Removed equippedBadgeId
  // Removed xp
  // Removed level
  // Removed currentSeasonId
  // Removed seasonXp
  // Removed seasonLevel
  // Removed claimedSeasonRewards
  final String nearbyStatusMessage;
  final String nearbyStatusEmoji;
  final int nearbyDiscoveryStreak;
  final DateTime lastNearbyDiscoveryDate;
  final Map<String, String>? sharedMusicTrack;
  final int nearbyDataVersion;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.photoUrl = '',
    this.pictureVersion = 0,
    this.bio = '',
    this.fcmToken = '',
    this.presence = false,
    required this.lastSeen,
    this.country = '',
    this.location,
    this.age = 0,
    this.gender = '',
    this.interests = const [],
    required this.createdAt,
    this.friends = const [],
    this.friendRequestsSent = const [],
    this.friendRequestsReceived = const [],
    this.blockedUsers = const [],
    this.followedPages = const [], // Initialize empty list
    this.userAffinities = const {}, // Initialize empty map
    this.coins = 0,
    this.superLikes = 1, // Keep
    required this.lastFreeSuperLike,
    this.referredBy,

    // Gamification defaults
    this.lifetimeCoinsSpent = 0,
    this.userLevel = 1,
    this.equippedBorderId,
    this.equippedBadgeId,
    this.equippedBadgeUrl,
    this.totalGiftsReceived = 0,
    this.totalGiftsSent = 0,
    this.uniqueGiftsCollected = 0,
    this.totalMessagesSent = 0,
    this.socialPoints = 0,
    required this.lastDailyRewardClaim, // Initialize with epoch in factory
    this.dailyLoginStreak = 0,
    // Remove fields from constructor
    this.nearbyStatusMessage = '',
    this.nearbyStatusEmoji = '',
    this.nearbyDiscoveryStreak = 0,
    required this.lastNearbyDiscoveryDate,
    this.sharedMusicTrack,
    this.nearbyDataVersion = 0,
  }) : uidShort = _uidShortFromFull(id);

  bool get isOnline => presence;

  // _toDateTime, _getList, _getIntList remain the same
  static DateTime _toDateTime(dynamic timestamp, [String? fieldName]) {
    if (timestamp == null) {
      if (fieldName == 'createdAt' || fieldName == 'lastSeen') {
        return DateTime.now();
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ??
          DateTime.fromMillisecondsSinceEpoch(0); // Safer fallback
    }
    if (timestamp is int) {
      if (timestamp > 1000000000000) {
        // Milliseconds
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        // Seconds
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
    }
    if (timestamp is Map && timestamp.containsKey('_seconds')) {
      return Timestamp(timestamp['_seconds'], timestamp['_nanoseconds'] ?? 0)
          .toDate();
    }
    debugPrint(
        "UserModel WARNING: Unhandled timestamp type: ${timestamp.runtimeType}");
    return DateTime.fromMillisecondsSinceEpoch(0); // Consistent safe fallback
  }

  static List<String> _getList(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is List) {
      return List<String>.from(value.map((item) => item.toString()));
    }
    return [];
  }

  /// Parse affinity map from Firestore data
  /// Safely converts Map<String, dynamic> to Map<String, double>
  static Map<String, double> _getAffinityMap(Map<String, dynamic> data) {
    final value = data['userAffinities'];
    if (value is Map) {
      return Map<String, double>.from(
        value.map((key, val) => MapEntry(
              key.toString(),
              (val is num) ? val.toDouble() : 1.0,
            )),
      );
    }
    return {};
  }

  // fromDoc remains the same, relies on fromMap
  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(doc.id, data);
  }

  // fromMap updated to remove deleted fields
  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    // Validate photoUrl - ensure it's a valid HTTP/HTTPS URL or empty string
    final rawPhotoUrl = data['photoUrl'] ?? '';
    final photoUrl = (rawPhotoUrl is String &&
            rawPhotoUrl.isNotEmpty &&
            rawPhotoUrl.trim().isNotEmpty &&
            (rawPhotoUrl.startsWith('http://') ||
                rawPhotoUrl.startsWith('https://')))
        ? rawPhotoUrl.trim()
        : '';

    return UserModel(
      id: id,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      photoUrl: photoUrl,
      pictureVersion: data['pictureVersion'] ?? 0,
      bio: data['bio'] ?? '',
      fcmToken: data['fcmToken'] ?? '',
      presence: data['presence'] ?? false,
      lastSeen: _toDateTime(data['lastSeen'], 'lastSeen'),
      country: data['country'] ?? '',
      location: data['location'] is GeoPoint
          ? data['location'] as GeoPoint
          : (data['location'] is Map
              ? GeoPoint(
                  (data['location'] as Map)['latitude'] ?? 0.0,
                  (data['location'] as Map)['longitude'] ?? 0.0,
                )
              : null),
      age: data['age'] ?? 0,
      gender: data['gender'] ?? '',
      interests: _getList(data, 'interests'),
      createdAt: _toDateTime(data['createdAt'], 'createdAt'),
      friends: _getList(data, 'friends'),
      friendRequestsSent: _getList(data, 'friendRequestsSent'),
      friendRequestsReceived: _getList(data, 'friendRequestsReceived'),
      blockedUsers: _getList(data, 'blockedUsers'),
      followedPages: _getList(data, 'followedPages'), // Read from Firestore
      userAffinities: _getAffinityMap(data),
      coins: data['coins'] ?? 0,
      superLikes: data['superLikes'] ?? 1, // Keep
      lastFreeSuperLike:
          _toDateTime(data['lastFreeSuperLike'], 'lastFreeSuperLike'),
      referredBy: data['referredBy'] as String?,

      // Gamification
      lifetimeCoinsSpent: data['lifetimeCoinsSpent'] ?? 0,
      userLevel: data['userLevel'] ?? 1,
      equippedBorderId: data['equippedBorderId'] as String?,
      equippedBadgeId: data['equippedBadgeId'] as String?,
      equippedBadgeUrl: data['equippedBadgeUrl'] as String?,
      totalGiftsReceived: data['totalGiftsReceived'] ?? 0,
      totalGiftsSent: data['totalGiftsSent'] ?? 0,
      uniqueGiftsCollected: data['uniqueGiftsCollected'] ?? 0,
      totalMessagesSent: data['totalMessagesSent'] ?? 0,
      socialPoints: data['socialPoints'] ?? 0,
      lastDailyRewardClaim:
          _toDateTime(data['lastDailyRewardClaim'], 'lastDailyRewardClaim'),
      dailyLoginStreak: data['dailyLoginStreak'] ?? 0,
      // xp: data['xp'] ?? 0, // Removed
      // level: data['level'] ?? 1, // Removed
      // currentSeasonId: data['currentSeasonId'] ?? '', // Removed
      // seasonXp: data['seasonXp'] ?? 0, // Removed
      // seasonLevel: data['seasonLevel'] ?? 0, // Removed
      // claimedSeasonRewards: _getIntList(data, 'claimedSeasonRewards'), // Removed
      // equippedProfileFrameId: data['equippedProfileFrameId'], // Removed
      // equippedBadgeId: data['equippedBadgeId'], // Removed
      nearbyStatusMessage: data['nearbyStatusMessage'] ?? '',
      nearbyStatusEmoji: data['nearbyStatusEmoji'] ?? '',
      nearbyDiscoveryStreak: data['nearbyDiscoveryStreak'] ?? 0,
      lastNearbyDiscoveryDate: _toDateTime(
          data['lastNearbyDiscoveryDate'], 'lastNearbyDiscoveryDate'),
      sharedMusicTrack: data['sharedMusicTrack'] != null
          ? Map<String, String>.from(data['sharedMusicTrack'])
          : null,
      nearbyDataVersion: data['nearbyDataVersion'] ?? 0,
      // uidShort is calculated by the constructor
    );
  }

  // toMap updated to remove deleted fields
  Map<String, dynamic> toMap() {
    return {
      'uidShort': uidShort,
      'username': username,
      'email': email,
      'photoUrl': photoUrl,
      'pictureVersion': pictureVersion,
      'bio': bio,
      'fcmToken': fcmToken,
      'presence': presence,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'country': country,
      'location': location,
      'age': age,
      'gender': gender,
      'interests': interests,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'friends': friends,
      'friendRequestsSent': friendRequestsSent,
      'friendRequestsReceived': friendRequestsReceived,
      'blockedUsers': blockedUsers,
      'followedPages': followedPages, // Write to Firestore
      'userAffinities': userAffinities, // Write to Firestore
      'coins': coins,
      'superLikes': superLikes, // Keep
      'lastFreeSuperLike': lastFreeSuperLike.millisecondsSinceEpoch,
      'referredBy': referredBy,

      // Gamification
      'lifetimeCoinsSpent': lifetimeCoinsSpent,
      'userLevel': userLevel,
      'equippedBorderId': equippedBorderId,
      'equippedBadgeId': equippedBadgeId,
      'equippedBadgeUrl': equippedBadgeUrl,
      'totalGiftsReceived': totalGiftsReceived,
      'totalGiftsSent': totalGiftsSent,
      'uniqueGiftsCollected': uniqueGiftsCollected,
      'totalMessagesSent': totalMessagesSent,
      'socialPoints': socialPoints,
      'lastDailyRewardClaim': lastDailyRewardClaim.millisecondsSinceEpoch,
      'dailyLoginStreak': dailyLoginStreak,
      // 'xp': xp, // Removed
      // 'level': level, // Removed
      // 'currentSeasonId': currentSeasonId, // Removed
      // 'seasonXp': seasonXp, // Removed
      // 'seasonLevel': seasonLevel, // Removed
      // 'claimedSeasonRewards': claimedSeasonRewards, // Removed
      // 'equippedProfileFrameId': equippedProfileFrameId, // Removed
      // 'equippedBadgeId': equippedBadgeId, // Removed
      'nearbyStatusMessage': nearbyStatusMessage,
      'nearbyStatusEmoji': nearbyStatusEmoji,
      'nearbyDiscoveryStreak': nearbyDiscoveryStreak,
      'lastNearbyDiscoveryDate': lastNearbyDiscoveryDate.millisecondsSinceEpoch,
      'sharedMusicTrack': sharedMusicTrack,
      'nearbyDataVersion': nearbyDataVersion,
    };
  }

  // Getter to convert gender string to int (0=unknown, 1=male, 2=female)
  int get genderValue {
    final genderLower = gender.toLowerCase();
    if (genderLower == 'male' || genderLower == 'm') return 1;
    if (genderLower == 'female' || genderLower == 'f') return 2;
    return 0;
  }

  // Getter for userAvatarUrl (alias for photoUrl for consistency)
  String get userAvatarUrl => photoUrl;

  /// Get affinity score for a target (user or page)
  /// Returns 1.0 (neutral) if not found
  double getAffinityFor(String targetId) {
    return userAffinities[targetId] ?? 1.0;
  }

  // Placeholder getters for UI consistency
  int get followersCount => friends.length;
  int get followingCount => friends.length;

  // Gamification Getters
  int get level => userLevel;
  int get experience =>
      lifetimeCoinsSpent - LevelCalculator.getThresholdForLevel(userLevel);
  int get nextLevelExperience =>
      LevelCalculator.getCoinsForNextLevel(userLevel) -
      LevelCalculator.getThresholdForLevel(userLevel);

  // props updated to remove deleted fields, but kept a selection for Equatable comparison
  @override
  List<Object?> get props => [
        id, uidShort, username, email, photoUrl, pictureVersion, bio, presence,
        lastSeen,
        country, location, age, gender, interests, createdAt, friends,
        followedPages, // Added for equality checks
        userAffinities, // Added for ranking algorithm
        superLikes, // Keep superLikes here if important for equality checks
        lastFreeSuperLike, referredBy,
        nearbyStatusMessage, nearbyStatusEmoji, nearbyDiscoveryStreak,
        lastNearbyDiscoveryDate,
        sharedMusicTrack, nearbyDataVersion, coins, // Added coins
        lifetimeCoinsSpent, userLevel, equippedBorderId, equippedBadgeId,
        equippedBadgeUrl,
        totalGiftsReceived, totalGiftsSent, uniqueGiftsCollected,
        totalMessagesSent, socialPoints,
        lastDailyRewardClaim, dailyLoginStreak,
      ];

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? photoUrl,
    int? pictureVersion,
    String? bio,
    String? fcmToken,
    bool? presence,
    DateTime? lastSeen,
    String? country,
    GeoPoint? location,
    int? age,
    String? gender,
    List<String>? interests,
    DateTime? createdAt,
    List<String>? friends,
    List<String>? friendRequestsSent,
    List<String>? friendRequestsReceived,
    List<String>? blockedUsers,
    List<String>? followedPages,
    Map<String, double>? userAffinities,
    int? coins,
    int? superLikes,
    DateTime? lastFreeSuperLike,
    String? referredBy,
    int? lifetimeCoinsSpent,
    int? userLevel,
    String? equippedBorderId,
    String? equippedBadgeId,
    String? equippedBadgeUrl,
    int? totalGiftsReceived,
    int? totalGiftsSent,
    int? uniqueGiftsCollected,
    int? totalMessagesSent,
    int? socialPoints,
    DateTime? lastDailyRewardClaim,
    int? dailyLoginStreak,
    String? nearbyStatusMessage,
    String? nearbyStatusEmoji,
    int? nearbyDiscoveryStreak,
    DateTime? lastNearbyDiscoveryDate,
    Map<String, String>? sharedMusicTrack,
    int? nearbyDataVersion,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      pictureVersion: pictureVersion ?? this.pictureVersion,
      bio: bio ?? this.bio,
      fcmToken: fcmToken ?? this.fcmToken,
      presence: presence ?? this.presence,
      lastSeen: lastSeen ?? this.lastSeen,
      country: country ?? this.country,
      location: location ?? this.location,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      createdAt: createdAt ?? this.createdAt,
      friends: friends ?? this.friends,
      friendRequestsSent: friendRequestsSent ?? this.friendRequestsSent,
      friendRequestsReceived:
          friendRequestsReceived ?? this.friendRequestsReceived,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      followedPages: followedPages ?? this.followedPages,
      userAffinities: userAffinities ?? this.userAffinities,
      coins: coins ?? this.coins,
      superLikes: superLikes ?? this.superLikes,
      lastFreeSuperLike: lastFreeSuperLike ?? this.lastFreeSuperLike,
      referredBy: referredBy ?? this.referredBy,
      lifetimeCoinsSpent: lifetimeCoinsSpent ?? this.lifetimeCoinsSpent,
      userLevel: userLevel ?? this.userLevel,
      equippedBorderId: equippedBorderId ?? this.equippedBorderId,
      equippedBadgeId: equippedBadgeId ?? this.equippedBadgeId,
      equippedBadgeUrl: equippedBadgeUrl ?? this.equippedBadgeUrl,
      totalGiftsReceived: totalGiftsReceived ?? this.totalGiftsReceived,
      totalGiftsSent: totalGiftsSent ?? this.totalGiftsSent,
      uniqueGiftsCollected: uniqueGiftsCollected ?? this.uniqueGiftsCollected,
      totalMessagesSent: totalMessagesSent ?? this.totalMessagesSent,
      socialPoints: socialPoints ?? this.socialPoints,
      lastDailyRewardClaim: lastDailyRewardClaim ?? this.lastDailyRewardClaim,
      dailyLoginStreak: dailyLoginStreak ?? this.dailyLoginStreak,
      nearbyStatusMessage: nearbyStatusMessage ?? this.nearbyStatusMessage,
      nearbyStatusEmoji: nearbyStatusEmoji ?? this.nearbyStatusEmoji,
      nearbyDiscoveryStreak:
          nearbyDiscoveryStreak ?? this.nearbyDiscoveryStreak,
      lastNearbyDiscoveryDate:
          lastNearbyDiscoveryDate ?? this.lastNearbyDiscoveryDate,
      sharedMusicTrack: sharedMusicTrack ?? this.sharedMusicTrack,
      nearbyDataVersion: nearbyDataVersion ?? this.nearbyDataVersion,
    );
  }
}
