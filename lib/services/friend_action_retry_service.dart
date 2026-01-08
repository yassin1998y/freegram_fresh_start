// lib/services/friend_action_retry_service.dart
// ⭐ PHASE 5: RELIABILITY - Auto-Retry Failed Friend Requests

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/repositories/action_queue_repository.dart';
import 'package:freegram/repositories/friend_repository.dart';

class FriendActionRetryService {
  final FriendRepository _friendRepository;
  final ActionQueueRepository _actionQueue;
  final Connectivity _connectivity;

  Timer? _retryTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  FriendActionRetryService({
    required FriendRepository friendRepository,
    required ActionQueueRepository actionQueue,
    Connectivity? connectivity,
  })  : _friendRepository = friendRepository,
        _actionQueue = actionQueue,
        _connectivity = connectivity ?? Connectivity();

  /// Initialize the retry service - starts monitoring connectivity
  void initialize() {
    debugPrint('[FriendActionRetryService] Initializing...');

    // Listen to connectivity changes and process queue when online
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      // Check if we have any connection other than none
      if (result != ConnectivityResult.none) {
        debugPrint(
            '[FriendActionRetryService] Network detected, processing queue...');
        _processQueue();
      }
    });

    // Also process queue immediately on initialization
    _processQueue();

    // Start periodic retry timer (every 2 minutes)
    _retryTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      debugPrint('[FriendActionRetryService] Periodic retry check...');
      _processQueue();
    });
  }

  /// Process all queued actions
  Future<void> _processQueue() async {
    final queuedActions = _actionQueue.getQueuedActions();

    if (queuedActions.isEmpty) {
      if (kDebugMode) {
        debugPrint('[FriendActionRetryService] Queue is empty');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
          '[FriendActionRetryService] Processing ${queuedActions.length} queued actions...');
    }

    // Bug #17 fix: Sort actions by timestamp to maintain FIFO order
    queuedActions.sort((a, b) {
      final aTime = a['timestamp'] as int? ?? 0;
      final bTime = b['timestamp'] as int? ?? 0;
      return aTime.compareTo(bTime);
    });

    for (final action in queuedActions) {
      try {
        final type = action['type'] as String;
        final payload = Map<String, dynamic>.from(action['payload'] as Map);
        final actionId = action['id'] as String;

        debugPrint('[FriendActionRetryService] Retrying action: $type');

        switch (type) {
          case 'sendFriendRequest':
            await _friendRepository.sendFriendRequest(
              payload['currentUserId'] as String,
              payload['targetUserId'] as String,
              message: payload['message'] as String?,
            );
            break;

          case 'acceptFriendRequest':
            await _friendRepository.acceptFriendRequest(
              payload['currentUserId'] as String,
              payload['requestingUserId'] as String,
            );
            break;

          case 'declineFriendRequest':
            await _friendRepository.declineFriendRequest(
              payload['currentUserId'] as String,
              payload['requestingUserId'] as String,
            );
            break;

          case 'cancelFriendRequest':
            await _friendRepository.cancelFriendRequest(
              payload['currentUserId'] as String,
              payload['targetUserId'] as String,
            );
            break;

          case 'removeFriend':
            await _friendRepository.removeFriend(
              payload['currentUserId'] as String,
              payload['friendId'] as String,
            );
            break;

          case 'blockUser':
            await _friendRepository.blockUser(
              payload['currentUserId'] as String,
              payload['userToBlockId'] as String,
            );
            break;

          case 'unblockUser':
            await _friendRepository.unblockUser(
              payload['currentUserId'] as String,
              payload['userToUnblockId'] as String,
            );
            break;

          default:
            debugPrint('[FriendActionRetryService] Unknown action type: $type');
        }

        // Successfully processed - remove from queue
        await _actionQueue.removeAction(actionId);
        debugPrint(
            '[FriendActionRetryService] ✅ Action $type completed and removed from queue');
      } catch (e) {
        debugPrint('[FriendActionRetryService] ❌ Action retry failed: $e');
        // Keep in queue for next retry
      }
    }
  }

  /// Manually trigger queue processing
  Future<void> processNow() async {
    await _processQueue();
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
    _connectivitySubscription?.cancel();
    debugPrint('[FriendActionRetryService] Disposed');
  }
}
