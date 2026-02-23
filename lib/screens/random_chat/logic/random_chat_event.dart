import 'package:equatable/equatable.dart';

abstract class RandomChatEvent extends Equatable {
  const RandomChatEvent();

  @override
  List<Object?> get props => [];
}

// --- New Lifecycle and UI Toggle Events ---

class RandomChatStartSearching extends RandomChatEvent {
  const RandomChatStartSearching();
}

class RandomChatStopSearching extends RandomChatEvent {
  const RandomChatStopSearching();
}

class RandomChatToggleLocalCamera extends RandomChatEvent {
  const RandomChatToggleLocalCamera();
}

class RandomChatToggleLocalMic extends RandomChatEvent {
  const RandomChatToggleLocalMic();
}

class RandomChatRemoteMediaChanged extends RandomChatEvent {
  final bool isCameraOff;
  final bool isMicOff;

  const RandomChatRemoteMediaChanged({
    required this.isCameraOff,
    required this.isMicOff,
  });

  @override
  List<Object?> get props => [isCameraOff, isMicOff];
}

class RandomChatAppBackgrounded extends RandomChatEvent {
  const RandomChatAppBackgrounded();
}

class RandomChatRoutePushed extends RandomChatEvent {
  const RandomChatRoutePushed();
}

class RandomChatRoutePopped extends RandomChatEvent {
  const RandomChatRoutePopped();
}

// --- Existing Events (Keeping for compatibility until Bloc is refactored) ---

class RandomChatJoinQueue extends RandomChatEvent {
  const RandomChatJoinQueue();
}

class RandomChatMatchFound extends RandomChatEvent {
  const RandomChatMatchFound();
}

class InitializeGatedScreen extends RandomChatEvent {
  const InitializeGatedScreen();
}

class RandomChatEnterMatchTab extends RandomChatEvent {
  const RandomChatEnterMatchTab();
}

class RandomChatSwipeNext extends RandomChatEvent {
  const RandomChatSwipeNext();
}

class RandomChatLeaveMatchTab extends RandomChatEvent {
  const RandomChatLeaveMatchTab();
}

class RandomChatToggleBlur extends RandomChatEvent {
  const RandomChatToggleBlur();
}

class RandomChatToggleMic extends RandomChatEvent {
  const RandomChatToggleMic();
}

class RandomChatToggleCamera extends RandomChatEvent {
  const RandomChatToggleCamera();
}

class RandomChatSetFilter extends RandomChatEvent {
  final String? gender;
  final String? region;
  const RandomChatSetFilter({this.gender, this.region});

  @override
  List<Object?> get props => [gender, region];
}

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
