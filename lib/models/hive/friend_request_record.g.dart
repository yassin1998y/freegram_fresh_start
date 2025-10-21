// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_request_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FriendRequestRecordAdapter extends TypeAdapter<FriendRequestRecord> {
  @override
  final int typeId = 4;

  @override
  FriendRequestRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FriendRequestRecord(
      fromUserId: fields[0] as String,
      toUserId: fields[1] as String,
      timestamp: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FriendRequestRecord obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.fromUserId)
      ..writeByte(1)
      ..write(obj.toUserId)
      ..writeByte(2)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendRequestRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
