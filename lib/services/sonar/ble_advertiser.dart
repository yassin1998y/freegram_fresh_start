// lib/services/sonar/ble_advertiser.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
// Correct import for advertising
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
// Import for status service and UUID
import 'package:freegram/services/sonar/bluetooth_discovery_service.dart';
import 'package:freegram/services/sonar/bluetooth_service.dart';

class BleAdvertiser {
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  final BluetoothStatusService _statusService = BluetoothStatusService();
  bool _isAdvertising = false;
  Timer? _waveTimer;

  // Define Manufacturer IDs
  static const int MANUFACTURER_ID_DISCOVERY = 0xFFFA;
  static const int MANUFACTURER_ID_WAVE = 0xFFFB;

  // Helper function to convert uidShort hex string to bytes
  Uint8List _uidShortToBytes(String uidShort) {
    if (uidShort.length != 8) {
      throw ArgumentError('uidShort must be an 8-character hex string');
    }
    List<int> bytes = [];
    for (int i = 0; i < uidShort.length; i += 2) {
      String hexPair = uidShort.substring(i, i + 2);
      bytes.add(int.parse(hexPair, radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  /// Checks if the Bluetooth adapter is enabled.
  Future<bool> _isAdapterEnabled() async {
    // flutter_ble_peripheral doesn't have a direct 'isEnabled' check like flutter_blue_plus.
    // We infer it by checking the advertising state or platform-specific checks if needed.
    // A simple check is to see if we *can* start advertising.
    // More robustly, you might need platform channels or another package
    // like flutter_blue_plus just for the adapter state if this isn't sufficient.
    try {
      // isAdvertising getter might implicitly check adapter state on some platforms
      bool advertising = await _peripheral.isAdvertising;
      // If we need a more direct check, consider adding flutter_blue_plus just for adapter state
      // or using a platform channel. For now, we rely on start success/failure.
      return true; // Assume enabled if no immediate error, start will confirm
    } catch (e) {
      debugPrint("BLE Advertiser: Error checking adapter state (assuming off): $e");
      return false; // Assume disabled if check fails
    }
  }


  Future<void> startAdvertising(String uidShort, int gender) async {
    bool isAdapterOn = await _isAdapterEnabled();
    if (_isAdvertising || !isAdapterOn) {
      if (!isAdapterOn) _statusService.updateStatus(NearbyStatus.adapterOff);
      debugPrint("BLE Advertiser: Cannot start advertising. IsAdvertising: $_isAdvertising, AdapterOn: $isAdapterOn");
      return;
    }

    try {
      Uint8List uidBytes = _uidShortToBytes(uidShort);
      Uint8List payload = Uint8List.fromList([...uidBytes, gender & 0xFF]);

      // Use AdvertiseData from flutter_ble_peripheral
      final advData = AdvertiseData(
        // Use the string representation for serviceUuid
        serviceUuid: BluetoothDiscoveryService.DISCOVERY_SERVICE_UUID.toString(),
        // Note: includeDeviceName is often controlled by platform-specific settings or defaults
        // includeDeviceName: false, // May not be directly settable here
        manufacturerId: MANUFACTURER_ID_DISCOVERY,
        manufacturerData: payload,
        // Optional platform-specific settings if available in the plugin version:
        // Ex: For Android (check actual plugin API):
        // advertiseMode: AdvertiseMode.lowLatency,
        // txPowerLevel: AdvertiseTxPowerLevel.medium,
        // connectable: false,
        // timeout: 0, // Advertise indefinitely
      );

      debugPrint("BLE Advertiser: Attempting to start discovery advertising...");
      await _peripheral.start(advertiseData: advData);

      _isAdvertising = true;
      debugPrint("BLE Advertiser: Started Discovery Advertising successfully.");

    } catch (e) {
      debugPrint("BLE Advertiser: Error starting discovery advertising: $e");
      _statusService.updateStatus(NearbyStatus.error);
      _isAdvertising = false;
    }
  }

  Future<void> sendWaveBroadcast(String senderUidShort) async {
    bool isAdapterOn = await _isAdapterEnabled();
    if (!isAdapterOn) {
      debugPrint("BLE Advertiser: Cannot send wave, adapter off.");
      _statusService.updateStatus(NearbyStatus.adapterOff);
      return;
    }

    bool wasAdvertisingDiscovery = _isAdvertising;
    // Check if *any* advertising is active, could be a previous wave too
    bool isCurrentlyAdvertising = await _peripheral.isAdvertising;

    // Stop current advertising *before* starting the wave
    if (isCurrentlyAdvertising) {
      debugPrint("BLE Advertiser: Stopping current advertising before sending wave...");
      await stopAdvertising(temporary: true); // Mark as temporary stop
      // Allow a brief moment for the stop command to process
      await Future.delayed(const Duration(milliseconds: 300));
    }


    try {
      Uint8List uidBytes = _uidShortToBytes(senderUidShort);
      Uint8List payload = uidBytes; // Wave payload is just sender's short ID

      final waveAdvData = AdvertiseData(
        serviceUuid: BluetoothDiscoveryService.DISCOVERY_SERVICE_UUID.toString(),
        manufacturerId: MANUFACTURER_ID_WAVE,
        manufacturerData: payload,
        // Optional: Attempt higher power settings if supported
        // txPowerLevel: AdvertiseTxPowerLevel.high,
        // advertiseMode: AdvertiseMode.lowLatency,
      );

      debugPrint("BLE Advertiser: Sending Wave Broadcast for 3 seconds...");
      // Start wave advertising
      await _peripheral.start(advertiseData: waveAdvData);

      // Use a timer to stop the wave advertisement after 3 seconds
      _waveTimer?.cancel();
      _waveTimer = Timer(const Duration(seconds: 3), () async {
        debugPrint("BLE Advertiser: Stopping Wave Broadcast (Timer).");
        try {
          // Check if still advertising before stopping
          if(await _peripheral.isAdvertising) {
            // Check if it's still the WAVE ad? Hard to tell, stop anyway.
            await _peripheral.stop();
            debugPrint("BLE Advertiser: Wave advertisement stopped via timer.");
          } else {
            debugPrint("BLE Advertiser: Wave advertisement already stopped before timer fired.");
          }
        } catch(e) { debugPrint("BLE Advertiser: Error stopping wave ad via timer: $e");}

        // Restart regular discovery advertising *if* it was running before
        if (wasAdvertisingDiscovery) {
          debugPrint("BLE Advertiser: Attempting to restart regular advertising after wave.");
          // Mark internal state false so startAdvertising can proceed
          _isAdvertising = false;
          // NOTE: Requires gender again. Fetch or store it. For simplicity,
          // we assume SonarController might re-trigger startAdvertising if needed.
          // Or pass required data for restart.
        } else {
          _isAdvertising = false; // Ensure state is consistent if nothing needs restart
        }
      });

    } catch (e) {
      debugPrint("BLE Advertiser: Error sending wave broadcast: $e");
      _statusService.updateStatus(NearbyStatus.error);
      // Ensure state is reset and attempt restart if needed
      _isAdvertising = false;
      if (wasAdvertisingDiscovery) {
        debugPrint("BLE Advertiser: Attempting to restart regular advertising after wave failure.");
        // Restart logic might be external
      }
    }
  }


  Future<void> stopAdvertising({bool temporary = false}) async {
    _waveTimer?.cancel(); // Always cancel wave timer on any stop request

    bool isCurrentlyAdvertising;
    try {
      isCurrentlyAdvertising = await _peripheral.isAdvertising;
    } catch (e) {
      debugPrint("BLE Advertiser: Error checking advertising state during stop: $e. Assuming not advertising.");
      isCurrentlyAdvertising = false; // Assume not advertising if check fails
    }


    if (!isCurrentlyAdvertising) {
      // If peripheral says not advertising, ensure internal state matches
      if (_isAdvertising) {
        debugPrint("BLE Advertiser: Was marked as advertising but peripheral says stopped.");
        _isAdvertising = false;
      }
      if (!temporary) {
        debugPrint("BLE Advertiser: Stop requested but already stopped.");
      }
      return; // Nothing to stop
    }

    // If it is advertising, try to stop it
    try {
      debugPrint("BLE Advertiser: Attempting to stop advertising...");
      await _peripheral.stop();
      if (!temporary) {
        _isAdvertising = false;
        debugPrint("BLE Advertiser: Stopped Advertising successfully.");
      } else {
        debugPrint("BLE Advertiser: Temporarily stopped Advertising for Wave.");
        // Keep _isAdvertising potentially true if temporary, expecting restart
        // Or manage restart externally
      }
    } catch (e) {
      // Log error, but assume stopped anyway to prevent inconsistent state
      debugPrint("BLE Advertiser: Error stopping advertising: $e");
      _isAdvertising = false; // Assume stopped even on error
      // Don't set global error status just for stopping failure
    }
  }

  void dispose() {
    stopAdvertising();
  }
}