// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nearby_user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NearbyUserAdapter extends TypeAdapter<NearbyUser> {
  @override
  final int typeId = 1;

  @override
  NearbyUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NearbyUser(
      uidShort: fields[0] as String,
      gender: fields[1] as int,
      distance: fields[2] as double,
      lastSeen: fields[3] as DateTime,
      foundAt: fields[4] as DateTime?,
      profileId: fields[5] as String?,
      presenceStatus: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, NearbyUser obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.uidShort)
      ..writeByte(1)
      ..write(obj.gender)
      ..writeByte(2)
      ..write(obj.distance)
      ..writeByte(3)
      ..write(obj.lastSeen)
      ..writeByte(5)
      ..write(obj.profileId)
      ..writeByte(6)
      ..write(obj.presenceStatus)
      ..writeByte(4)
      ..write(obj.foundAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyUserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
