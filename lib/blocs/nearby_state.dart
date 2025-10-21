// lib/blocs/nearby_state.dart
part of 'nearby_bloc.dart';

@immutable
abstract class NearbyState extends Equatable {
  const NearbyState();

  @override
  List<Object> get props => [];
}

/// The initial state before Sonar is active or after it's stopped.
class NearbyInitial extends NearbyState {}

/// The state when Sonar services are active (scanning or recently found a user).
class NearbyActive extends NearbyState {
  // Removed foundUserIds - UI will get this from LocalCacheService/Hive
  // final List<String> foundUserIds;
  final NearbyStatus status; // Can be scanning or userFound

  const NearbyActive({required this.status});

  // Updated props
  @override
  List<Object> get props => [status];
}

/// The state when an error occurs (permissions, hardware, other).
class NearbyError extends NearbyState {
  final String message;
  const NearbyError(this.message);

  @override
  List<Object> get props => [message];
}