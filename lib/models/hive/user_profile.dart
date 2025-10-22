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
  int level;

  @HiveField(5)
  int xp;

  @HiveField(6)
  List<String> interests;

  @HiveField(7)
  List<String> friends; // Store friend IDs for mutual friend check

  @HiveField(8)
  String gender; // Store gender string ('Male', 'Female', 'Other', '')

  @HiveField(9)
  String nearbyStatusMessage;

  @HiveField(10)
  String nearbyStatusEmoji;

  // *** ADDED FIELDS TO FIX ERRORS ***
  @HiveField(11)
  List<String> friendRequestsSent;

  @HiveField(12)
  List<String> friendRequestsReceived;

  @HiveField(13)
  List<String> blockedUsers;
  // --- END NEW FIELDS ---


  UserProfile({
    required this.profileId,
    required this.name,
    required this.photoUrl,
    required this.updatedAt,
    // Add new fields to constructor with defaults
    this.level = 1,
    this.xp = 0,
    this.interests = const [],
    this.friends = const [],
    this.gender = '',
    this.nearbyStatusMessage = '',
    this.nearbyStatusEmoji = '',
    // Add defaults for new fields
    this.friendRequestsSent = const [],
    this.friendRequestsReceived = const [],
    this.blockedUsers = const [],
  });
}