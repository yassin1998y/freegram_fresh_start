// lib/blocs/nearby_event.dart
part of 'nearby_bloc.dart';


@immutable
abstract class NearbyEvent extends Equatable {
  const NearbyEvent();

  @override
  List<Object> get props => [];
}

/// Event to start Sonar services (scanning and advertising).
class StartNearbyServices extends NearbyEvent {}

/// Event to stop Sonar services.
class StopNearbyServices extends NearbyEvent {}

/// Internal event to update the BLoC with a new status from the BluetoothStatusService.
class _NearbyStatusUpdated extends NearbyEvent {
  final NearbyStatus status;
  const _NearbyStatusUpdated(this.status);

  @override
  List<Object> get props => [status];
}
