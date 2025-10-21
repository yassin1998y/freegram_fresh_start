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

  // No longer needed per final plan review - profileId covers sync status
  // @HiveField(4)
  // bool synced; // profile synced?

  @HiveField(4) // Adjusted index due to removal above
  String? profileId; // full user id from server (if known)

  NearbyUser({
    required this.uidShort,
    required this.gender,
    required this.distance,
    required this.lastSeen,
    this.profileId,
  });
}
