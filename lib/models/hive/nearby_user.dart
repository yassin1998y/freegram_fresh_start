// lib/models/hive/nearby_user.dart
import 'package:hive/hive.dart';

part 'nearby_user.g.dart'; // Hive generator will create this

@HiveType(typeId: 1)
class NearbyUser extends HiveObject {
  @HiveField(0)
  String uidShort; // hex string of uid32

  @HiveField(1)
  int gender; // 0=unknown, 1=male, 2=female

  @HiveField(2)
  double distance; // meters, estimate

  @HiveField(3)
  DateTime lastSeen;

  @HiveField(4)
  DateTime get foundAt =>
      _foundAt ??
      lastSeen; // Use lastSeen if not provided (for old data migration)

  // Internal field to check if foundAt was set
  DateTime? get internalFoundAt => _foundAt;

  DateTime? _foundAt; // when the user was first discovered (for 24h retention)

  @HiveField(5)
  String? profileId; // full user id from server (if known)

  @HiveField(6)
  String? presenceStatus; // e.g. "online", "busy", "offline"

  NearbyUser({
    required this.uidShort,
    required this.gender,
    required this.distance,
    required this.lastSeen,
    DateTime? foundAt,
    this.profileId,
    this.presenceStatus,
  }) : _foundAt = foundAt;

  // Setter for foundAt to allow updates
  set foundAt(DateTime value) {
    _foundAt = value;
  }
}
