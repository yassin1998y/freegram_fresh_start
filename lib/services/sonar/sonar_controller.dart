// lib/services/sonar/sonar_controller.dart
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/services/sonar/bluetooth_discovery_service.dart';
import 'package:freegram/services/sonar/local_cache_service.dart';
import 'package:freegram/services/sonar/wave_service.dart';
import 'package:freegram/services/sonar/notification_service.dart';
import 'package:freegram/services/sync_manager.dart';
// Import bluetooth_service.dart directly here too
import 'package:freegram/services/sonar/bluetooth_service.dart';
import 'package:permission_handler/permission_handler.dart';

class SonarController {
  final BluetoothDiscoveryService _discoveryService;
  final LocalCacheService _cacheService;
  final WaveService _waveService;
  final NotificationService _notificationService;
  final SyncManager _syncManager;
  final ConnectivityBloc _connectivityBloc;
  final UserRepository _userRepository;

  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _statusSubscription;
  bool _isInitialized = false;
  bool _isRunning = false; // Tracks if Sonar *should* be running

  String? _currentUserShortId;
  int? _currentUserGender;

  Timer? _cleanupTimer;

  SonarController({
    required BluetoothDiscoveryService discoveryService,
    required LocalCacheService cacheService,
    required WaveService waveService,
    required NotificationService notificationService,
    required SyncManager syncManager,
    required ConnectivityBloc connectivityBloc,
    required UserRepository userRepository,
  })  : _discoveryService = discoveryService,
        _cacheService = cacheService,
        _waveService = waveService,
        _notificationService = notificationService,
        _syncManager = syncManager,
        _connectivityBloc = connectivityBloc,
        _userRepository = userRepository {
    _listenToConnectivity();
    _listenToDiscoveryStatus();
    debugPrint("SonarController: Initialized.");
  }

