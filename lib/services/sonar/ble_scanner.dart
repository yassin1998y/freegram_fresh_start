// lib/services/sonar/ble_scanner.dart
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp; // Keep fbp for scanning
import 'ble_advertiser.dart';
import 'bluetooth_service.dart'; // Import corrected bluetooth_service.dart
import 'bluetooth_discovery_service.dart';

typedef UserDetectedCallback = void Function(String uidShort, int gender, double distance);

class BleScanner {
  final BluetoothStatusService _statusService = BluetoothStatusService();
  StreamSubscription? _scanSubscription;
  StreamSubscription? _scanningStateSubscription;
  bool _isScanning = false;

  UserDetectedCallback? onUserDetected;

  final StreamController<String> _waveReceivedController = StreamController<String>.broadcast();
  Stream<String> get waveReceivedStream => _waveReceivedController.stream;

  final Map<String, DateTime> _lastDiscoveryTime = {};
  final Map<String, DateTime> _lastWaveTime = {};
  final Duration _debounceDuration = const Duration(seconds: 2);
  final Duration _waveDebounceDuration = const Duration(seconds: 5);

  BleScanner({this.onUserDetected});

  double estimateDistance(int rssi, {int txPower = -59}) {
    // ... (implementation remains the same)
    if (rssi == 0) return double.infinity;
    double ratio = rssi * 1.0 / txPower;
    if (ratio < 1.0) return pow(ratio, 10).toDouble();
    return (0.89976) * pow(ratio, 7.7095) + 0.111;
  }

  String _bytesToUidShort(List<int> bytes) {
    // ... (implementation remains the same)
    if (bytes.length < 4) throw ArgumentError('Byte list must contain at least 4 bytes for uidShort');
    return bytes.sublist(0, 4).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }


  Future<void> startScan() async {
    // Rely on BluetoothStatusService for adapter state check
    if (_statusService.currentStatus == NearbyStatus.adapterOff) {
      debugPrint("BLE Scanner: Cannot start scan. Adapter is reported OFF.");
      return; // Exit if adapter is off
    }
    if (_isScanning) {
      debugPrint("BLE Scanner: Already scanning.");
      return;
    }

    try {
      _scanningStateSubscription?.cancel();
      _scanningStateSubscription = fbp.FlutterBluePlus.isScanning.listen((scanning) {
        _isScanning = scanning;
        if (scanning) {
          // Only update if not already scanning or finding users
          if(_statusService.currentStatus != NearbyStatus.scanning && _statusService.currentStatus != NearbyStatus.userFound) {
            _statusService.updateStatus(NearbyStatus.scanning);
          }
          debugPrint("BLE Scanner: Scan reported as active.");
        } else {
          // If scanning stops unexpectedly (not via stopScan method)
          if (_statusService.currentStatus == NearbyStatus.scanning || _statusService.currentStatus == NearbyStatus.userFound) {
            _statusService.updateStatus(NearbyStatus.idle);
            debugPrint("BLE Scanner: Scan stopped unexpectedly or completed.");
          }
          // Always reset the scanning flag when scan stops
          _isScanning = false;
        }
      });

      _scanSubscription?.cancel();
      _scanSubscription = fbp.FlutterBluePlus.scanResults.listen(
          _handleScanResult,
          onError: (error) {
            debugPrint("BLE Scanner: ScanResults stream error: $error");
            _statusService.updateStatus(NearbyStatus.error);
            stopScan();
          });

      debugPrint("BLE Scanner: Attempting to start scan...");
      // Start the scan using flutter_blue_plus with more aggressive settings
      await fbp.FlutterBluePlus.startScan(
        withServices: [BluetoothDiscoveryService.DISCOVERY_SERVICE_UUID],
        androidScanMode: fbp.AndroidScanMode.lowLatency,
        // Add timeout for more aggressive scanning
        timeout: const Duration(seconds: 30),
      );
      // Status update is handled by the isScanning listener now

    } catch (e) {
      debugPrint("BLE Scanner: Error starting scan: $e");
      // Check if the error indicates adapter is off AFTER the attempt
      if (e.toString().toLowerCase().contains("bluetooth adapter is off")) {
        _statusService.updateStatus(NearbyStatus.adapterOff);
      } else {
        _statusService.updateStatus(NearbyStatus.error);
      }
      _isScanning = false;
      _scanSubscription?.cancel();
      _scanningStateSubscription?.cancel();
    }
  }

