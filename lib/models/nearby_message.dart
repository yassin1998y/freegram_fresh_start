import 'package:hive/hive.dart';

part 'nearby_message.g.dart';

@HiveType(typeId: 0)
class NearbyMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String chatId;

  @HiveField(2)
  final String text;

  @HiveField(3)
  final String senderId;

  @HiveField(4)
  final String recipientId;

  @HiveField(5)
  final DateTime timestamp;

  @HiveField(6)
  final bool isRead;

  NearbyMessage({
    required this.id,
    required this.chatId,
    required this.text,
    required this.senderId,
    required this.recipientId,
    required this.timestamp,
    this.isRead = false,
  });
}
