part of 'game_bloc.dart';

enum AnimationEffect { arrow, bomb, lightning, score, creation, invalidSwap }

class AnimationDetails extends Equatable {
  final Point<int> swapFrom;
  final Point<int> swapTo;
  final List<Set<Point<int>>> clearedGems; // Waves of cleared gems
  final Map<Point<int>, Point<int>> cascadedGems; // Map<from, to>
  final List<List<GameTile>> finalBoard; // Final state after all logic
  final Map<Point<int>, GameTile> newGems; // Newly created gems at specific points
  final AnimationEffect? specialEffect;
  final Point<int>? specialEffectOrigin;
  final List<Point<int>>? specialEffectTargets;

  const AnimationDetails({
    this.swapFrom = const Point(-1, -1),
    this.swapTo = const Point(-1, -1),
    this.clearedGems = const [],
    this.cascadedGems = const {},
    required this.finalBoard,
    this.newGems = const {},
    this.specialEffect,
    this.specialEffectOrigin,
    this.specialEffectTargets,
  });

  // FIX: Added the missing copyWith method
  AnimationDetails copyWith({
    Point<int>? swapFrom,
    Point<int>? swapTo,
    List<Set<Point<int>>>? clearedGems,
    Map<Point<int>, Point<int>>? cascadedGems,
    List<List<GameTile>>? finalBoard,
    Map<Point<int>, GameTile>? newGems,
    AnimationEffect? specialEffect,
    Point<int>? specialEffectOrigin,
    List<Point<int>>? specialEffectTargets,
  }) {
    return AnimationDetails(
      swapFrom: swapFrom ?? this.swapFrom,
      swapTo: swapTo ?? this.swapTo,
      clearedGems: clearedGems ?? this.clearedGems,
      cascadedGems: cascadedGems ?? this.cascadedGems,
      finalBoard: finalBoard ?? this.finalBoard,
      newGems: newGems ?? this.newGems,
      specialEffect: specialEffect ?? this.specialEffect,
      specialEffectOrigin: specialEffectOrigin ?? this.specialEffectOrigin,
      specialEffectTargets: specialEffectTargets ?? this.specialEffectTargets,
    );
  }

  @override
  List<Object?> get props => [
    swapFrom,
    swapTo,
    clearedGems,
    cascadedGems,
    finalBoard,
    newGems,
    specialEffect,
    specialEffectOrigin,
    specialEffectTargets,
  ];
}

@immutable
abstract class GameState extends Equatable {
  const GameState();

  @override
  List<Object?> get props => [];
}

class GameInitial extends GameState {}

class GameLoading extends GameState {}

class GameLoaded extends GameState {
  final GameSession gameSession;
  final bool isMyTurn;
  final bool isHammerActive;
  final AnimationDetails? animationDetails;
  final bool isTimerPaused;

  const GameLoaded({
    required this.gameSession,
    required this.isMyTurn,
    this.isHammerActive = false,
    this.animationDetails,
    this.isTimerPaused = false,
  });

  @override
  List<Object?> get props => [gameSession, isMyTurn, isHammerActive, animationDetails, isTimerPaused];

  GameLoaded copyWith({
    GameSession? gameSession,
    bool? isMyTurn,
    bool? isHammerActive,
    AnimationDetails? animationDetails,
    bool? isTimerPaused,
    bool clearAnimationDetails = false,
  }) {
    return GameLoaded(
      gameSession: gameSession ?? this.gameSession,
      isMyTurn: isMyTurn ?? this.isMyTurn,
      isHammerActive: isHammerActive ?? this.isHammerActive,
      animationDetails: clearAnimationDetails ? null : animationDetails ?? this.animationDetails,
      isTimerPaused: isTimerPaused ?? this.isTimerPaused,
    );
  }
}

class GameError extends GameState {
  final String message;
  const GameError(this.message);

  @override
  List<Object> get props => [message];
}