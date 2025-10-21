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
  String photoUrl; // Store URL, caching handled separately

  @HiveField(3)
  DateTime updatedAt;

  UserProfile({
    required this.profileId,
    required this.name,
    required this.photoUrl,
    required this.updatedAt,
  });
}