  String _uidShortFromFull(String fullId) {
    // ... (implementation remains the same)
    final bytes = utf8.encode(fullId);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8);
  }

  int _genderToInt(String gender) {
    // ... (implementation remains the same)
    switch (gender.toLowerCase()) { case 'male': return 1; case 'female': return 2; default: return 0; }
  }

  Future<bool> initializeUser() async {
    // ... (implementation remains the same)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final userModel = await _userRepository.getUser(user.uid);
      _currentUserShortId = _uidShortFromFull(user.uid);
      _currentUserGender = _genderToInt(userModel.gender);
      _discoveryService.initialize(_currentUserShortId!, _currentUserGender!);
      _isInitialized = true;
      debugPrint("SonarController: User Initialized. ShortID: $_currentUserShortId, Gender: $_currentUserGender");
      return true;
    } catch (e) {
      debugPrint("SonarController Error: Failed to fetch user details: $e");
      return false;
    }
  }

  Future<void> startSonar() async {
    if (!_isInitialized) {
      debugPrint("SonarController Error: Cannot start, user not initialized.");
      if (!await initializeUser()) return;
    }

    // Check _isRunning flag *before* checking permissions/hardware
    if (_isRunning) {
      debugPrint("SonarController: Start requested but already marked as running.");
      // Verify actual status, maybe it stopped unexpectedly?
      if (BluetoothStatusService().currentStatus == NearbyStatus.idle ||
          BluetoothStatusService().currentStatus == NearbyStatus.error ||
          BluetoothStatusService().currentStatus == NearbyStatus.adapterOff ||
          BluetoothStatusService().currentStatus == NearbyStatus.permissionsDenied ||
          BluetoothStatusService().currentStatus == NearbyStatus.permissionsPermanentlyDenied
      ) {
        debugPrint("SonarController: Mismatch detected. _isRunning=true but status is ${BluetoothStatusService().currentStatus}. Attempting restart.");
        _isRunning = false; // Reset flag and proceed
      } else {
        return; // Already running and status seems okay
      }
    }

    // --- Mark intention to run ---
    _isRunning = true;
    debugPrint("SonarController: Attempting to start Sonar discovery...");


    // Check permissions first
    if (!await _checkPermissions()) {
      debugPrint("SonarController: Permissions not granted. Cannot start Sonar.");
      // StatusService is updated within _checkPermissions
      _isRunning = false; // *** FIX: Reset flag on permission failure ***
      return;
    }

    // Check hardware state via Status Service
    if (BluetoothStatusService().currentStatus == NearbyStatus.adapterOff) {
      debugPrint("SonarController: Bluetooth adapter is off. Cannot start Sonar.");
      _isRunning = false; // *** FIX: Reset flag if adapter is off ***
      return; // Status service already reported adapterOff
    }

    // Try starting the discovery service
    await _discoveryService.start();

    // *** FIX: Check status *after* attempting to start ***
    final currentStatus = BluetoothStatusService().currentStatus;
    if (currentStatus == NearbyStatus.error || currentStatus == NearbyStatus.adapterOff) {
      debugPrint("SonarController: Discovery service failed to start properly (Status: $currentStatus). Resetting state.");
      _isRunning = false; // Reset flag if start failed
      // Stop potentially partially started services
      await _discoveryService.stop();
    } else {
      debugPrint("SonarController: Sonar started successfully (Current Status: $currentStatus).");
      // Start periodic cleanup timer only on successful start
      _cleanupTimer?.cancel();
      _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_isRunning) { _cacheService.pruneStaleNearbyUsers(); }
      });
    }
  }


  Future<void> stopSonar() async {
    // Check flag first
    if (!_isRunning) {
      debugPrint("SonarController: Stop requested but not marked as running.");
      // Optional: Double-check actual service status and try stopping anyway?
      // final currentStatus = BluetoothStatusService().currentStatus;
      // if (currentStatus == NearbyStatus.scanning || currentStatus == NearbyStatus.userFound) { ... }
      return;
    }
    debugPrint("SonarController: Stopping Sonar discovery...");
    await _discoveryService.stop();
    _cleanupTimer?.cancel();
    _isRunning = false; // Mark as stopped
    // Status service should update to Idle via discoveryService.stop()
    debugPrint("SonarController: Stopped.");
  }

  Future<void> sendWave(String targetUidShort) async {
    // ... (implementation remains the same)
    if (!_isInitialized || _currentUserShortId == null) return;
    debugPrint("SonarController: Requesting WaveService to send wave to $targetUidShort");
    await _waveService.sendWave(targetUidShort);
  }

  Future<bool> _checkPermissions() async {
    // ... (implementation remains the same)
    Map<Permission, PermissionStatus> statuses = await [
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();
    bool allGranted = statuses.values.every((status) => status.isGranted);
    if (!allGranted) {
      if (statuses.values.any((s) => s.isPermanentlyDenied)) {
        BluetoothStatusService().updateStatus(NearbyStatus.permissionsPermanentlyDenied);
      } else {
        BluetoothStatusService().updateStatus(NearbyStatus.permissionsDenied);
      }
    }
    return allGranted;
  }

  void _listenToConnectivity() {
    // ... (implementation remains the same)
    _connectivitySubscription = _connectivityBloc.stream.listen((state) {
      if (state is Online) {
        _syncManager.processQueue();
      }
    });
    if (_connectivityBloc.state is Online) {
      _syncManager.processQueue();
    }
  }

  void _listenToDiscoveryStatus() {
    // ... (implementation remains the same)
    _statusSubscription = BluetoothStatusService().statusStream.listen((status) { // Listen to shared service
      debugPrint("SonarController: Received status update -> $status");
      // Reset _isRunning flag if service stops unexpectedly
      if ((status == NearbyStatus.idle || status == NearbyStatus.error || status == NearbyStatus.adapterOff) && _isRunning) {
        // Check if this stop was intentional (e.g., via stopSonar)
        // This basic check assumes any transition to these states while _isRunning=true is unexpected.
        debugPrint("SonarController: Discovery service stopped/errored unexpectedly ($status). Resetting _isRunning flag.");
        _isRunning = false;
        _cleanupTimer?.cancel();
      } else if ((status == NearbyStatus.scanning || status == NearbyStatus.userFound) && !_isRunning) {
        // If service starts running unexpectedly (maybe auto-reconnect?), update flag
        debugPrint("SonarController: Discovery service started unexpectedly ($status). Setting _isRunning flag.");
        _isRunning = true;
        // Restart timer if needed
        _cleanupTimer?.cancel();
        _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          if (_isRunning) { _cacheService.pruneStaleNearbyUsers(); }
        });
      }
    });
  }

  void dispose() {
    // ... (implementation remains the same)
    debugPrint("SonarController: Disposing...");
    stopSonar();
    _connectivitySubscription?.cancel();
    _statusSubscription?.cancel();
    _cleanupTimer?.cancel();
    _discoveryService.dispose();
    _waveService.dispose();
    debugPrint("SonarController: Disposed.");
  }
}