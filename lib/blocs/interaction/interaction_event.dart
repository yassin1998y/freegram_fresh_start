import 'package:equatable/equatable.dart';
import 'package:freegram/models/gift_model.dart';

abstract class InteractionEvent extends Equatable {
  const InteractionEvent();

  @override
  List<Object?> get props => [];
}

class SendGiftEvent extends InteractionEvent {
  final GiftModel gift;
  const SendGiftEvent(this.gift);

  @override
  List<Object?> get props => [gift];
}

class SendMessageEvent extends InteractionEvent {
  final String text;
  const SendMessageEvent(this.text);

  @override
  List<Object?> get props => [text];
}

class SendFriendRequestEvent extends InteractionEvent {}

class BlockUserEvent extends InteractionEvent {
  final String userId;
  const BlockUserEvent(this.userId);
  @override
  List<Object?> get props => [userId];
}

class ReportUserEvent extends InteractionEvent {
  final String userId;
  final String reason;
  final String category; // 'spam', 'harassment', etc.
  const ReportUserEvent({
    required this.userId,
    required this.reason,
    required this.category,
  });
  @override
  List<Object?> get props => [userId, reason, category];
}

// Internal: Incoming events from Data Channel
class IncomingInteractionEvent extends InteractionEvent {
  final Map<String, dynamic> data;
  const IncomingInteractionEvent(this.data);

  @override
  List<Object?> get props => [data];
}
