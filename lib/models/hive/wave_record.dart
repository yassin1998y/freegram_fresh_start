// lib/models/hive/wave_record.dart
import 'package:hive/hive.dart';

part 'wave_record.g.dart'; // Hive generator will create this

@HiveType(typeId: 3)
class WaveRecord extends HiveObject {
  @HiveField(0)
  String fromUidFull; // Sender's full User ID

  @HiveField(1)
  String toUidShort; // Target's short ID (as discovered)

  @HiveField(2)
  DateTime timestamp;

  // Removed 'synced' field - we just delete upon successful sync
  // Removed 'received' field - this box is only for *pending outgoing* waves

  WaveRecord({
    required this.fromUidFull,
    required this.toUidShort,
    required this.timestamp,
  });
}
