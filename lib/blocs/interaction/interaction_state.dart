import 'package:equatable/equatable.dart';
import 'package:freegram/models/gift_model.dart';

abstract class InteractionState extends Equatable {
  const InteractionState();

  @override
  List<Object?> get props => [];
}

class InteractionInitial extends InteractionState {}

class GiftReceivedState extends InteractionState {
  final GiftModel gift;
  final String senderName;
  final DateTime timestamp;

  GiftReceivedState({
    required this.gift,
    required this.senderName,
  }) : timestamp = DateTime.now();

  @override
  List<Object?> get props => [gift, senderName, timestamp];
}

class ChatReceivedState extends InteractionState {
  final String text;
  final String senderName;
  final DateTime timestamp;

  ChatReceivedState({
    required this.text,
    required this.senderName,
  }) : timestamp = DateTime.now();

  @override
  List<Object?> get props => [text, senderName, timestamp];
}

class FriendRequestReceivedState extends InteractionState {
  final String senderName;
  FriendRequestReceivedState(this.senderName);

  @override
  List<Object?> get props => [senderName];
}
