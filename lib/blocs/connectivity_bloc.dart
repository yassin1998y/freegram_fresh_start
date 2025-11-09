import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

part 'connectivity_event.dart';
part 'connectivity_state.dart';

class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  StreamSubscription? _connectivitySubscription;
  Timer? _internetCheckTimer;
  bool _isCheckingInternet = false;

  ConnectivityBloc() : super(ConnectivityInitial()) {
    on<CheckConnectivity>((event, emit) async {
      final result = await Connectivity().checkConnectivity();
      await _updateState(result, emit);
    });

    on<_ConnectivityChanged>((event, emit) async {
      await _updateState(event.result, emit);
    });

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      add(_ConnectivityChanged(result));
    });

    // Periodic internet check every 10 seconds
    _internetCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => add(CheckConnectivity()),
    );
  }

  Future<void> _updateState(
      ConnectivityResult result, Emitter<ConnectivityState> emit) async {
    if (result == ConnectivityResult.none) {
      if (state is! Offline) {
        debugPrint('ConnectivityBloc: No connection detected → Offline');
        emit(Offline());
      }
    } else {
      // Has WiFi/Mobile connection, but verify actual internet access
      final hasInternet = await _checkActualInternetConnectivity();

      if (hasInternet) {
        if (state is! Online) {
          debugPrint('ConnectivityBloc: Internet verified → Online');
          emit(Online());
        }
      } else {
        if (state is! Offline) {
          debugPrint(
              'ConnectivityBloc: Connection exists but no internet access → Offline');
          emit(Offline());
        }
      }
    }
  }

  /// Checks actual internet connectivity by attempting to reach Google DNS
  Future<bool> _checkActualInternetConnectivity() async {
    if (_isCheckingInternet) {
      return state is Online; // Prevent concurrent checks
    }

    _isCheckingInternet = true;
    try {
      // InternetAddress.lookup is not supported on web
      if (kIsWeb) {
        _isCheckingInternet = false;
        // On web, assume online if connectivity check passed
        // (connectivity_plus handles web connectivity differently)
        return true;
      }

      // Try to lookup Google's DNS (very reliable and fast)
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
        onTimeout: () => [],
      );

      _isCheckingInternet = false;

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true; // Internet is accessible
      }
      return false;
    } on SocketException catch (_) {
      _isCheckingInternet = false;
      return false; // No internet access
    } catch (e) {
      _isCheckingInternet = false;
      debugPrint('ConnectivityBloc: Error checking internet: $e');
      return false; // Assume offline on error
    }
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    _internetCheckTimer?.cancel();
    return super.close();
  }
}
