part of 'matchmaking_bloc.dart';

@immutable
abstract class MatchmakingEvent extends Equatable {
  const MatchmakingEvent();

  @override
  List<Object> get props => [];
}

class FindGame extends MatchmakingEvent {}

class CancelSearch extends MatchmakingEvent {}

class _GameStatusChanged extends MatchmakingEvent {
  final GameSession gameSession;
  const _GameStatusChanged(this.gameSession);

  @override
  List<Object> get props => [gameSession];
}

