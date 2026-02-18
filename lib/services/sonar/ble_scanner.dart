// lib/services/sonar/ble_scanner.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'
    as fbp; // Keep fbp for scanning
import 'package:freegram/services/sonar/ble_advertiser.dart';
import 'package:freegram/services/sonar/bluetooth_service.dart'; // Import corrected bluetooth_service.dart
import 'package:freegram/services/sonar/bluetooth_discovery_service.dart';

typedef UserDetectedCallback = void Function(
    String uidShort, int gender, double distance);

class BleScanner {
  final BluetoothStatusService _statusService = BluetoothStatusService();
  StreamSubscription? _scanSubscription;
  StreamSubscription? _scanningStateSubscription;
  bool _isScanning = false;
  String?
      _currentUserShortId; // Store current user's short ID for wave filtering

  UserDetectedCallback? onUserDetected;

  final StreamController<String> _waveReceivedController =
      StreamController<String>.broadcast();
  Stream<String> get waveReceivedStream => _waveReceivedController.stream;

  final Map<String, DateTime> _lastDiscoveryTime = {};
  final Map<String, DateTime> _lastWaveTime = {};
  final Duration _debounceDuration = const Duration(seconds: 2);
  final Duration _waveDebounceDuration = const Duration(
      seconds:
          15); // Increased to prevent duplicate wave receptions during 3s broadcast

  BleScanner({this.onUserDetected});

  /// Initialize scanner with current user's short ID for wave filtering
  void initialize(String currentUserShortId) {
    _currentUserShortId = currentUserShortId;
    debugPrint("BLE Scanner: Initialized with user ID: $_currentUserShortId");
  }

  double estimateDistance(int rssi, {int txPower = -59}) {
    // ... (implementation remains the same)
    if (rssi == 0) return double.infinity;
    double ratio = rssi * 1.0 / txPower;
    if (ratio < 1.0) return pow(ratio, 10).toDouble();
    return (0.89976) * pow(ratio, 7.7095) + 0.111;
  }

