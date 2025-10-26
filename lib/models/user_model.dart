// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

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
  final int age;
  final String gender;
  final List<String> interests;
  final DateTime createdAt;
  final List<String> friends;
  final List<String> friendRequestsSent;
  final List<String> friendRequestsReceived;
  final List<String> blockedUsers;
  final int coins;
  final int superLikes; // Keep this field
  final DateTime lastFreeSuperLike;
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
    this.age = 0,
    this.gender = '',
    this.interests = const [],
    required this.createdAt,
    this.friends = const [],
    this.friendRequestsSent = const [],
    this.friendRequestsReceived = const [],
    this.blockedUsers = const [],
    this.coins = 0,
    this.superLikes = 1, // Keep
    required this.lastFreeSuperLike,
    // Remove fields from constructor
    this.nearbyStatusMessage = '',
    this.nearbyStatusEmoji = '',
    this.nearbyDiscoveryStreak = 0,
    required this.lastNearbyDiscoveryDate,
    this.sharedMusicTrack,
    this.nearbyDataVersion = 0,
  }) : uidShort = _uidShortFromFull(id);


  // _toDateTime, _getList, _getIntList remain the same
  static DateTime _toDateTime(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) return DateTime.tryParse(timestamp) ?? DateTime.fromMillisecondsSinceEpoch(0); // Safer fallback
    if (timestamp is int) {
      if (timestamp > 1000000000000) { // Milliseconds
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else { // Seconds
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
    }
    if (timestamp is Map && timestamp.containsKey('_seconds')) {
      return Timestamp(timestamp['_seconds'], timestamp['_nanoseconds'] ?? 0).toDate();
    }
    print("UserModel WARNING: Unhandled timestamp type: ${timestamp?.runtimeType}");
    return DateTime.fromMillisecondsSinceEpoch(0); // Consistent safe fallback
  }

  static List<String> _getList(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is List) return List<String>.from(value.map((item) => item.toString()));
    return [];
  }
  static List<int> _getIntList(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is List) return List<int>.from(value.map((item) => int.tryParse(item.toString()) ?? 0));
    return [];
  }

  // fromDoc remains the same, relies on fromMap
  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(doc.id, data);
  }

  // fromMap updated to remove deleted fields
  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    return UserModel(
      id: id,
      username: data['username'] ?? 'Anonymous',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      pictureVersion: data['pictureVersion'] ?? 0,
      bio: data['bio'] ?? '',
      fcmToken: data['fcmToken'] ?? '',
      presence: data['presence'] ?? false,
      lastSeen: _toDateTime(data['lastSeen']),
      country: data['country'] ?? '',
      age: data['age'] ?? 0,
      gender: data['gender'] ?? '',
      interests: _getList(data, 'interests'),
      createdAt: _toDateTime(data['createdAt']),
      friends: _getList(data, 'friends'),
      friendRequestsSent: _getList(data, 'friendRequestsSent'),
      friendRequestsReceived: _getList(data, 'friendRequestsReceived'),
      blockedUsers: _getList(data, 'blockedUsers'),
      coins: data['coins'] ?? 0,
      superLikes: data['superLikes'] ?? 1, // Keep
      lastFreeSuperLike: _toDateTime(data['lastFreeSuperLike']),
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
      lastNearbyDiscoveryDate: _toDateTime(data['lastNearbyDiscoveryDate']),
      sharedMusicTrack: data['sharedMusicTrack'] != null ? Map<String, String>.from(data['sharedMusicTrack']) : null,
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
      'age': age,
      'gender': gender,
      'interests': interests,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'friends': friends,
      'friendRequestsSent': friendRequestsSent,
      'friendRequestsReceived': friendRequestsReceived,
      'blockedUsers': blockedUsers,
      'coins': coins,
      'superLikes': superLikes, // Keep
      'lastFreeSuperLike': lastFreeSuperLike.millisecondsSinceEpoch,
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

  // props updated to remove deleted fields, but kept a selection for Equatable comparison
  @override
  List<Object?> get props => [
    id, uidShort, username, email, photoUrl, pictureVersion, bio, presence, lastSeen,
    country, age, gender, interests, createdAt, friends, superLikes, // Keep superLikes here if important for equality checks
    nearbyStatusMessage, nearbyStatusEmoji, nearbyDiscoveryStreak, lastNearbyDiscoveryDate,
    sharedMusicTrack, nearbyDataVersion, coins, // Added coins
    // Removed: level
  ];
}