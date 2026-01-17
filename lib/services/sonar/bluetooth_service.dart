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
  static final BluetoothStatusService _instance =
      BluetoothStatusService._internal();
  factory BluetoothStatusService() => _instance;

  // --- NEW: Subscription to fbp adapter state ---
  StreamSubscription? _adapterStateSubscription;
  // --- END NEW ---

  final StreamController<NearbyStatus> _statusController =
      StreamController<NearbyStatus>.broadcast();
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
        if (_currentStatus == NearbyStatus.adapterOff ||
            _currentStatus == NearbyStatus.error) {
          updateStatus(NearbyStatus.idle);
        } else if (_currentStatus == NearbyStatus.permissionsDenied ||
            _currentStatus == NearbyStatus.permissionsPermanentlyDenied) {
          // If permissions were the issue, adapter turning on doesn't fix it. Keep perm error status.
        } else {
          // If status was idle/scanning/found, adapter turning on doesn't change the functional status.
          // No update needed unless it was previously OFF.
        }
      } else {
        // If adapter turns OFF or becomes unavailable/unauthorized
        updateStatus(NearbyStatus.adapterOff);
      }
    }, onError: (err) {
      debugPrint(
          "BluetoothStatusService: Error listening to adapter state: $err");
      updateStatus(NearbyStatus.error); // Report error if stream fails
    });
    // Update initial status based on current adapter state
    _updateInitialStatusFromAdapter();
  }

  // *** NEW: Helper to set initial status ***
  Future<void> _updateInitialStatusFromAdapter() async {
    var initialState = fbp.FlutterBluePlus.adapterStateNow;
    debugPrint(
        "BluetoothStatusService: Initial FBP Adapter State -> $initialState");
    if (initialState != fbp.BluetoothAdapterState.on) {
      // Update status immediately if adapter is off initially
      // This overrides the default _currentStatus = NearbyStatus.idle
      updateStatus(NearbyStatus.adapterOff);
    }
  }

  void updateStatus(NearbyStatus newStatus) {
    // Prevent unnecessary state changes and reduce log spam
    if (_currentStatus == newStatus) return;

    // Only log significant state changes, not rapid transitions
    final bool isSignificantChange =
        _isSignificantStatusChange(_currentStatus, newStatus);
    if (isSignificantChange) {
      debugPrint(
          "BluetoothStatusService: Status changing from $_currentStatus -> $newStatus");
    }

    _currentStatus = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    } else {
      debugPrint(
          "BluetoothStatusService Warning: Tried to update status on a closed controller.");
    }
  }

  // Helper method to determine if a status change is significant enough to log
  bool _isSignificantStatusChange(NearbyStatus from, NearbyStatus to) {
    // Always log transitions to/from error states
    if (from == NearbyStatus.error || to == NearbyStatus.error) return true;

    // Always log permission-related changes
    if (from == NearbyStatus.permissionsDenied ||
        from == NearbyStatus.permissionsPermanentlyDenied ||
        to == NearbyStatus.permissionsDenied ||
        to == NearbyStatus.permissionsPermanentlyDenied) {
      return true;
    }

    // Always log adapter on/off changes
    if (from == NearbyStatus.adapterOff || to == NearbyStatus.adapterOff)
      return true;

    // Always log scanning state changes
    if (from == NearbyStatus.scanning || to == NearbyStatus.scanning)
      return true;

    // Always log user found state
    if (to == NearbyStatus.userFound) return true;

    // Don't log idle transitions unless coming from a significant state
    if (to == NearbyStatus.idle &&
        from != NearbyStatus.scanning &&
        from != NearbyStatus.userFound) {
      return false;
    }

    return true; // Default to logging other changes
  }

  void dispose() {
    debugPrint("BluetoothStatusService: Disposing.");
    _adapterStateSubscription?.cancel(); // Cancel adapter listener
    // CRITICAL: Stop scanning to prevent battery drain
    fbp.FlutterBluePlus.stopScan();
    _statusController.close();
  }
}
