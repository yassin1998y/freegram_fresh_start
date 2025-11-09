// lib/services/sonar/ble_advertiser.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
// Correct import for advertising
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
// Import for status service and UUID
import 'package:freegram/services/sonar/bluetooth_discovery_service.dart';
import 'package:freegram/services/sonar/bluetooth_service.dart';
// MIUI-specific BLE fix
import 'package:freegram/services/sonar/miui_ble_fix.dart';
import 'package:freegram/services/device_info_helper.dart';

class BleAdvertiser {
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  final BluetoothStatusService _statusService = BluetoothStatusService();
  final MiuiBleFixService _miuiFix = MiuiBleFixService();
  final DeviceInfoHelper _deviceInfo = DeviceInfoHelper();
  bool _isAdvertising = false;
  bool _usingNativeAdvertiser = false; // Track if using native advertiser
  Timer? _waveTimer;

  // Callback for wave completion (called by timer after wave stops)
  Function()? onWaveCompleteCallback;

  // Define Manufacturer IDs
  // MIUI FIX: Use SAME manufacturer ID (117) for BOTH discovery and waves!
  // MIUI filters manufacturer ID 118 (0x0076) completely, even in main packet
  // We differentiate by payload length: discovery=5 bytes, wave=8 bytes
  static const int MANUFACTURER_ID_DISCOVERY = 0x0075;
  static const int MANUFACTURER_ID_WAVE = 0x0075; // SAME as discovery for MIUI!

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
      await _peripheral.isAdvertising;
      // If we need a more direct check, consider adding flutter_blue_plus just for adapter state
      // or using a platform channel. For now, we rely on start success/failure.
      return true; // Assume enabled if no immediate error, start will confirm
    } catch (e) {
      debugPrint(
          "BLE Advertiser: Error checking adapter state (assuming off): $e");
      return false; // Assume disabled if check fails
    }
  }

  Future<void> startAdvertising(String uidShort, int gender) async {
    // CRITICAL FIX: Cancel any active wave timer first
    // This prevents race conditions where a wave is still broadcasting
    if (_waveTimer != null && _waveTimer!.isActive) {
      debugPrint(
          "BLE Advertiser: WARNING - Wave timer still active! Waiting for wave to complete...");
      // Wait for wave to finish before starting discovery
      await Future.delayed(const Duration(milliseconds: 500));
      // If still active after waiting, force cancel
      if (_waveTimer != null && _waveTimer!.isActive) {
        debugPrint("BLE Advertiser: Force canceling stuck wave timer");
        _waveTimer?.cancel();
        _isAdvertising = false;
        _usingNativeAdvertiser = false;
      }
    }

    bool isAdapterOn = await _isAdapterEnabled();
    if (_isAdvertising || !isAdapterOn) {
      if (!isAdapterOn) _statusService.updateStatus(NearbyStatus.adapterOff);
      debugPrint(
          "BLE Advertiser: Cannot start advertising. IsAdvertising: $_isAdvertising, AdapterOn: $isAdapterOn, UsingNative: $_usingNativeAdvertiser");
      return;
    }

    // Initialize MIUI fix service
    await _miuiFix.initialize();
    await _deviceInfo.initialize();

    // Try native advertiser first for ALL Android devices for maximum MIUI compatibility
    // This ensures consistent advertisement packet structure
    debugPrint(
        "[BLE Advertiser] Trying native advertiser first for maximum compatibility...");
    bool nativeSuccess =
        await _miuiFix.startNativeAdvertising(uidShort, gender);
    if (nativeSuccess) {
      _isAdvertising = true;
      _usingNativeAdvertiser = true;
      debugPrint("[BLE Advertiser] Native advertising successful!");
      return;
    } else {
      debugPrint(
          "[BLE Advertiser] Native advertising failed, trying flutter_ble_peripheral...");
    }

    try {
      Uint8List uidBytes = _uidShortToBytes(uidShort);
      Uint8List payload = Uint8List.fromList([...uidBytes, gender & 0xFF]);

      // Use AdvertiseData from flutter_ble_peripheral
      final advData = AdvertiseData(
        // Use the string representation for serviceUuid
        serviceUuid:
            BluetoothDiscoveryService.DISCOVERY_SERVICE_UUID.toString(),
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

      debugPrint(
          "BLE Advertiser: Attempting to start discovery advertising with manufacturer ID: $MANUFACTURER_ID_DISCOVERY (0x${MANUFACTURER_ID_DISCOVERY.toRadixString(16).toUpperCase()})");
      debugPrint("BLE Advertiser: Payload bytes: $payload");
      await _peripheral.start(advertiseData: advData);

      _isAdvertising = true;
      debugPrint("BLE Advertiser: Started Discovery Advertising successfully.");
    } catch (e) {
      debugPrint("BLE Advertiser: Error starting discovery advertising: $e");

      // Handle specific error codes for Xiaomi devices
      if (e.toString().contains('18')) {
        debugPrint(
            "BLE Advertiser: Error 18 - Too many advertisers (Xiaomi device detected). Implementing retry strategy...");

        // Show MIUI-specific guidance
        if (_deviceInfo.isXiaomiDevice) {
          final diagnosis = await _miuiFix.diagnoseMiuiAdvertisingIssue();
          debugPrint("BLE Advertiser: MIUI Diagnosis: $diagnosis");
          debugPrint(
              "BLE Advertiser: ${_miuiFix.getMiuiAdvertisingGuidance()}");
        }

        await _handleXiaomiAdvertisingError(uidShort, gender);

        // If all retry attempts failed, enter scan-only mode
        if (!_isAdvertising) {
          debugPrint(
              "BLE Advertiser: All advertising attempts failed. Entering scan-only mode for Xiaomi device.");
          // Don't set error status - allow scanning to continue
        }
      } else {
        _statusService.updateStatus(NearbyStatus.error);
        _isAdvertising = false;
      }
    }
  }

  // Special handling for Xiaomi devices with advertising limitations
  Future<void> _handleXiaomiAdvertisingError(
      String uidShort, int gender) async {
    debugPrint(
        "BLE Advertiser: Implementing Xiaomi-specific advertising strategy...");

    // Strategy 1: Try native advertiser if available (best for MIUI)
    if (_miuiFix.shouldUseNativeAdvertiser) {
      debugPrint("BLE Advertiser: Attempting native advertising fallback...");
      bool nativeSuccess =
          await _miuiFix.startNativeAdvertising(uidShort, gender);
      if (nativeSuccess) {
        _isAdvertising = true;
        _usingNativeAdvertiser = true;
        debugPrint("BLE Advertiser: Native advertising fallback successful!");
        return;
      }
    }

    // Strategy 2: Try with minimal data first
    await _tryMinimalAdvertising(uidShort, gender);
    if (_isAdvertising) return;

    // Strategy 3: Wait and retry with exponential backoff (reduced attempts)
    for (int attempt = 1; attempt <= 2; attempt++) {
      final delay = Duration(
          seconds: attempt * 5); // 5s, 10s - even longer delays for MIUI
      debugPrint(
          "BLE Advertiser: Xiaomi retry attempt $attempt after ${delay.inSeconds}s delay...");

      await Future.delayed(delay);

      try {
        // Ensure we're not advertising before retry
        if (_isAdvertising) {
          await stopAdvertising();
          await Future.delayed(
              const Duration(milliseconds: 2000)); // Even longer wait
        }

        // Try minimal advertising again
        await _tryMinimalAdvertising(uidShort, gender);
        if (_isAdvertising) {
          debugPrint(
              "BLE Advertiser: Xiaomi retry successful on attempt $attempt");
          return;
        }
      } catch (retryError) {
        debugPrint(
            "BLE Advertiser: Xiaomi retry attempt $attempt failed: $retryError");
        if (attempt == 2) {
          // Final attempt failed, try alternative approach
          await _tryAlternativeAdvertising(uidShort, gender);
        }
      }
    }
  }

  // Try minimal advertising data for Xiaomi devices
  Future<void> _tryMinimalAdvertising(String uidShort, int gender) async {
    debugPrint(
        "BLE Advertiser: Trying minimal advertising for Xiaomi device...");

    try {
      // Use only the first 4 bytes of UID to reduce payload size
      String shortUid = uidShort.substring(0, 4);
      Uint8List uidBytes = Uint8List.fromList([
        int.parse(shortUid.substring(0, 2), radix: 16),
        int.parse(shortUid.substring(2, 4), radix: 16),
      ]);
      Uint8List payload = Uint8List.fromList([...uidBytes, gender & 0xFF]);

      final advData = AdvertiseData(
        serviceUuid:
            BluetoothDiscoveryService.DISCOVERY_SERVICE_UUID.toString(),
        manufacturerId: MANUFACTURER_ID_DISCOVERY,
        manufacturerData: payload,
      );

      await _peripheral.start(advertiseData: advData);
      _isAdvertising = true;
      debugPrint("BLE Advertiser: Minimal advertising successful");
    } catch (e) {
      debugPrint("BLE Advertiser: Minimal advertising failed: $e");
      _isAdvertising = false;
    }
  }

  // Alternative advertising approach for problematic devices
  Future<void> _tryAlternativeAdvertising(String uidShort, int gender) async {
    debugPrint("BLE Advertiser: Trying alternative advertising approach...");

    try {
      // Use a different manufacturer ID to avoid conflicts
      const int alternativeManufacturerId = 0xFFFC;

      // Try with even more minimal data
      String shortUid = uidShort.substring(0, 2); // Only 2 characters
      Uint8List uidBytes = Uint8List.fromList([
        int.parse(shortUid, radix: 16),
      ]);
      Uint8List payload = Uint8List.fromList([...uidBytes, gender & 0xFF]);

      final advData = AdvertiseData(
        serviceUuid:
            BluetoothDiscoveryService.DISCOVERY_SERVICE_UUID.toString(),
        manufacturerId: alternativeManufacturerId,
        manufacturerData: payload,
      );

      await _peripheral.start(advertiseData: advData);
      _isAdvertising = true;
      debugPrint("BLE Advertiser: Alternative advertising approach successful");
    } catch (e) {
      debugPrint("BLE Advertiser: Alternative advertising also failed: $e");
      // Don't set error status - allow scanning-only mode
      _isAdvertising = false;
      debugPrint("BLE Advertiser: Entering scan-only mode for Xiaomi device");
    }
  }

  // Check if device is in scan-only mode (can't advertise)
  bool get isScanOnlyMode => !_isAdvertising;

  Future<void> sendWaveBroadcast(
      String senderUidShort, String targetUidShort) async {
    bool isAdapterOn = await _isAdapterEnabled();
    if (!isAdapterOn) {
      debugPrint("BLE Advertiser: Cannot send wave, adapter off.");
      _statusService.updateStatus(NearbyStatus.adapterOff);
      return;
    }

    // CRITICAL FIX: Check BOTH advertisers (native AND flutter)
    bool wasAdvertisingDiscovery = _isAdvertising;
    bool isFlutterAdvertising = await _peripheral.isAdvertising;
    bool isAnyAdvertising = _isAdvertising || isFlutterAdvertising;

    // ALWAYS stop current advertising before starting wave
    // This ensures clean state regardless of which advertiser is active
    if (isAnyAdvertising) {
      debugPrint(
          "BLE Advertiser: Stopping current advertising before sending wave (Native: $_usingNativeAdvertiser, Flutter: $isFlutterAdvertising)...");
      await stopAdvertising(temporary: true);
      // Allow a brief moment for the stop command to process
      await Future.delayed(const Duration(milliseconds: 300));
    }

    try {
      // MIUI FIX: Try Service Data wave broadcast FIRST for ALL Android devices
      // Service Data bypasses MIUI's aggressive manufacturer data filtering
      // This is now the PRIMARY method for waves, not fallback!
      debugPrint(
          "[BLE Advertiser] Trying Service Data wave broadcast (MIUI-compatible)...");
      bool serviceDataSuccess = await _miuiFix.sendServiceDataWaveBroadcast(
          senderUidShort, targetUidShort);
      if (serviceDataSuccess) {
        debugPrint("[BLE Advertiser] Service Data wave broadcast successful!");

        // Schedule wave stop and discovery restart
        _waveTimer?.cancel();
        _waveTimer = Timer(const Duration(seconds: 3), () async {
          // CRITICAL FIX: Wrap in try-catch to prevent timer failures causing indefinite broadcast
          try {
            debugPrint(
                "[BLE Advertiser] Service Data wave timer complete - stopping");
            await _miuiFix.stopNativeAdvertising();
            _isAdvertising = false;
            _usingNativeAdvertiser = false; // CRITICAL FIX: Reset flag!

            // Call completion callback to restart discovery
            if (onWaveCompleteCallback != null) {
              debugPrint("[BLE Advertiser] Calling wave complete callback");
              await onWaveCompleteCallback!();
            }
          } catch (e) {
            debugPrint("[BLE Advertiser] ERROR in Service Data wave timer: $e");
            // Force stop advertising even on error
            try {
              await _miuiFix.stopNativeAdvertising();
            } catch (stopError) {
              debugPrint(
                  "[BLE Advertiser] ERROR stopping advertising: $stopError");
            }
            _isAdvertising = false;
            _usingNativeAdvertiser =
                false; // CRITICAL FIX: Reset flag even on error!
            // Still call callback to recover state
            if (onWaveCompleteCallback != null) {
              try {
                await onWaveCompleteCallback!();
              } catch (callbackError) {
                debugPrint(
                    "[BLE Advertiser] ERROR in callback: $callbackError");
              }
            }
          }
        });
        return;
      } else {
        debugPrint(
            "[BLE Advertiser] Service Data wave failed, trying manufacturer data fallback...");
      }

      // FALLBACK: Try manufacturer data wave for Xiaomi (old method, may be filtered)
      if (_deviceInfo.isXiaomiDevice) {
        debugPrint(
            "[BLE Advertiser] Trying manufacturer data wave for Xiaomi...");
        bool manufDataSuccess =
            await _miuiFix.sendWaveBroadcast(senderUidShort, targetUidShort);
        if (manufDataSuccess) {
          _waveTimer?.cancel();
          _waveTimer = Timer(const Duration(seconds: 3), () async {
            try {
              debugPrint(
                  "[BLE Advertiser] Manufacturer data wave timer complete - stopping");
              await _miuiFix.stopNativeAdvertising();
              _isAdvertising = false;
              _usingNativeAdvertiser = false; // CRITICAL FIX: Reset flag!
              if (onWaveCompleteCallback != null) {
                debugPrint("[BLE Advertiser] Calling wave complete callback");
                await onWaveCompleteCallback!();
              }
            } catch (e) {
              debugPrint(
                  "[BLE Advertiser] ERROR in Manufacturer data wave timer: $e");
              try {
                await _miuiFix.stopNativeAdvertising();
              } catch (stopError) {
                debugPrint(
                    "[BLE Advertiser] ERROR stopping advertising: $stopError");
              }
              _isAdvertising = false;
              _usingNativeAdvertiser =
                  false; // CRITICAL FIX: Reset flag even on error!
              if (onWaveCompleteCallback != null) {
                try {
                  await onWaveCompleteCallback!();
                } catch (callbackError) {
                  debugPrint(
                      "[BLE Advertiser] ERROR in callback: $callbackError");
                }
              }
            }
          });
          return;
        } else {
          debugPrint(
              "[BLE Advertiser] Manufacturer data wave failed, trying flutter_ble_peripheral...");
        }
      }

      // LAST RESORT: Use flutter_ble_peripheral with Manufacturer Data (FALLBACK ONLY)
      // Build wave payload: senderUID (4 bytes) + targetUID (4 bytes) = 8 bytes
      Uint8List senderBytes = _uidShortToBytes(senderUidShort);
      Uint8List targetBytes = _uidShortToBytes(targetUidShort);
      Uint8List payload = Uint8List.fromList([...senderBytes, ...targetBytes]);

      debugPrint(
          "BLE Advertiser: Wave payload - sender: $senderUidShort, target: $targetUidShort, bytes: $payload");
      debugPrint(
          "BLE Advertiser: WARNING - Using manufacturer data fallback (may be filtered by MIUI)");

      final waveAdvData = AdvertiseData(
        serviceUuid:
            BluetoothDiscoveryService.DISCOVERY_SERVICE_UUID.toString(),
        manufacturerId: MANUFACTURER_ID_WAVE,
        manufacturerData: payload,
      );

      debugPrint(
          "BLE Advertiser: Sending Wave Broadcast (Manufacturer Data Fallback) for 3 seconds...");
      // Start wave advertising
      await _peripheral.start(advertiseData: waveAdvData);

      // Use a timer to stop the wave advertisement after 3 seconds
      _waveTimer?.cancel();
      _waveTimer = Timer(const Duration(seconds: 3), () async {
        // CRITICAL FIX: Wrap entire timer in try-catch
        try {
          debugPrint("[BLE Advertiser] Flutter wave timer complete - stopping");
          if (await _peripheral.isAdvertising) {
            await _peripheral.stop();
          }
          _isAdvertising = false;

          // Call completion callback to restart discovery
          if (onWaveCompleteCallback != null) {
            debugPrint("[BLE Advertiser] Calling wave complete callback");
            await onWaveCompleteCallback!();
          }
        } catch (e) {
          debugPrint("[BLE Advertiser] ERROR in Flutter wave timer: $e");
          // Force stop
          try {
            await _peripheral.stop();
          } catch (stopError) {
            debugPrint(
                "[BLE Advertiser] ERROR stopping flutter peripheral: $stopError");
          }
          _isAdvertising = false;
          // Still call callback to recover state
          if (onWaveCompleteCallback != null) {
            try {
              await onWaveCompleteCallback!();
            } catch (callbackError) {
              debugPrint("[BLE Advertiser] ERROR in callback: $callbackError");
            }
          }
        }
      });
    } catch (e) {
      debugPrint("BLE Advertiser: Error sending wave broadcast: $e");
      _statusService.updateStatus(NearbyStatus.error);
      // Ensure state is reset and attempt restart if needed
      _isAdvertising = false;
      if (wasAdvertisingDiscovery) {
        debugPrint(
            "BLE Advertiser: Attempting to restart regular advertising after wave failure.");
        // Restart logic might be external
      }
    }
  }

  Future<void> stopAdvertising({bool temporary = false}) async {
    _waveTimer?.cancel(); // Always cancel wave timer on any stop request

    // Stop native advertiser if that's what we're using
    if (_usingNativeAdvertiser) {
      debugPrint("BLE Advertiser: Stopping native advertiser...");
      await _miuiFix.stopNativeAdvertising();
      if (!temporary) {
        _isAdvertising = false;
        _usingNativeAdvertiser = false;
      }
      return;
    }

    bool isCurrentlyAdvertising;
    try {
      isCurrentlyAdvertising = await _peripheral.isAdvertising;
    } catch (e) {
      debugPrint(
          "BLE Advertiser: Error checking advertising state during stop: $e. Assuming not advertising.");
      isCurrentlyAdvertising = false; // Assume not advertising if check fails
    }

    if (!isCurrentlyAdvertising) {
      // If peripheral says not advertising, ensure internal state matches
      if (_isAdvertising) {
        debugPrint(
            "BLE Advertiser: Was marked as advertising but peripheral says stopped.");
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
