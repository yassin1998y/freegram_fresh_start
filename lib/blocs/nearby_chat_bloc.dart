// lib/blocs/nearby_chat_bloc.dart

import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/models/nearby_message.dart';
import 'package:freegram/repositories/nearby_chat_repository.dart';

part 'nearby_chat_event.dart';
part 'nearby_chat_state.dart';

class NearbyChatBloc extends Bloc<NearbyChatEvent, NearbyChatState> {
  final NearbyChatRepository _nearbyChatRepository;
  final String chatId;
  final String deviceAddress;
  late final ValueNotifier<List<NearbyMessage>> _messageNotifier;

  NearbyChatBloc({
    required NearbyChatRepository nearbyChatRepository,
    required this.chatId,
    required this.deviceAddress,
  })  : _nearbyChatRepository = nearbyChatRepository,
        super(NearbyChatLoading()) {
    on<LoadMessages>(_onLoadMessages);
    on<SendMessage>(_onSendMessage);
    on<_MessagesUpdated>(_onMessagesUpdated);

    _messageNotifier = _nearbyChatRepository.getChatMessagesNotifier(chatId);
    _nearbyChatRepository.listenToChatUpdates(chatId, _messageNotifier);
    _messageNotifier.addListener(() {
      add(_MessagesUpdated(_messageNotifier.value));
    });
  }

  void _onLoadMessages(LoadMessages event, Emitter<NearbyChatState> emit) {
    emit(NearbyChatLoaded(messages: _messageNotifier.value));
  }

  Future<void> _onSendMessage(
      SendMessage event, Emitter<NearbyChatState> emit) async {
    // For now, this logic is disabled. We can still save locally if we want.
    // final myId = FirebaseAuth.instance.currentUser!.uid;
    // final recipientId = chatId.replaceAll(myId, '').replaceAll('_', '');
    // await _nearbyChatRepository.sendMessage(recipientId, deviceAddress, event.text);
    debugPrint("Sending messages is temporarily disabled.");
  }

  void _onMessagesUpdated(
      _MessagesUpdated event, Emitter<NearbyChatState> emit) {
    emit(NearbyChatLoaded(messages: event.messages));
  }

  @override
  Future<void> close() {
    _messageNotifier.dispose();
    return super.close();
  }
}
