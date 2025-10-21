// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nearby_message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NearbyMessageAdapter extends TypeAdapter<NearbyMessage> {
  @override
  final int typeId = 0;

  @override
  NearbyMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NearbyMessage(
      id: fields[0] as String,
      chatId: fields[1] as String,
      text: fields[2] as String,
      senderId: fields[3] as String,
      recipientId: fields[4] as String,
      timestamp: fields[5] as DateTime,
      isRead: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, NearbyMessage obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.chatId)
      ..writeByte(2)
      ..write(obj.text)
      ..writeByte(3)
      ..write(obj.senderId)
      ..writeByte(4)
      ..write(obj.recipientId)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.isRead);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
