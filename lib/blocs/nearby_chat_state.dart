part of 'nearby_chat_bloc.dart';

abstract class NearbyChatState extends Equatable {
  const NearbyChatState();

  @override
  List<Object> get props => [];
}

class NearbyChatLoading extends NearbyChatState {}

class NearbyChatLoaded extends NearbyChatState {
  final List<NearbyMessage> messages;

  const NearbyChatLoaded({required this.messages});

  @override
  List<Object> get props => [messages];
}
