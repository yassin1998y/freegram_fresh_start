// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_history_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MatchHistoryModelAdapter extends TypeAdapter<MatchHistoryModel> {
  @override
  final int typeId = 200;

  @override
  MatchHistoryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MatchHistoryModel(
      id: fields[0] as String,
      nickname: fields[1] as String,
      avatarUrl: fields[2] as String,
      timestamp: fields[3] as DateTime,
      durationSeconds: fields[4] as int,
      isFriend: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, MatchHistoryModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nickname)
      ..writeByte(2)
      ..write(obj.avatarUrl)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.durationSeconds)
      ..writeByte(5)
      ..write(obj.isFriend);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchHistoryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
