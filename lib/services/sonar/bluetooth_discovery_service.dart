// lib/services/sonar/bluetooth_discovery_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart'; // <<<--- ADD locator import
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/utils/app_logger.dart';
import 'package:freegram/services/sonar/ble_advertiser.dart';
import 'package:freegram/services/sonar/ble_scanner.dart';
import 'package:freegram/services/sonar/local_cache_service.dart';
import 'package:freegram/services/sonar/wave_service.dart'; // Still need to import for type usage later
import 'package:freegram/services/sonar/bluetooth_service.dart'
    show NearbyStatus, BluetoothStatusService;
import 'package:freegram/services/sonar/wave_manager.dart';

class BluetoothDiscoveryService {
  final BleAdvertiser _advertiser;
  final BleScanner _scanner;
  final LocalCacheService _cacheService;
  // final WaveService _waveService; // <<<--- REMOVE this field
  final BluetoothStatusService _statusService = BluetoothStatusService();
  final WaveManager _waveManager = WaveManager();

  static final fbp.Guid discoveryServiceUuid =
      fbp.Guid("12345678-1234-5678-1234-56789abcdef0");

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
  })  : _cacheService = cacheService,
        // _waveService = waveService, // <<<--- REMOVE assignment
        _advertiser = advertiser ?? BleAdvertiser(),
        _scanner = scanner ?? BleScanner() {
    _scanner.onUserDetected = _handleUserDetected;
    _listenForWaves();
  }

  void _listenForWaves() {
    _waveStreamSubscription?.cancel();
    _waveStreamSubscription =
        _scanner.waveReceivedStream.listen((senderUidShort) {
      debugPrint(
          "BluetoothDiscoveryService: Received wave from $senderUidShort");
      // *** GET WaveService from LOCATOR HERE ***
      try {
        locator<WaveService>().handleReceivedWave(senderUidShort);
        debugPrint(
            "BluetoothDiscoveryService: Successfully processed wave from $senderUidShort");
      } catch (e) {
        debugPrint(
            "BluetoothDiscoveryService: Error getting/calling WaveService handler: $e");
      }
    }, onError: (error) {
      debugPrint("BluetoothDiscoveryService: Error on wave stream: $error");
    }, onDone: () {
      debugPrint("BluetoothDiscoveryService: Wave stream closed");
    });
    debugPrint("BluetoothDiscoveryService: Subscribed to wave stream.");
  }

  // ... (rest of the file remains the same: statusStream, initialize, start, stop, _handleUserDetected, sendWave, dispose) ...

  Stream<NearbyStatus> get statusStream => _statusService.statusStream;

  void initialize(String uidShort, int gender) {
    _currentUserShortId = uidShort;
    _currentUserGender = gender;
    _isInitialized = true;

    // Initialize scanner with current user's short ID for wave filtering
    _scanner.initialize(uidShort);

    // Set advertiser callback for wave completion (called after wave timer)
    _advertiser.onWaveCompleteCallback = () async {
      debugPrint(
          "[BluetoothDiscoveryService] Advertiser wave complete - restarting discovery");

      // CRITICAL FIX: Notify WaveManager that wave is actually complete
      await _waveManager.completeCurrentWave();

      // Restart discovery advertising
      if (_isRunning &&
          _currentUserShortId != null &&
          _currentUserGender != null) {
        await Future.delayed(const Duration(milliseconds: 300));
        await _advertiser.startAdvertising(
            _currentUserShortId!, _currentUserGender!);
      }
    };

    // Initialize wave manager with callbacks
    _waveManager.initialize(
      onWaveSend: (sender, target) async {
        // Send BLE broadcast - this will handle its own timing
        await _advertiser.sendWaveBroadcast(sender, target);
      },
      onWaveComplete: () async {
        // This callback is no longer used - completion is handled by advertiser callback
        debugPrint(
            "[BluetoothDiscoveryService] WaveManager onWaveComplete (deprecated)");
      },
    );

    debugPrint(
        "BluetoothDiscoveryService: Initialized with uidShort: $uidShort, gender: $gender");
  }

  Future<void> start() async {
    if (!_isInitialized) {
      debugPrint("BluetoothDiscoveryService Error: Service not initialized.");
      _statusService.updateStatus(NearbyStatus.error);
      return;
    }
    if (_isRunning) {
      debugPrint("BluetoothDiscoveryService: Already running.");
      // If already running but status is idle, force restart
      if (_statusService.currentStatus == NearbyStatus.idle) {
        debugPrint(
            "BluetoothDiscoveryService: Force restarting due to idle status while running.");
        await stop();
        // Wait a bit before restarting
        await Future.delayed(const Duration(milliseconds: 100));
      } else {
        return;
      }
    }

    _isRunning = true;
    AppLogger.info("BluetoothDiscoveryService: Starting...");

    // Force reset scanner state before starting (helps with restart issues)
    _scanner.forceReset();

    // Ensure wave stream subscription is active BEFORE starting scan
    _listenForWaves();
    AppLogger.debug(
        "BluetoothDiscoveryService: Wave stream subscription ensured");

    await _scanner.startScan();
    AppLogger.debug("BluetoothDiscoveryService: Scanner started");

    if (_statusService.currentStatus != NearbyStatus.error &&
        _statusService.currentStatus != NearbyStatus.adapterOff) {
      // --- Cloaking Mode Check ---
      bool isCloaked = false;
      try {
        final currentId = FirebaseAuth.instance.currentUser?.uid;
        if (currentId != null) {
          final profile = _cacheService.getUserProfile(currentId);
          // Check 'cloaking_mode' (default false)
          isCloaked = profile?.privacySettings?['cloaking_mode'] == true;
          if (isCloaked) {
            AppLogger.info(
                "BluetoothDiscoveryService: Cloaking Mode ENABLED. Skipping advertising.");
          }
        }
      } catch (e) {
        AppLogger.warning(
            "BluetoothDiscoveryService: Failed to check privacy settings: $e");
      }

      if (!isCloaked) {
        await _advertiser.startAdvertising(
            _currentUserShortId!, _currentUserGender!);
        AppLogger.info("BluetoothDiscoveryService: Advertiser started");
      }
    } else {
      AppLogger.warning(
          "BluetoothDiscoveryService: Skipping advertising due to scanner/adapter state: ${_statusService.currentStatus}");
      // Don't set _isRunning = false, allow scanning-only mode
      AppLogger.info("BluetoothDiscoveryService: Running in scan-only mode");
    }
    AppLogger.info(
        "BluetoothDiscoveryService: Start sequence complete. Running: $_isRunning");
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

  Future<void> sendWave(
      {required String fromUidFull, required String toUidShort}) async {
    if (!_isInitialized || _currentUserShortId == null) {
      debugPrint(
          "BluetoothDiscoveryService Error: Cannot send wave, service not initialized or user ID missing.");
      return;
    }

    debugPrint(
        "BluetoothDiscoveryService: Wave request - $fromUidFull ($_currentUserShortId) → $toUidShort");

    // Use WaveManager for reliable wave sending with cooldown and queue management
    final success = await _waveManager.sendWave(
      senderUidShort: _currentUserShortId!,
      targetUidShort: toUidShort,
    );

    if (!success) {
      debugPrint(
          "BluetoothDiscoveryService: Wave send rejected by WaveManager (cooldown or validation)");
      return;
    }

    // Try to send server notification immediately if online, don't queue it
    try {
      final nearbyUser = _cacheService.getNearbyUser(toUidShort);
      if (nearbyUser?.profileId != null && nearbyUser!.profileId!.isNotEmpty) {
        // We have the full profile ID, send server notification immediately
        await _sendWaveNotificationImmediately(
            fromUidFull, nearbyUser.profileId!);
      } else {
        // Profile not synced yet, queue for later sync
        _cacheService.recordSentWave(
            fromUidFull: fromUidFull, toUidShort: toUidShort);
      }
    } catch (e) {
      debugPrint(
          "BluetoothDiscoveryService: Error sending immediate wave notification: $e");
      // Fallback: queue for later sync
      _cacheService.recordSentWave(
          fromUidFull: fromUidFull, toUidShort: toUidShort);
    }
  }

  Future<void> _sendWaveNotificationImmediately(
      String fromUserId, String toUserId) async {
    try {
      final userRepository = locator<UserRepository>();
      await userRepository.sendWave(fromUserId, toUserId);
      debugPrint(
          "BluetoothDiscoveryService: Server wave notification sent immediately");
    } catch (e) {
      debugPrint(
          "BluetoothDiscoveryService: Failed to send immediate wave notification: $e");
      rethrow; // Let caller handle the error
    }
  }

  void dispose() {
    stop();
    debugPrint("BluetoothDiscoveryService: Disposed.");
  }
}
