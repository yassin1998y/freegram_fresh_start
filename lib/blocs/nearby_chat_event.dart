// lib/blocs/nearby_chat_event.dart

part of 'nearby_chat_bloc.dart';

abstract class NearbyChatEvent extends Equatable {
  const NearbyChatEvent();

  @override
  List<Object> get props => [];
}

class LoadMessages extends NearbyChatEvent {}

class SendMessage extends NearbyChatEvent {
  final String text;

  const SendMessage({required this.text});

  @override
  List<Object> get props => [text];
}

class _MessagesUpdated extends NearbyChatEvent {
  final List<NearbyMessage> messages;

  const _MessagesUpdated(this.messages);

  @override
  List<Object> get props => [messages];
}