// lib/services/sonar/bluetooth_discovery_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:freegram/locator.dart'; // <<<--- ADD locator import
import 'ble_advertiser.dart';
import 'ble_scanner.dart';
import 'local_cache_service.dart';
import 'wave_service.dart'; // Still need to import for type usage later
import 'bluetooth_service.dart' show NearbyStatus, BluetoothStatusService;

class BluetoothDiscoveryService {
  final BleAdvertiser _advertiser;
  final BleScanner _scanner;
  final LocalCacheService _cacheService;
  // final WaveService _waveService; // <<<--- REMOVE this field
  final BluetoothStatusService _statusService = BluetoothStatusService();

  static final fbp.Guid DISCOVERY_SERVICE_UUID = fbp.Guid("12345678-1234-5678-1234-56789abcdef0");

  String? _currentUserShortId;
  int? _currentUserGender;
  bool _isInitialized = false;
  bool _isRunning = false;

  StreamSubscription? _waveStreamSubscription;

  // Constructor updated: removed waveService parameter
  BluetoothDiscoveryService({
    required LocalCacheService cacheService,
    // required WaveService waveService, // <<<--- REMOVE parameter
    BleAdvertiser? advertiser,
    BleScanner? scanner,
  }) : _cacheService = cacheService,
       // _waveService = waveService, // <<<--- REMOVE assignment
       _advertiser = advertiser ?? BleAdvertiser(),
       _scanner = scanner ?? BleScanner() {
        _scanner.onUserDetected = _handleUserDetected;
        _listenForWaves();
       }

  void _listenForWaves() {
      _waveStreamSubscription?.cancel();
      _waveStreamSubscription = _scanner.waveReceivedStream.listen(
        (senderUidShort) {
          // *** GET WaveService from LOCATOR HERE ***
          try {
             locator<WaveService>().handleReceivedWave(senderUidShort);
          } catch (e) {
             debugPrint("BluetoothDiscoveryService: Error getting/calling WaveService handler: $e");
          }
        },
        onError: (error) {
           debugPrint("BluetoothDiscoveryService: Error on wave stream: $error");
        }
      );
      debugPrint("BluetoothDiscoveryService: Subscribed to wave stream.");
  }

  // ... (rest of the file remains the same: statusStream, initialize, start, stop, _handleUserDetected, sendWave, dispose) ...

  Stream<NearbyStatus> get statusStream => _statusService.statusStream;

  void initialize(String uidShort, int gender) {
    _currentUserShortId = uidShort;
    _currentUserGender = gender;
    _isInitialized = true;
     debugPrint("BluetoothDiscoveryService: Initialized with uidShort: $uidShort, gender: $gender");
  }

  Future<void> start() async {
    if (!_isInitialized) {
      debugPrint("BluetoothDiscoveryService Error: Service not initialized.");
      _statusService.updateStatus(NearbyStatus.error);
      return;
    }
    if (_isRunning) {
       debugPrint("BluetoothDiscoveryService: Already running.");
       return;
    }

    _isRunning = true;
    debugPrint("BluetoothDiscoveryService: Starting...");
    _listenForWaves(); // Ensure subscription is active
    await _scanner.startScan();
    if (_statusService.currentStatus != NearbyStatus.error &&
        _statusService.currentStatus != NearbyStatus.adapterOff) {
      await _advertiser.startAdvertising(_currentUserShortId!, _currentUserGender!);
    } else {
        debugPrint("BluetoothDiscoveryService: Skipping advertising due to scanner/adapter state: ${_statusService.currentStatus}");
        _isRunning = false;
    }
     debugPrint("BluetoothDiscoveryService: Start sequence complete. Running: $_isRunning");
  }

  Future<void> stop() async {
     if (!_isRunning) {
        debugPrint("BluetoothDiscoveryService: Already stopped.");
        return;
    }
     debugPrint("BluetoothDiscoveryService: Stopping...");
    _waveStreamSubscription?.cancel();
    _waveStreamSubscription = null;
    await _advertiser.stopAdvertising();
    await _scanner.stopScan();
    _isRunning = false;
     debugPrint("BluetoothDiscoveryService: Stopped.");
     if (_statusService.currentStatus != NearbyStatus.idle) {
        _statusService.updateStatus(NearbyStatus.idle);
     }
  }

  void _handleUserDetected(String uidShort, int gender, double distance) {
    _cacheService.storeOrUpdateNearby(uidShort, gender, distance);
  }

  Future<void> sendWave({required String fromUidFull, required String toUidShort}) async {
    if (!_isInitialized || _currentUserShortId == null) {
      debugPrint("BluetoothDiscoveryService Error: Cannot send wave, service not initialized or user ID missing.");
      return;
    }

     debugPrint("BluetoothDiscoveryService: Sending wave to $toUidShort from $fromUidFull");
    _cacheService.recordSentWave(fromUidFull: fromUidFull, toUidShort: toUidShort);
    await _advertiser.sendWaveBroadcast(_currentUserShortId!);
  }

  void dispose() {
    stop();
     debugPrint("BluetoothDiscoveryService: Disposed.");
  }
}
