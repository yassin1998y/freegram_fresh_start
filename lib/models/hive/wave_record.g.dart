// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wave_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WaveRecordAdapter extends TypeAdapter<WaveRecord> {
  @override
  final int typeId = 3;

  @override
  WaveRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WaveRecord(
      fromUidFull: fields[0] as String,
      toUidShort: fields[1] as String,
      timestamp: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, WaveRecord obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.fromUidFull)
      ..writeByte(1)
      ..write(obj.toUidShort)
      ..writeByte(2)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaveRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
