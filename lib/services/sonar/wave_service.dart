// lib/services/sonar/wave_service.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/hive/nearby_user.dart'; // Import NearbyUser
import 'package:freegram/models/hive/user_profile.dart';
import 'package:freegram/services/sonar/bluetooth_discovery_service.dart';
import 'package:freegram/services/sonar/local_cache_service.dart';
import 'package:freegram/services/sonar/notification_service.dart';
import 'package:vibration/vibration.dart';

class WaveService {
  final BluetoothDiscoveryService _discoveryService;
  final LocalCacheService _cacheService;
  final NotificationService _notificationService;
  // WaveManager is managed by BluetoothDiscoveryService (singleton - single source of truth)
  // StreamSubscription? _waveSubscription; // REMOVED

  WaveService({
    required BluetoothDiscoveryService discoveryService,
    required LocalCacheService cacheService,
    required NotificationService notificationService,
  })  : _discoveryService = discoveryService,
        _cacheService = cacheService,
        _notificationService = notificationService {
    // Subscription logic moved to BluetoothDiscoveryService
    debugPrint("WaveService Initialized.");
  }

  Future<void> sendWave(String targetUidShort) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint("WaveService Error: Cannot send wave, user not logged in.");
      return;
    }

    debugPrint("WaveService: Sending wave to $targetUidShort");
    try {
      // Pass both IDs to discovery service
      await _discoveryService.sendWave(
          fromUidFull: currentUser.uid, toUidShort: targetUidShort);
      debugPrint("WaveService: Wave broadcast initiated for $targetUidShort.");
    } catch (e) {
      debugPrint("WaveService Error: Failed to send wave: $e");
    }
  }

  /// Handles an incoming wave detected by the BLE scanner.
  /// Cooldown enforcement happens in WaveManager (via BluetoothDiscoveryService)
  /// This method only processes valid waves that pass through the scanner filter
  Future<void> handleReceivedWave(String senderUidShort) async {
    debugPrint("[WaveService] Processing wave from $senderUidShort");

    // 1. Vibrate
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 500);
      }
    } catch (e) {
      debugPrint("WaveService Error: Could not vibrate: $e");
    }

    // 2. Record locally
    _cacheService.recordReceivedWave(senderUidShort);

    // 3. Show Local Notification
    String senderName = "Someone nearby";
    NearbyUser? nearbyUser = _cacheService.getNearbyUser(senderUidShort);
    String? payload = senderUidShort; // Default payload is short ID

    if (nearbyUser?.profileId != null) {
      UserProfile? profile =
          _cacheService.getUserProfile(nearbyUser!.profileId!);
      if (profile != null) {
        senderName = profile.name;
        payload = profile.profileId; // Use full ID as payload if available
      }
    }

    try {
      await _notificationService.showWaveNotification(
        title: "👋 Wave Received!",
        body: "$senderName waved at you!",
        payload: payload,
      );
      debugPrint("WaveService: Wave notification shown for $senderName");
    } catch (e) {
      debugPrint("WaveService Error: Failed to show wave notification: $e");
    }
  }

  void simulateReceiveWave(String senderUidShort) {
    debugPrint("WaveService: Simulating wave reception from $senderUidShort");
    handleReceivedWave(senderUidShort); // Call public method
  }

  void dispose() {
    // _waveSubscription?.cancel(); // REMOVED
    debugPrint("WaveService: Disposed.");
  }
}
