import 'package:equatable/equatable.dart';

abstract class RandomChatEvent extends Equatable {
  const RandomChatEvent();

  @override
  List<Object?> get props => [];
}

// Aliases for user requested events
class RandomChatJoinQueue extends RandomChatEvent {}

class RandomChatMatchFound extends RandomChatEvent {}

class InitializeGatedScreen extends RandomChatEvent {}

class RandomChatEnterMatchTab extends RandomChatEvent {}

class RandomChatSwipeNext extends RandomChatEvent {}

class RandomChatLeaveMatchTab extends RandomChatEvent {}

class RandomChatToggleBlur extends RandomChatEvent {}

class RandomChatToggleMic extends RandomChatEvent {}

class RandomChatToggleCamera extends RandomChatEvent {}

class RandomChatSetFilter extends RandomChatEvent {
  final String? gender;
  final String? region;

  const RandomChatSetFilter({this.gender, this.region});

  @override
  List<Object?> get props => [gender, region];
}

// Internal events from Service listeners
class RandomChatConnectionStateChanged extends RandomChatEvent {
  final String status;
  const RandomChatConnectionStateChanged(this.status);

  @override
  List<Object?> get props => [status];
}

class RandomChatRemoteStreamChanged extends RandomChatEvent {
  final dynamic stream;
  const RandomChatRemoteStreamChanged(this.stream);

  @override
  List<Object?> get props => [stream];
}

class RandomChatNewMessage extends RandomChatEvent {
  final String message;
  const RandomChatNewMessage(this.message);

  @override
  List<Object?> get props => [message];
}

class RandomChatMediaStateChanged extends RandomChatEvent {
  final bool isMicOn;
  final bool isCameraOn;
  const RandomChatMediaStateChanged(
      {required this.isMicOn, required this.isCameraOn});

  @override
  List<Object?> get props => [isMicOn, isCameraOn];
}
