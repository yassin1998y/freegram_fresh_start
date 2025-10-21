// lib/repositories/nearby_chat_repository.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/nearby_message.dart';
import 'package:freegram/services/bluetooth_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class NearbyChatRepository {
  final BluetoothService _bluetoothService = locator<BluetoothService>();
  late final Box<List<dynamic>> _chatBox;
  StreamSubscription? _messageSubscription;
  Timer? _cleanupTimer;

  static const String waveCommand = '__WAVE__';
  final Duration messageRetentionPeriod = const Duration(hours: 48);

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(NearbyMessageAdapter());
    }
    _chatBox = await Hive.openBox<List<dynamic>>('nearby_chats');
    _listenForIncomingMessages();
    _startCleanupTimer();
  }

  void _listenForIncomingMessages() {
    // This stream no longer exists on the simplified service, so we comment out the listener.
    /*
    _messageSubscription = _bluetoothService.incomingMessagesStream.listen((messageData) {
      final String senderId = messageData['senderId'] ?? 'unknown';
      final String text = messageData['message'] ?? '';
      final String myId = _bluetoothService.getCurrentUserId() ?? '';

      if (text == waveCommand) {
        _handleIncomingWave(senderId);
      } else {
        _saveMessage(
          senderId: senderId,
          recipientId: myId,
          text: text,
        );
      }
    });
    */
  }

  void _handleIncomingWave(String fromUserId) {
    debugPrint("Received a wave from $fromUserId!");
  }

  Future<void> sendMessage(String recipientId, String deviceAddress, String text) async {
    final myId = _bluetoothService.getCurrentUserId();
    if (myId == null) return;

    await _saveMessage(
      senderId: myId,
      recipientId: recipientId,
      text: text,
    );
    // COMMENTED OUT to fix compilation error
    // await _bluetoothService.sendMessage(deviceAddress, text);
  }

  Future<void> sendWave(String deviceAddress) async {
    // COMMENTED OUT to fix compilation error
    // await _bluetoothService.sendWave(deviceAddress);
  }

  Future<void> _saveMessage({
    required String senderId,
    required String recipientId,
    required String text,
  }) async {
    final ids = [senderId, recipientId]..sort();
    final chatId = ids.join('_');

    final newMessage = NearbyMessage(
      id: const Uuid().v4(),
      chatId: chatId,
      text: text,
      senderId: senderId,
      recipientId: recipientId,
      timestamp: DateTime.now(),
    );

    final chatHistory = _chatBox.get(chatId)?.cast<NearbyMessage>().toList() ?? [];
    chatHistory.add(newMessage);
    await _chatBox.put(chatId, chatHistory);
  }

  ValueNotifier<List<NearbyMessage>> getChatMessagesNotifier(String chatId) {
    final messages = _chatBox.get(chatId)?.cast<NearbyMessage>().toList() ?? [];
    return ValueNotifier(messages);
  }

  void listenToChatUpdates(String chatId, ValueNotifier<List<NearbyMessage>> notifier) {
    _chatBox.listenable(keys: [chatId]).addListener(() {
      notifier.value = _chatBox.get(chatId)?.cast<NearbyMessage>().toList() ?? [];
    });
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _deleteOldMessages();
    });
    _deleteOldMessages();
  }

  Future<void> _deleteOldMessages() async {
    final now = DateTime.now();
    final allChatIds = _chatBox.keys.toList();

    for (final chatId in allChatIds) {
      final messages = _chatBox.get(chatId)?.cast<NearbyMessage>().toList() ?? [];
      if (messages.isEmpty) continue;

      final recentMessages = messages.where((msg) {
        return now.difference(msg.timestamp) < messageRetentionPeriod;
      }).toList();

      if (recentMessages.isEmpty) {
        await _chatBox.delete(chatId);
      } else if (recentMessages.length < messages.length) {
        await _chatBox.put(chatId, recentMessages);
      }
    }
  }

  void dispose() {
    _messageSubscription?.cancel();
    _cleanupTimer?.cancel();
  }
}