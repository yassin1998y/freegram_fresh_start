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
      // Start the scan using flutter_blue_plus
      await fbp.FlutterBluePlus.startScan(
        withServices: [BluetoothDiscoveryService.DISCOVERY_SERVICE_UUID],
        androidScanMode: fbp.AndroidScanMode.lowLatency,
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
    // ... (implementation remains the same) ...
    // It correctly updates status to userFound via _statusService.updateStatus
    DateTime now = DateTime.now();
    for (fbp.ScanResult r in results) {
      final manufData = r.advertisementData.manufacturerData;
      if (manufData.containsKey(BleAdvertiser.MANUFACTURER_ID_DISCOVERY)) {
        final payload = manufData[BleAdvertiser.MANUFACTURER_ID_DISCOVERY]!;
        if (payload.length == 5) {
          try {
            String uidShort = _bytesToUidShort(payload);
            int gender = payload[4];
            double distance = estimateDistance(r.rssi);
            if (_lastDiscoveryTime[uidShort] == null || now.difference(_lastDiscoveryTime[uidShort]!) > _debounceDuration) {
              _lastDiscoveryTime[uidShort] = now;
              onUserDetected?.call(uidShort, gender, distance);
              _statusService.updateStatus(NearbyStatus.userFound);
            }
          } catch (e) { /* Log error */ }
        }
      }
      else if (manufData.containsKey(BleAdvertiser.MANUFACTURER_ID_WAVE)) {
        final payload = manufData[BleAdvertiser.MANUFACTURER_ID_WAVE]!;
        if (payload.length == 4) {
          try {
            String uidShort = _bytesToUidShort(payload);
            if (_lastWaveTime[uidShort] == null || now.difference(_lastWaveTime[uidShort]!) > _waveDebounceDuration) {
              _lastWaveTime[uidShort] = now;
              if (!_waveReceivedController.isClosed) {
                _waveReceivedController.add(uidShort);
              }
              debugPrint("BLE Scanner: Detected Wave from $uidShort");
            }
          } catch (e) { /* Log error */ }
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

  void dispose() {
    stopScan();
    _waveReceivedController.close();
    debugPrint("BLE Scanner: Disposed.");
  }
}