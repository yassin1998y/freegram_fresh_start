// lib/services/sonar/wave_manager.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Professional Wave Management System (SINGLETON)
/// Handles wave sending/receiving with proper state management, queuing, and cooldowns
/// CRITICAL: This is a singleton - only ONE instance exists across the entire app
class WaveManager {
  // Singleton pattern - ensures all services share the same WaveManager instance
  static final WaveManager _instance = WaveManager._internal();
  factory WaveManager() => _instance;
  WaveManager._internal() {
    debugPrint("[WaveManager] Singleton instance created");
  }

  // Wave states
  WaveState _currentState = WaveState.idle;
  WaveState get currentState => _currentState;

  // Wave queue for handling multiple wave requests
  final List<WaveRequest> _waveQueue = [];
  bool _isProcessingQueue = false;

  // Cooldown management
  final Map<String, DateTime> _sendCooldowns = {}; // targetId -> last send time
  final Map<String, DateTime> _receiveCooldowns =
      {}; // senderId -> last receive time
  static const Duration _sendCooldownDuration = Duration(seconds: 5);
  static const Duration _receiveCooldownDuration = Duration(seconds: 3);

  // Wave timing is now managed by BleAdvertiser (3 second broadcast + callbacks)
  // Removed unused timing constants: _waveBroadcastDuration, _restartDelay

  // State change stream
  final StreamController<WaveState> _stateController =
      StreamController<WaveState>.broadcast();
  Stream<WaveState> get stateStream => _stateController.stream;

  // Callbacks
  Function(String senderUidShort, String targetUidShort)? onWaveSendRequested;
  Function()? onWaveComplete;

  /// Initialize the wave manager with callbacks
  void initialize({
    required Function(String senderUidShort, String targetUidShort) onWaveSend,
    required Function() onWaveComplete,
  }) {
    onWaveSendRequested = onWaveSend;
    this.onWaveComplete = onWaveComplete;
    debugPrint("[WaveManager] Initialized");
  }

  /// Check if a wave can be sent to a specific target
  bool canSendWaveTo(String targetUidShort) {
    // Check current state
    if (_currentState == WaveState.sending) {
      debugPrint(
          "[WaveManager] Cannot send wave - currently sending another wave");
      return false;
    }

    // Check cooldown
    if (_sendCooldowns.containsKey(targetUidShort)) {
      final lastSendTime = _sendCooldowns[targetUidShort]!;
      final timeSinceLastSend = DateTime.now().difference(lastSendTime);
      if (timeSinceLastSend < _sendCooldownDuration) {
        final remainingCooldown = _sendCooldownDuration - timeSinceLastSend;
        debugPrint(
            "[WaveManager] Wave to $targetUidShort on cooldown (${remainingCooldown.inSeconds}s remaining)");
        return false;
      }
    }

    return true;
  }

  /// Check if a wave can be received from a specific sender
  bool canReceiveWaveFrom(String senderUidShort) {
    // Check cooldown
    if (_receiveCooldowns.containsKey(senderUidShort)) {
      final lastReceiveTime = _receiveCooldowns[senderUidShort]!;
      final timeSinceLastReceive = DateTime.now().difference(lastReceiveTime);
      if (timeSinceLastReceive < _receiveCooldownDuration) {
        debugPrint(
            "[WaveManager] Wave from $senderUidShort ignored (cooldown)");
        return false;
      }
    }

    return true;
  }

  /// Request to send a wave (adds to queue if busy)
  Future<bool> sendWave({
    required String senderUidShort,
    required String targetUidShort,
  }) async {
    debugPrint(
        "[WaveManager] Wave send requested: $senderUidShort → $targetUidShort");

    // Validation
    if (senderUidShort.isEmpty || targetUidShort.isEmpty) {
      debugPrint("[WaveManager] Invalid wave request - empty IDs");
      return false;
    }

    if (senderUidShort == targetUidShort) {
      debugPrint("[WaveManager] Cannot send wave to self");
      return false;
    }

    // Check if can send
    if (!canSendWaveTo(targetUidShort)) {
      return false;
    }

    // Create wave request
    final request = WaveRequest(
      senderUidShort: senderUidShort,
      targetUidShort: targetUidShort,
      timestamp: DateTime.now(),
    );

    // Add to queue
    _waveQueue.add(request);
    debugPrint(
        "[WaveManager] Wave added to queue (queue size: ${_waveQueue.length})");

    // Process queue
    _processQueue();

    return true;
  }

