// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 2;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      profileId: fields[0] as String,
      name: fields[1] as String,
      photoUrl: fields[2] as String,
      updatedAt: fields[3] as DateTime,
      level: fields[4] as int?,
      xp: fields[5] as int?,
      interests: (fields[6] as List?)?.cast<String>(),
      friends: (fields[7] as List?)?.cast<String>(),
      gender: fields[8] as String?,
      nearbyStatusMessage: fields[9] as String?,
      nearbyStatusEmoji: fields[10] as String?,
      friendRequestsSent: (fields[11] as List?)?.cast<String>(),
      friendRequestsReceived: (fields[12] as List?)?.cast<String>(),
      blockedUsers: (fields[13] as List?)?.cast<String>(),
      equippedBadgeUrl: fields[14] as String?,
      privacySettings: (fields[15] as Map?)?.cast<dynamic, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.profileId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.photoUrl)
      ..writeByte(3)
      ..write(obj.updatedAt)
      ..writeByte(4)
      ..write(obj.level)
      ..writeByte(5)
      ..write(obj.xp)
      ..writeByte(6)
      ..write(obj.interests)
      ..writeByte(7)
      ..write(obj.friends)
      ..writeByte(8)
      ..write(obj.gender)
      ..writeByte(9)
      ..write(obj.nearbyStatusMessage)
      ..writeByte(10)
      ..write(obj.nearbyStatusEmoji)
      ..writeByte(11)
      ..write(obj.friendRequestsSent)
      ..writeByte(12)
      ..write(obj.friendRequestsReceived)
      ..writeByte(13)
      ..write(obj.blockedUsers)
      ..writeByte(14)
      ..write(obj.equippedBadgeUrl)
      ..writeByte(15)
      ..write(obj.privacySettings);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
