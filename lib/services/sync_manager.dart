import 'dart:async';
import 'package:flutter/material.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/action_queue_repository.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/repositories/user_repository.dart';

class SyncManager {
  final ConnectivityBloc _connectivityBloc;
  final ActionQueueRepository _actionQueueRepository = locator<ActionQueueRepository>();
  final UserRepository _userRepository = locator<UserRepository>();
  final ChatRepository _chatRepository = locator<ChatRepository>();

  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  SyncManager({required ConnectivityBloc connectivityBloc})
      : _connectivityBloc = connectivityBloc {
    _connectivitySubscription = _connectivityBloc.stream.listen((state) {
      if (state is Online) {
        processQueue();
      }
    });
  }

  Future<void> processQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;
    debugPrint("SyncManager: Internet connection detected. Starting sync process...");

    final actions = _actionQueueRepository.getQueuedActions();
    if (actions.isEmpty) {
      debugPrint("SyncManager: Action queue is empty. Nothing to sync.");
      _isSyncing = false;
      return;
    }

    debugPrint("SyncManager: Found ${actions.length} actions to sync.");

    for (final action in actions) {
      final String actionId = action['id'];
      final String type = action['type'];
      final Map<String, dynamic> payload = Map<String, dynamic>.from(action['payload']);

      try {
        switch (type) {
          case 'send_friend_request':
            await _userRepository.sendFriendRequest(
              payload['fromUserId'],
              payload['toUserId'],
              isSync: true, // Pass flag to prevent re-queuing
            );
            break;
          case 'accept_friend_request':
            await _userRepository.acceptFriendRequest(
              payload['currentUserId'],
              payload['requestingUserId'],
              isSync: true,
            );
            break;
          case 'send_online_message':
          // The chat repo's send method already handles online sending
            await _chatRepository.sendMessage(
              chatId: payload['chatId'],
              senderId: payload['senderId'],
              text: payload['text'],
              // Add other message fields if needed
            );
            break;
        }
        // If the action was successful, remove it from the queue
        await _actionQueueRepository.removeAction(actionId);
        debugPrint("SyncManager: Successfully synced and removed action $actionId.");
      } catch (e) {
        debugPrint("SyncManager: Failed to sync action $actionId. Error: $e. It will be retried on next connection.");
        // Optionally, implement a retry limit or error logging here
      }
    }

    debugPrint("SyncManager: Sync process finished.");
    _isSyncing = false;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}