  String _bytesToUidShort(List<int> bytes) {
    // ... (implementation remains the same)
    if (bytes.length < 4) {
      throw ArgumentError(
          'Byte list must contain at least 4 bytes for uidShort');
    }
    return bytes
        .sublist(0, 4)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
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
      _scanningStateSubscription =
          fbp.FlutterBluePlus.isScanning.listen((scanning) {
        _isScanning = scanning;
        if (scanning) {
          // Only update if not already scanning or finding users
          if (_statusService.currentStatus != NearbyStatus.scanning &&
              _statusService.currentStatus != NearbyStatus.userFound) {
            _statusService.updateStatus(NearbyStatus.scanning);
          }
          debugPrint("BLE Scanner: Scan reported as active.");
        } else {
          // If scanning stops unexpectedly (not via stopScan method)
          if (_statusService.currentStatus == NearbyStatus.scanning ||
              _statusService.currentStatus == NearbyStatus.userFound) {
            _statusService.updateStatus(NearbyStatus.idle);
            debugPrint("BLE Scanner: Scan stopped unexpectedly or completed.");
          }
          // Always reset the scanning flag when scan stops
          _isScanning = false;
        }
      });

      _scanSubscription?.cancel();
      _scanSubscription = fbp.FlutterBluePlus.scanResults
          .listen(_handleScanResult, onError: (error) {
        debugPrint("BLE Scanner: ScanResults stream error: $error");
        _statusService.updateStatus(NearbyStatus.error);
        stopScan();
      });

      debugPrint("BLE Scanner: Attempting to start scan...");
      // Start the scan using flutter_blue_plus with more aggressive settings
      // MIUI FIX: Don't use withServices filter on any device to maximize compatibility
      // The manufacturer data filter in _handleScanResult will filter out unwanted devices
      // No timeout - scan continuously until manually stopped
      await fbp.FlutterBluePlus.startScan(
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
    DateTime now = DateTime.now();
    debugPrint("BLE Scanner: Processing ${results.length} scan results");

    for (fbp.ScanResult r in results) {
      final manufData = r.advertisementData.manufacturerData;
      final serviceUuids = r.advertisementData.serviceUuids;
      final serviceData = r.advertisementData.serviceData;
      debugPrint(
          "BLE Scanner: Processing device ${r.device.remoteId} with manufacturer data: $manufData, services: $serviceUuids, service data: $serviceData, RSSI: ${r.rssi}");

      // Process discovery/wave advertisements (manufacturer ID 117)
      // CRITICAL FIX: Process manufacturer ID 117 ONCE and differentiate by payload length
      // Discovery = 5 bytes, Wave = 8 bytes
      // This prevents duplicate processing of the same packet
      if (manufData.containsKey(BleAdvertiser.MANUFACTURER_ID_DISCOVERY)) {
        final payload = manufData[BleAdvertiser.MANUFACTURER_ID_DISCOVERY]!;
        debugPrint(
            "BLE Scanner: Found manufacturer ID 117, payload length: ${payload.length}");

        if (payload.length == 5) {
          // DISCOVERY: 5 bytes (UID 4 bytes + gender 1 byte)
          try {
            String uidShort = _bytesToUidShort(payload);
            int gender = payload[4];
            double distance = estimateDistance(r.rssi);
            if (_lastDiscoveryTime[uidShort] == null ||
                now.difference(_lastDiscoveryTime[uidShort]!) >
                    _debounceDuration) {
              _lastDiscoveryTime[uidShort] = now;
              onUserDetected?.call(uidShort, gender, distance);
              _statusService.updateStatus(NearbyStatus.userFound);
              debugPrint("BLE Scanner: Discovery detected: $uidShort");
            }
          } catch (e) {
            debugPrint(
                "BLE Scanner: Error processing discovery advertisement: $e");
          }
        } else if (payload.length == 8) {
          // WAVE: 8 bytes (sender 4 bytes + target 4 bytes) in MANUFACTURER DATA
          debugPrint("BLE Scanner: Found WAVE (8 bytes) in manufacturer data");
          try {
            String senderUidShort = _bytesToUidShort(payload.sublist(0, 4));
            String targetUidShort = _bytesToUidShort(payload.sublist(4, 8));

            debugPrint(
                "BLE Scanner: Wave from $senderUidShort to $targetUidShort (my ID: $_currentUserShortId)");

            // CRITICAL FIX: Prevent self-wave notifications
            if (senderUidShort == _currentUserShortId) {
              debugPrint(
                  "BLE Scanner: Wave ignored - cannot receive wave from self");
            }
            // Only process if this device is the target
            else if (targetUidShort == _currentUserShortId) {
              if (_lastWaveTime[senderUidShort] == null ||
                  now.difference(_lastWaveTime[senderUidShort]!) >
                      _waveDebounceDuration) {
                _lastWaveTime[senderUidShort] = now;
                if (!_waveReceivedController.isClosed) {
                  _waveReceivedController.add(senderUidShort);
                  debugPrint(
                      "BLE Scanner: Wave accepted from $senderUidShort (targeted to me)");
                } else {
                  debugPrint(
                      "BLE Scanner: Wave detected but stream is closed from $senderUidShort");
                }
              } else {
                debugPrint(
                    "BLE Scanner: Wave from $senderUidShort ignored due to debounce");
              }
            } else {
              debugPrint(
                  "BLE Scanner: Wave ignored - not targeted to me (target: $targetUidShort)");
            }
          } catch (e) {
            debugPrint("BLE Scanner: Error processing wave advertisement: $e");
          }
        } else {
          debugPrint(
              "BLE Scanner: Unknown payload length ${payload.length} for manufacturer ID 117");
        }
      }

      // MIUI FIX: Process wave advertisements in SERVICE DATA (primary method)
      // Service Data bypasses MIUI's manufacturer data filtering!
      // Check for our service UUID in service data
      final discoveryServiceUuid = BluetoothDiscoveryService
          .DISCOVERY_SERVICE_UUID
          .toString()
          .toUpperCase();
      if (serviceData.isNotEmpty) {
        // Check if our service UUID is in the service data
        for (var serviceUuid in serviceData.keys) {
          if (serviceUuid.toString().toUpperCase() == discoveryServiceUuid) {
            final payload = serviceData[serviceUuid]!;
            debugPrint(
                "BLE Scanner: Found Service Data with our UUID, payload length: ${payload.length}");

            // Wave in service data: 8 bytes (sender 4 bytes + target 4 bytes)
            if (payload.length == 8) {
              debugPrint("BLE Scanner: Found WAVE (8 bytes) in SERVICE DATA");
              try {
                // Extract sender and target UIDs
                String senderUidShort = _bytesToUidShort(payload.sublist(0, 4));
                String targetUidShort = _bytesToUidShort(payload.sublist(4, 8));

                debugPrint(
                    "BLE Scanner: Service Data Wave from $senderUidShort to $targetUidShort (my ID: $_currentUserShortId)");

                // CRITICAL FIX: Prevent self-wave notifications
                if (senderUidShort == _currentUserShortId) {
                  debugPrint(
                      "BLE Scanner: Service Data Wave ignored - cannot receive wave from self");
                }
                // Only process if this device is the target
                else if (targetUidShort == _currentUserShortId) {
                  if (_lastWaveTime[senderUidShort] == null ||
                      now.difference(_lastWaveTime[senderUidShort]!) >
                          _waveDebounceDuration) {
                    _lastWaveTime[senderUidShort] = now;
                    if (!_waveReceivedController.isClosed) {
                      _waveReceivedController.add(senderUidShort);
                      debugPrint(
                          "BLE Scanner: Service Data Wave accepted from $senderUidShort (targeted to me)");
                    } else {
                      debugPrint(
                          "BLE Scanner: Service Data Wave detected but stream is closed from $senderUidShort");
                    }
                  } else {
                    debugPrint(
                        "BLE Scanner: Service Data Wave from $senderUidShort ignored due to debounce");
                  }
                } else {
                  debugPrint(
                      "BLE Scanner: Service Data Wave ignored - not targeted to me (target: $targetUidShort)");
                }
              } catch (e) {
                debugPrint(
                    "BLE Scanner: Error processing Service Data wave advertisement: $e");
              }
            }
            break; // Found our service UUID, no need to check others
          }
        }
      }

      // Process Xiaomi alternative advertisements (minimal data)
      const int alternativeManufacturerId = 0xFFFC;
      if (manufData.containsKey(alternativeManufacturerId)) {
        final payload = manufData[alternativeManufacturerId]!;
        debugPrint(
            "BLE Scanner: Found Xiaomi alternative advertisement with payload length: ${payload.length}");
        if (payload.length >= 3) {
          // Minimal payload: 2 bytes UID + 1 byte gender
          try {
            // Reconstruct full UID from minimal data (pad with zeros)
            String shortUid = payload
                .sublist(0, 2)
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join();
            String uidShort = shortUid.padRight(8, '0'); // Pad to 8 characters
            int gender = payload[2];
            double distance = estimateDistance(r.rssi);
            if (_lastDiscoveryTime[uidShort] == null ||
                now.difference(_lastDiscoveryTime[uidShort]!) >
                    _debounceDuration) {
              _lastDiscoveryTime[uidShort] = now;
              onUserDetected?.call(uidShort, gender, distance);
              _statusService.updateStatus(NearbyStatus.userFound);
              debugPrint("BLE Scanner: Xiaomi user detected: $uidShort");
            }
          } catch (e) {
            debugPrint(
                "BLE Scanner: Error processing Xiaomi alternative advertisement: $e");
          }
        }
      }

      // REMOVED: Duplicate manufacturer ID 117 processing
      // Now handled in a single block above to prevent double-processing
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
        debugPrint(
            "BLE Scanner: stopScan() called but peripheral was not scanning.");
      }
    } catch (e) {
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

    // CRITICAL FIX: Clear debounce maps to prevent stale advertisements
    // When BLE scan restarts, old advertisements may still be in scanner cache
    // Clearing these maps ensures we don't process stale packets
    _lastDiscoveryTime.clear();
    _lastWaveTime.clear();

    debugPrint("BLE Scanner: Scanner state reset complete.");
  }

  void dispose() {
    stopScan();
    _waveReceivedController.close();
    debugPrint("BLE Scanner: Disposed.");
  }
}
