import 'package:equatable/equatable.dart';

abstract class RandomChatEvent extends Equatable {
  const RandomChatEvent();

  @override
  List<Object?> get props => [];
}

// Aliases for user requested events
class RandomChatJoinQueue extends RandomChatEvent {} // Same as EnterMatchTab

class RandomChatMatchFound extends RandomChatEvent {} // Triggered by socket

class RandomChatEnterMatchTab extends RandomChatEvent {}

class RandomChatSwipeNext extends RandomChatEvent {}

class RandomChatLeaveMatchTab extends RandomChatEvent {}

class RandomChatToggleBlur extends RandomChatEvent {}

// Internal events from Service listeners
class RandomChatConnectionStateChanged extends RandomChatEvent {
  final String status;
  const RandomChatConnectionStateChanged(this.status);

  @override
  List<Object?> get props => [status];
}

class RandomChatRemoteStreamChanged extends RandomChatEvent {
  // We can pass the stream or just trigger a refresh,
  // since the stream is in the service.
  // Passing it ensures the state has the reference.
  final dynamic stream;
  const RandomChatRemoteStreamChanged(this.stream);

  @override
  List<Object?> get props => [stream];
}