  void _handleScanResult(List<fbp.ScanResult> results) {
    DateTime now = DateTime.now();
    debugPrint("BLE Scanner: Processing ${results.length} scan results");
    
    for (fbp.ScanResult r in results) {
      final manufData = r.advertisementData.manufacturerData;
      debugPrint("BLE Scanner: Processing device ${r.device.remoteId} with manufacturer data: $manufData");
      
      // Process discovery advertisements (both standard and Xiaomi alternative)
      if (manufData.containsKey(BleAdvertiser.MANUFACTURER_ID_DISCOVERY)) {
        final payload = manufData[BleAdvertiser.MANUFACTURER_ID_DISCOVERY]!;
        debugPrint("BLE Scanner: Found discovery advertisement with payload length: ${payload.length}");
        if (payload.length == 5) {
          try {
            String uidShort = _bytesToUidShort(payload);
            int gender = payload[4];
            double distance = estimateDistance(r.rssi);
            if (_lastDiscoveryTime[uidShort] == null || now.difference(_lastDiscoveryTime[uidShort]!) > _debounceDuration) {
              _lastDiscoveryTime[uidShort] = now;
              onUserDetected?.call(uidShort, gender, distance);
              _statusService.updateStatus(NearbyStatus.userFound);
              debugPrint("BLE Scanner: User detected: $uidShort");
            }
          } catch (e) { 
            debugPrint("BLE Scanner: Error processing discovery advertisement: $e"); 
          }
        }
      }
      
      // Process Xiaomi alternative advertisements (minimal data)
      const int ALTERNATIVE_MANUFACTURER_ID = 0xFFFC;
      if (manufData.containsKey(ALTERNATIVE_MANUFACTURER_ID)) {
        final payload = manufData[ALTERNATIVE_MANUFACTURER_ID]!;
        debugPrint("BLE Scanner: Found Xiaomi alternative advertisement with payload length: ${payload.length}");
        if (payload.length >= 3) { // Minimal payload: 2 bytes UID + 1 byte gender
          try {
            // Reconstruct full UID from minimal data (pad with zeros)
            String shortUid = payload.sublist(0, 2).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
            String uidShort = shortUid.padRight(8, '0'); // Pad to 8 characters
            int gender = payload[2];
            double distance = estimateDistance(r.rssi);
            if (_lastDiscoveryTime[uidShort] == null || now.difference(_lastDiscoveryTime[uidShort]!) > _debounceDuration) {
              _lastDiscoveryTime[uidShort] = now;
              onUserDetected?.call(uidShort, gender, distance);
              _statusService.updateStatus(NearbyStatus.userFound);
              debugPrint("BLE Scanner: Xiaomi user detected: $uidShort");
            }
          } catch (e) { 
            debugPrint("BLE Scanner: Error processing Xiaomi alternative advertisement: $e"); 
          }
        }
      }
      
      // Process wave advertisements - CHANGED: Use 'if' instead of 'else if'
      if (manufData.containsKey(BleAdvertiser.MANUFACTURER_ID_WAVE)) {
        final payload = manufData[BleAdvertiser.MANUFACTURER_ID_WAVE]!;
        debugPrint("BLE Scanner: Found wave advertisement with payload length: ${payload.length}");
        if (payload.length == 4) {
          try {
            String uidShort = _bytesToUidShort(payload);
            if (_lastWaveTime[uidShort] == null || now.difference(_lastWaveTime[uidShort]!) > _waveDebounceDuration) {
              _lastWaveTime[uidShort] = now;
              if (!_waveReceivedController.isClosed) {
                _waveReceivedController.add(uidShort);
                debugPrint("BLE Scanner: Wave detected and sent to stream from $uidShort");
              } else {
                debugPrint("BLE Scanner: Wave detected but stream is closed from $uidShort");
              }
            } else {
              debugPrint("BLE Scanner: Wave from $uidShort ignored due to debounce");
            }
          } catch (e) { 
            debugPrint("BLE Scanner: Error processing wave advertisement: $e"); 
          }
        }
      }
    }
  }


  Future<void> stopScan() async {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _scanningStateSubscription?.cancel();
    _scanningStateSubscription = null;
    bool wasScanning = _isScanning; // Check internal flag before stopping

    try {
      if (fbp.FlutterBluePlus.isScanningNow) {
        await fbp.FlutterBluePlus.stopScan();
        debugPrint("BLE Scanner: Scan stopped via stopScan().");
      } else {
        debugPrint("BLE Scanner: stopScan() called but peripheral was not scanning.");
      }
    } catch(e) {
      debugPrint("BLE Scanner: Error stopping scan: $e");
    } finally {
      // Update status to idle *only if* it was previously active (scanning/found)
      // and we initiated the stop. Status listener handles unexpected stops.
      if (wasScanning && _statusService.currentStatus != NearbyStatus.idle) {
        _statusService.updateStatus(NearbyStatus.idle);
      }
      _isScanning = false; // Ensure internal flag is reset
    }
  }

  // Force reset scanner state (useful for restarting after issues)
  void forceReset() {
    debugPrint("BLE Scanner: Force resetting scanner state...");
    _isScanning = false;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _scanningStateSubscription?.cancel();
    _scanningStateSubscription = null;
    debugPrint("BLE Scanner: Scanner state reset complete.");
  }

  void dispose() {
    stopScan();
    _waveReceivedController.close();
    debugPrint("BLE Scanner: Disposed.");
  }
}