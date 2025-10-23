// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
// ** NEW IMPORT **
import 'dart:convert';
import 'package:crypto/crypto.dart';

// ** NEW HELPER FUNCTION **
String _uidShortFromFull(String fullId) {
  if (fullId.isEmpty) return '';
  final bytes = utf8.encode(fullId);
  final digest = sha256.convert(bytes);
  // Return the first 8 characters (4 bytes) of the hex digest
  return digest.toString().substring(0, 8);
}


class UserModel extends Equatable {
  final String id;
  // ** NEW FIELD **
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
  final int superLikes;
  final DateTime lastFreeSuperLike;
  final String? equippedProfileFrameId;
  final String? equippedBadgeId;
  final int xp;
  final int level;
  final String currentSeasonId;
  final int seasonXp;
  final int seasonLevel;
  final List<int> claimedSeasonRewards;
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
    this.superLikes = 1,
    required this.lastFreeSuperLike,
    this.xp = 0,
    this.level = 1,
    this.currentSeasonId = '',
    this.seasonXp = 0,
    this.seasonLevel = 0,
    this.claimedSeasonRewards = const [],
    this.equippedProfileFrameId,
    this.equippedBadgeId,
    this.nearbyStatusMessage = '',
    this.nearbyStatusEmoji = '',
    this.nearbyDiscoveryStreak = 0,
    required this.lastNearbyDiscoveryDate,
    this.sharedMusicTrack,
    this.nearbyDataVersion = 0,
  }) : uidShort = _uidShortFromFull(id); // Calculate uidShort in constructor


  static DateTime _toDateTime(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) return DateTime.tryParse(timestamp) ?? DateTime.now();
    // Handle milliseconds or seconds since epoch
    if (timestamp is int) {
      if (timestamp > 1000000000000) { // Likely milliseconds
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else { // Likely seconds
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
    }
    // Fallback or handle based on Map representation if needed
    if (timestamp is Map && timestamp.containsKey('_seconds')) {
      return Timestamp(timestamp['_seconds'], timestamp['_nanoseconds'] ?? 0).toDate();
    }
    print("UserModel WARNING: Unhandled timestamp type: ${timestamp?.runtimeType}");
    return DateTime.fromMillisecondsSinceEpoch(0);
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

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(doc.id, data);
  }

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
      superLikes: data['superLikes'] ?? 1,
      lastFreeSuperLike: _toDateTime(data['lastFreeSuperLike']),
      xp: data['xp'] ?? 0,
      level: data['level'] ?? 1,
      currentSeasonId: data['currentSeasonId'] ?? '',
      seasonXp: data['seasonXp'] ?? 0,
      seasonLevel: data['seasonLevel'] ?? 0,
      claimedSeasonRewards: _getIntList(data, 'claimedSeasonRewards'),
      equippedProfileFrameId: data['equippedProfileFrameId'],
      equippedBadgeId: data['equippedBadgeId'],
      nearbyStatusMessage: data['nearbyStatusMessage'] ?? '',
      nearbyStatusEmoji: data['nearbyStatusEmoji'] ?? '',
      nearbyDiscoveryStreak: data['nearbyDiscoveryStreak'] ?? 0,
      lastNearbyDiscoveryDate: _toDateTime(data['lastNearbyDiscoveryDate']),
      sharedMusicTrack: data['sharedMusicTrack'] != null ? Map<String, String>.from(data['sharedMusicTrack']) : null,
      nearbyDataVersion: data['nearbyDataVersion'] ?? 0,
      // uidShort is calculated by the constructor
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // ** NEW FIELD ADDED **
      'uidShort': uidShort,
      'username': username,
      'email': email,
      'photoUrl': photoUrl,
      'pictureVersion': pictureVersion,
      'bio': bio,
      'fcmToken': fcmToken,
      'presence': presence,
      // Store timestamps as milliseconds for consistency
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
      'superLikes': superLikes,
      'lastFreeSuperLike': lastFreeSuperLike.millisecondsSinceEpoch,
      'xp': xp,
      'level': level,
      'currentSeasonId': currentSeasonId,
      'seasonXp': seasonXp,
      'seasonLevel': seasonLevel,
      'claimedSeasonRewards': claimedSeasonRewards,
      'equippedProfileFrameId': equippedProfileFrameId,
      'equippedBadgeId': equippedBadgeId,
      'nearbyStatusMessage': nearbyStatusMessage,
      'nearbyStatusEmoji': nearbyStatusEmoji,
      'nearbyDiscoveryStreak': nearbyDiscoveryStreak,
      'lastNearbyDiscoveryDate': lastNearbyDiscoveryDate.millisecondsSinceEpoch,
      'sharedMusicTrack': sharedMusicTrack,
      'nearbyDataVersion': nearbyDataVersion,
    };
  }

  // Adjusted props to include uidShort
  @override
  List<Object?> get props => [id, uidShort, username, email, photoUrl, pictureVersion, bio, presence, lastSeen, country, age, gender, interests, createdAt, friends, level, nearbyStatusMessage];
}