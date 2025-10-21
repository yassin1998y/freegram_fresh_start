// lib/services/bluetooth_service.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/services/native_gatt.dart'; // We'll rename this file soon
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';

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
  BluetoothStatusService._internal();
  final _statusController = StreamController<NearbyStatus>.broadcast();
  Stream<NearbyStatus> get statusStream => _statusController.stream;
  NearbyStatus _currentStatus = NearbyStatus.idle;
  NearbyStatus get currentStatus => _currentStatus;
  void updateStatus(NearbyStatus status) {
    if (_currentStatus == status && status != NearbyStatus.userFound) return;
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }
  void dispose() {
    _statusController.close();
  }
}

class BluetoothService {
  final BluetoothStatusService _statusService = BluetoothStatusService();
  final UserRepository _userRepository;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _adapterStateSubscription;
  bool _shouldBeDiscovering = false;
  bool _isPausedByLifecycle = false;
  final Set<String> _recentlyProcessedUIDs = {};

  static final fbp.Guid _serviceUuid = fbp.Guid("12345678-1234-5678-1234-56789abcdef0");
  static const int _manufacturerId = 0xFFFF;

  Stream<NearbyStatus> get statusStream => _statusService.statusStream;
  String? getCurrentUserId() => FirebaseAuth.instance.currentUser?.uid;

  BluetoothService({required UserRepository userRepository}) : _userRepository = userRepository;

  Future<void> start() async {
    if (_adapterStateSubscription != null) return;
    if (await _checkAndRequestPermissions()) {
      _adapterStateSubscription = fbp.FlutterBluePlus.adapterState.listen((state) {
        if (state == fbp.BluetoothAdapterState.on) {
          _statusService.updateStatus(NearbyStatus.idle);
          if (_shouldBeDiscovering) startDiscovery();
        } else {
          _statusService.updateStatus(NearbyStatus.adapterOff);
          stopDiscovery();
        }
      });
    }
  }

  Future<void> startDiscovery() async {
    _shouldBeDiscovering = true;
    if (_isPausedByLifecycle || fbp.FlutterBluePlus.isScanningNow) return;
    if (fbp.FlutterBluePlus.adapterStateNow != fbp.BluetoothAdapterState.on) {
      _statusService.updateStatus(NearbyStatus.adapterOff);
      return;
    }
    await _cleanupStaleUsers();
    try {
      fbp.FlutterBluePlus.startScan(withServices: [_serviceUuid]);
      _scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
        for (fbp.ScanResult r in results) {
          _handleDiscoveredDevice(r);
        }
      });
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await NativeAdvertiser.startAdvertising(currentUser.uid);
      }
      _statusService.updateStatus(NearbyStatus.scanning);
    } catch (e) {
      debugPrint("Error starting discovery: $e");
      _statusService.updateStatus(NearbyStatus.error);
    }
  }

  Future<void> stopDiscovery() async {
    _shouldBeDiscovering = false;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    await fbp.FlutterBluePlus.stopScan().catchError((e) => debugPrint("Error stopping scan: $e"));
    await NativeAdvertiser.stopAdvertising().catchError((e) => debugPrint("Error stopping advertiser: $e"));
    if (_statusService.currentStatus != NearbyStatus.idle) {
      _statusService.updateStatus(NearbyStatus.idle);
    }
  }

  void _handleDiscoveredDevice(fbp.ScanResult result) {
    final manufacturerData = result.advertisementData.manufacturerData[_manufacturerId];
    if (manufacturerData == null || manufacturerData.isEmpty) return;

    try {
      final userId = String.fromCharCodes(manufacturerData);
      if (_recentlyProcessedUIDs.contains(userId)) return;

      _processFoundUser(userId, result.rssi, result.device.remoteId.toString());

      _recentlyProcessedUIDs.add(userId);
      Future.delayed(const Duration(seconds: 10), () {
        _recentlyProcessedUIDs.remove(userId);
      });
    } catch (e) {
      debugPrint("Error parsing manufacturer data: $e");
    }
  }

  Future<void> _processFoundUser(String userId, int rssi, String deviceAddress) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == userId) return;

    final profileBox = Hive.box('user_profiles');

    try {
      if (!profileBox.containsKey(userId)) {
        final userModel = await _userRepository.getUser(userId);
        await profileBox.put(userId, userModel.toMap());
      }

      final contactsBox = Hive.box('nearby_contacts');
      contactsBox.put(userId, {
        'lastSeen': DateTime.now().toIso8601String(),
        'rssi': rssi,
        'address': deviceAddress,
      });

      _statusService.updateStatus(NearbyStatus.userFound);

    } catch (e) {
      debugPrint("Failed to process found user $userId (likely offline and not cached): $e");
    }
  }

  Future<void> _cleanupStaleUsers() async {
    final contactsBox = Hive.box('nearby_contacts');
    final now = DateTime.now();
    final List<String> staleUsers = [];
    for (var key in contactsBox.keys) {
      final data = contactsBox.get(key) as Map;
      final lastSeen = DateTime.tryParse(data['lastSeen'] ?? '');
      if (lastSeen == null || now.difference(lastSeen).inMinutes > 5) {
        staleUsers.add(key as String);
      }
    }
    for (var key in staleUsers) {
      await contactsBox.delete(key);
    }
  }

  void pause() {
    _isPausedByLifecycle = true;
    stopDiscovery();
  }

  void resume() {
    _isPausedByLifecycle = false;
    if (_shouldBeDiscovering) {
      startDiscovery();
    }
  }

  void dispose() {
    stopDiscovery();
    _adapterStateSubscription?.cancel();
  }

  Future<bool> _checkAndRequestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();
    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      _statusService.updateStatus(NearbyStatus.permissionsPermanentlyDenied);
      return false;
    }
    if (statuses.values.any((s) => s.isDenied)) {
      _statusService.updateStatus(NearbyStatus.permissionsDenied);
      return false;
    }
    return true;
  }
}