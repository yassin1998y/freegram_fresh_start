part of 'connectivity_bloc.dart';

abstract class ConnectivityState extends Equatable {
  const ConnectivityState();

  @override
  List<Object> get props => [];
}

/// The initial state before the first connectivity check.
class ConnectivityInitial extends ConnectivityState {}

/// The state when the device has an active internet connection.
class Online extends ConnectivityState {}

/// The state when the device has no active internet connection.
class Offline extends ConnectivityState {}
