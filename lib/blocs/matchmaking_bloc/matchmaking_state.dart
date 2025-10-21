part of 'matchmaking_bloc.dart';

@immutable
abstract class MatchmakingState extends Equatable {
  const MatchmakingState();

  @override
  List<Object> get props => [];
}

class MatchmakingInitial extends MatchmakingState {}

class MatchmakingSearching extends MatchmakingState {
  final String gameId;
  const MatchmakingSearching(this.gameId);

  @override
  List<Object> get props => [gameId];
}

class MatchmakingSuccess extends MatchmakingState {
  final GameSession gameSession;
  const MatchmakingSuccess(this.gameSession);

  @override
  List<Object> get props => [gameSession];
}

class MatchmakingError extends MatchmakingState {
  final String message;
  const MatchmakingError(this.message);
  @override
  List<Object> get props => [message];
}

