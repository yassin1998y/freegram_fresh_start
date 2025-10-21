part of 'connectivity_bloc.dart';

abstract class ConnectivityEvent extends Equatable {
  const ConnectivityEvent();

  @override
  List<Object> get props => [];
}

/// Event to trigger an initial connectivity check.
class CheckConnectivity extends ConnectivityEvent {}

/// Internal event triggered by the connectivity stream.
class _ConnectivityChanged extends ConnectivityEvent {
  final ConnectivityResult result;
  const _ConnectivityChanged(this.result);

  @override
  List<Object> get props => [result];
}
