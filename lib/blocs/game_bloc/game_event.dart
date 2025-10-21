part of 'game_bloc.dart';

@immutable
abstract class GameEvent extends Equatable {
  const GameEvent();

  @override
  List<Object?> get props => [];
}

/// Starts listening to the game session stream from Firestore.
class LoadGame extends GameEvent {}

/// Event triggered when a player swaps two gems.
class SwapGems extends GameEvent {
  final Point<int> from;
  final Point<int> to;

  const SwapGems({required this.from, required this.to});

  @override
  List<Object> get props => [from, to];
}

class UseHammerOnGem extends GameEvent {
  final Point<int> target;

  const UseHammerOnGem({required this.target});

  @override
  List<Object> get props => [target];
}
/// Event triggered when a player activates their booster.
class ActivateBooster extends GameEvent {}

/// Event triggered when a player activates a perk.
class ActivatePerk extends GameEvent {
  final PerkType perkType;
  const ActivatePerk(this.perkType);

  @override
  List<Object> get props => [perkType];
}

/// NEW: Event triggered by the UI timer when a player's turn expires.
class EndTurnByTimer extends GameEvent {}

/// Internal event triggered by the Firestore stream.
class _GameUpdated extends GameEvent {
  final GameSession gameSession;
  final Set<Point<int>>? clearedGems; // Pass cleared gems for animation

  const _GameUpdated(this.gameSession, {this.clearedGems});

  @override
  List<Object?> get props => [gameSession, clearedGems];
}