  /// Process the wave queue
  Future<void> _processQueue() async {
    if (_isProcessingQueue || _waveQueue.isEmpty) {
      return;
    }

    _isProcessingQueue = true;

    while (_waveQueue.isNotEmpty) {
      final request = _waveQueue.removeAt(0);

      // Double-check cooldown before processing
      if (!canSendWaveTo(request.targetUidShort)) {
        debugPrint("[WaveManager] Skipping wave - cooldown not expired");
        continue;
      }

      await _executeWaveSend(request);

      // Wait between waves if queue has more
      if (_waveQueue.isNotEmpty) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    _isProcessingQueue = false;
  }

  /// Execute a wave send operation
  Future<void> _executeWaveSend(WaveRequest request) async {
    try {
      // Update state
      _updateState(WaveState.sending);

      // Record cooldown
      _sendCooldowns[request.targetUidShort] = DateTime.now();

      debugPrint(
          "[WaveManager] Executing wave: ${request.senderUidShort} → ${request.targetUidShort}");

      // Call the actual wave send callback
      // CRITICAL FIX: The callback now handles its own timing and will call onWaveComplete when done
      // We do NOT wait here - let the advertiser control the timing!
      if (onWaveSendRequested != null) {
        await onWaveSendRequested!(
            request.senderUidShort, request.targetUidShort);
      }

      // REMOVED: await Future.delayed(_waveBroadcastDuration);
      // The advertiser's timer will call onWaveComplete when the wave is actually done
      debugPrint(
          "[WaveManager] Wave broadcast initiated, waiting for completion callback...");
    } catch (e) {
      debugPrint("[WaveManager] Error executing wave: $e");
      _updateState(WaveState.error);
      await Future.delayed(const Duration(milliseconds: 500));
      _updateState(WaveState.idle);
    }
  }

  /// Complete wave operation (called by advertiser when wave actually stops)
  Future<void> completeCurrentWave() async {
    debugPrint("[WaveManager] Wave confirmed complete by advertiser");

    // Update state to restarting
    _updateState(WaveState.restarting);

    // Brief delay before returning to idle
    await Future.delayed(const Duration(milliseconds: 300));

    // Return to idle - ready for next wave
    _updateState(WaveState.idle);

    debugPrint("[WaveManager] Ready for next wave");
  }

  /// Record a received wave (with cooldown)
  void recordReceivedWave(String senderUidShort) {
    if (!canReceiveWaveFrom(senderUidShort)) {
      return;
    }

    _receiveCooldowns[senderUidShort] = DateTime.now();
    debugPrint("[WaveManager] Recorded received wave from $senderUidShort");
  }

  /// Update state and notify listeners
  void _updateState(WaveState newState) {
    if (_currentState == newState) return;

    _currentState = newState;
    _stateController.add(newState);
    debugPrint("[WaveManager] State changed: $newState");
  }

  /// Clear all cooldowns (useful for testing or reset)
  void clearCooldowns() {
    _sendCooldowns.clear();
    _receiveCooldowns.clear();
    debugPrint("[WaveManager] All cooldowns cleared");
  }

  /// Get remaining cooldown time for a target
  Duration? getRemainingCooldown(String targetUidShort) {
    if (!_sendCooldowns.containsKey(targetUidShort)) {
      return null;
    }

    final lastSendTime = _sendCooldowns[targetUidShort]!;
    final timeSinceLastSend = DateTime.now().difference(lastSendTime);
    final remaining = _sendCooldownDuration - timeSinceLastSend;

    return remaining.isNegative ? null : remaining;
  }

  /// Check if wave system is busy
  bool get isBusy =>
      _currentState == WaveState.sending ||
      _currentState == WaveState.restarting;

  /// Get queue size
  int get queueSize => _waveQueue.length;

  /// Dispose
  void dispose() {
    _stateController.close();
    _waveQueue.clear();
    _sendCooldowns.clear();
    _receiveCooldowns.clear();
    debugPrint("[WaveManager] Disposed");
  }
}

/// Wave states
enum WaveState {
  idle, // Ready to send waves
  sending, // Currently sending a wave
  restarting, // Restarting discovery after wave
  error, // Error state
}

/// Wave request data
class WaveRequest {
  final String senderUidShort;
  final String targetUidShort;
  final DateTime timestamp;

  WaveRequest({
    required this.senderUidShort,
    required this.targetUidShort,
    required this.timestamp,
  });

  @override
  String toString() =>
      'WaveRequest($senderUidShort → $targetUidShort at $timestamp)';
}
