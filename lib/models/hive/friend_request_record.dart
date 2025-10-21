// lib/models/hive/friend_request_record.dart
import 'package:hive/hive.dart';

part 'friend_request_record.g.dart'; // Hive generator will create this

@HiveType(typeId: 4)
class FriendRequestRecord extends HiveObject {
  @HiveField(0)
  String fromUserId; // Sender's full user ID

  @HiveField(1)
  String toUserId; // Target's full user ID (must be resolved before queuing)

  @HiveField(2)
  DateTime timestamp;

  // Removed 'synced' field - we delete upon successful sync

  FriendRequestRecord({
    required this.fromUserId,
    required this.toUserId,
    required this.timestamp,
  });
}
