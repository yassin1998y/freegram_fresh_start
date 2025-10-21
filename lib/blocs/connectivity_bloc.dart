import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';

part 'connectivity_event.dart';
part 'connectivity_state.dart';

class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  StreamSubscription? _connectivitySubscription;

  ConnectivityBloc() : super(ConnectivityInitial()) {
    on<CheckConnectivity>((event, emit) async {
      final result = await Connectivity().checkConnectivity();
      _updateState(result, emit);
    });

    on<_ConnectivityChanged>((event, emit) {
      _updateState(event.result, emit);
    });

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      add(_ConnectivityChanged(result));
    });
  }

  void _updateState(ConnectivityResult result, Emitter<ConnectivityState> emit) {
    if (result == ConnectivityResult.none) {
      if (state is! Offline) {
        emit(Offline());
      }
    } else {
      if (state is! Online) {
        emit(Online());
      }
    }
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
