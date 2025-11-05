part of 'profile_bloc.dart';

@immutable
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Event to update a user's profile data and optionally their profile image.
class ProfileUpdateEvent extends ProfileEvent {
  final String userId;
  final Map<String, dynamic> updatedData;
  final XFile? imageFile;

  const ProfileUpdateEvent({
    required this.userId,
    required this.updatedData,
    this.imageFile,
  });

  @override
  List<Object?> get props => [userId, updatedData, imageFile];
}

/// Event to track image upload progress.
class ProfileImageUploadProgressEvent extends ProfileEvent {
  final double progress;

  const ProfileImageUploadProgressEvent({required this.progress});

  @override
  List<Object?> get props => [progress];
}

/// Event to upload an image only (without updating full profile).
class ProfileImageUploadOnlyEvent extends ProfileEvent {
  final String userId;
  final XFile imageFile;

  const ProfileImageUploadOnlyEvent({
    required this.userId,
    required this.imageFile,
  });

  @override
  List<Object?> get props => [userId, imageFile];
}
