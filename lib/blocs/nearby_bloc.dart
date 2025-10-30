// lib/blocs/nearby_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart'; // <<<--- ADDED THIS IMPORT for debugPrint
import 'package:freegram/locator.dart'; // To get SonarController
import 'package:freegram/services/sonar/sonar_controller.dart'; // To start/stop
import 'package:meta/meta.dart';
import 'package:freegram/services/sonar/bluetooth_service.dart';

part 'nearby_event.dart';
part 'nearby_state.dart';

class NearbyBloc extends Bloc<NearbyEvent, NearbyState> {
  // Get instances from locator
  final SonarController _sonarController = locator<SonarController>();
  final BluetoothStatusService _statusService =
      BluetoothStatusService(); // Use shared status service
  StreamSubscription? _statusSubscription;

  NearbyBloc() : super(NearbyInitial()) {
    // Removed BluetoothService dependency

    // Listen to the shared status stream
    _statusSubscription = _statusService.statusStream.listen((status) {
      add(_NearbyStatusUpdated(status)); // Internal event to update BLoC state
    });

    // Handle events to start/stop sonar via the controller
    on<StartNearbyServices>(_onStartServices, transformer: droppable());
    on<StopNearbyServices>(_onStopServices, transformer: droppable());

    // Handle internal status updates
    on<_NearbyStatusUpdated>(_onStatusUpdated);

    // Reflect initial status from the service
    add(_NearbyStatusUpdated(_statusService.currentStatus));
  }

  // Calls SonarController to start
  void _onStartServices(
      StartNearbyServices event, Emitter<NearbyState> emit) async {
    debugPrint("NearbyBloc: Received StartNearbyServices event."); // Corrected
    // Initialize user if not already done (controller handles internal check)
    await _sonarController.initializeUser();
    // Start sonar (controller handles permissions and state checks)
    await _sonarController.startSonar();
    // The state will update via the _statusSubscription listening to BluetoothStatusService
  }

  // Calls SonarController to stop
  void _onStopServices(
      StopNearbyServices event, Emitter<NearbyState> emit) async {
    debugPrint("NearbyBloc: Received StopNearbyServices event."); // Corrected
    await _sonarController.stopSonar();
    // The state will update via the _statusSubscription
  }

  // Updates BLoC state based on status from the shared service
  void _onStatusUpdated(_NearbyStatusUpdated event, Emitter<NearbyState> emit) {
    final status = event.status;
    debugPrint("NearbyBloc: Processing status update -> $status"); // Corrected

    switch (status) {
      case NearbyStatus.idle:
        // Only emit initial if the current state isn't already initial
        // This prevents unnecessary rebuilds if stopSonar is called multiple times
        if (state is! NearbyInitial) {
          emit(NearbyInitial());
        }
        break;
      case NearbyStatus.scanning:
      case NearbyStatus
            .userFound: // Combine scanning and found into 'Active' state
        // In the new model, the BLoC doesn't hold the user list directly.
        // The UI will get the list from LocalCacheService via Hive.listenable().
        // We just need to signal that the service is active.
        emit(NearbyActive(status: status));
        break;
      case NearbyStatus.adapterOff:
        emit(const NearbyError("Bluetooth is turned off."));
        break;
      case NearbyStatus.permissionsDenied:
        emit(const NearbyError("Permissions are required for Sonar."));
        break;
      case NearbyStatus.permissionsPermanentlyDenied:
        emit(const NearbyError(
            "Permissions permanently denied. Please enable in Settings."));
        break;
      case NearbyStatus.error:
        emit(const NearbyError("A Sonar error occurred. Please try again."));
        break;
    }
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    // Do NOT dispose SonarController here if it's a singleton managed by GetIt
    debugPrint("NearbyBloc: Closed."); // Corrected
    return super.close();
  }
}
