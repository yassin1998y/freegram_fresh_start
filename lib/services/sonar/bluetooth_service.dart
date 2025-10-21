// lib/services/sonar/bluetooth_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
// *** ADD flutter_blue_plus import ***
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

enum NearbyStatus {
  idle,
  scanning,
  userFound,
  permissionsDenied,
  permissionsPermanentlyDenied,
  adapterOff,
  error,
}

class BluetoothStatusService {
  static final BluetoothStatusService _instance = BluetoothStatusService._internal();
  factory BluetoothStatusService() => _instance;

  // --- NEW: Subscription to fbp adapter state ---
  StreamSubscription? _adapterStateSubscription;
  // --- END NEW ---

  final StreamController<NearbyStatus> _statusController = StreamController<NearbyStatus>.broadcast();
  Stream<NearbyStatus> get statusStream => _statusController.stream;
  NearbyStatus _currentStatus = NearbyStatus.idle;
  NearbyStatus get currentStatus => _currentStatus;

  // Private constructor
  BluetoothStatusService._internal() {
    // *** NEW: Listen to adapter state on creation ***
    _listenToAdapterState();
  }

  // *** NEW: Method to handle adapter state changes ***
  void _listenToAdapterState() {
    _adapterStateSubscription?.cancel(); // Cancel previous if exists
    _adapterStateSubscription = fbp.FlutterBluePlus.adapterState.listen(
            (fbp.BluetoothAdapterState state) {
          debugPrint("BluetoothStatusService: FBP Adapter State Changed -> $state");
          if (state == fbp.BluetoothAdapterState.on) {
            // If the adapter turns ON, and we were previously in an 'off' or 'error' state,
            // revert to 'idle' to allow starting again.
            // Don't override 'scanning' or 'userFound'.
            if (_currentStatus == NearbyStatus.adapterOff || _currentStatus == NearbyStatus.error) {
              updateStatus(NearbyStatus.idle);
            } else if (_currentStatus == NearbyStatus.permissionsDenied || _currentStatus == NearbyStatus.permissionsPermanentlyDenied) {
              // If permissions were the issue, adapter turning on doesn't fix it. Keep perm error status.
            } else {
              // If status was idle/scanning/found, adapter turning on doesn't change the functional status.
              // No update needed unless it was previously OFF.
            }
          } else {
            // If adapter turns OFF or becomes unavailable/unauthorized
            updateStatus(NearbyStatus.adapterOff);
          }
        },
        onError: (err) {
          debugPrint("BluetoothStatusService: Error listening to adapter state: $err");
          updateStatus(NearbyStatus.error); // Report error if stream fails
        }
    );
    // Update initial status based on current adapter state
    _updateInitialStatusFromAdapter();
  }

  // *** NEW: Helper to set initial status ***
  Future<void> _updateInitialStatusFromAdapter() async {
    var initialState = fbp.FlutterBluePlus.adapterStateNow;
    debugPrint("BluetoothStatusService: Initial FBP Adapter State -> $initialState");
    if (initialState != fbp.BluetoothAdapterState.on) {
      // Update status immediately if adapter is off initially
      // This overrides the default _currentStatus = NearbyStatus.idle
      updateStatus(NearbyStatus.adapterOff);
    }
  }


  void updateStatus(NearbyStatus newStatus) {
    if (_currentStatus == newStatus && newStatus != NearbyStatus.userFound) return;
    debugPrint("BluetoothStatusService: Status changing from $_currentStatus -> $newStatus");
    _currentStatus = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    } else {
      debugPrint("BluetoothStatusService Warning: Tried to update status on a closed controller.");
    }
  }

  void dispose() {
    debugPrint("BluetoothStatusService: Disposing.");
    _adapterStateSubscription?.cancel(); // Cancel adapter listener
    _statusController.close();
  }
}