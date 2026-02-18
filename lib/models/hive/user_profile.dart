// lib/models/hive/user_profile.dart
import 'package:hive/hive.dart';

part 'user_profile.g.dart'; // Hive generator will create this

@HiveType(typeId: 2)
class UserProfile extends HiveObject {
  @HiveField(0)
  String profileId; // server UUID (matches NearbyUser.profileId)

  @HiveField(1)
  String name;

  @HiveField(2)
  String photoUrl;

  @HiveField(3)
  DateTime updatedAt;

  // --- NEW FIELDS added for caching ---
  @HiveField(4)
  int? level;

  @HiveField(5)
  int? xp;

  @HiveField(6)
  List<String>? interests;

  @HiveField(7)
  List<String>? friends; // Store friend IDs for mutual friend check

  @HiveField(8)
  String? gender; // Store gender string ('Male', 'Female', 'Other', '')

  @HiveField(9)
  String? nearbyStatusMessage;

  @HiveField(10)
  String? nearbyStatusEmoji;

  // *** ADDED FIELDS TO FIX ERRORS ***
  @HiveField(11)
  List<String>? friendRequestsSent;

  @HiveField(12)
  List<String>? friendRequestsReceived;

  @HiveField(13)
  List<String>? blockedUsers;

  @HiveField(14)
  String? equippedBadgeUrl;

  @HiveField(15)
  Map? privacySettings;
  // --- END NEW FIELDS ---

  UserProfile({
    required this.profileId,
    required this.name,
    required this.photoUrl,
    required this.updatedAt,
    // Add new fields to constructor with defaults
    int? level,
    int? xp,
    List<String>? interests,
    List<String>? friends,
    String? gender,
    String? nearbyStatusMessage,
    String? nearbyStatusEmoji,
    List<String>? friendRequestsSent,
    List<String>? friendRequestsReceived,
    List<String>? blockedUsers,
    this.equippedBadgeUrl,
    Map? privacySettings,
  })  : level = level ?? 1,
        xp = xp ?? 0,
        interests = interests ?? const [],
        friends = friends ?? const [],
        gender = gender ?? '',
        nearbyStatusMessage = nearbyStatusMessage ?? '',
        nearbyStatusEmoji = nearbyStatusEmoji ?? '',
        friendRequestsSent = friendRequestsSent ?? const [],
        friendRequestsReceived = friendRequestsReceived ?? const [],
        blockedUsers = blockedUsers ?? const [],
        privacySettings = privacySettings ?? const {};
}
