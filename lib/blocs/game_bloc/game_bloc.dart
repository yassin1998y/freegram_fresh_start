import 'dart:async';
import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/game_session.dart';
import 'package:freegram/repositories/gamification_repository.dart';
import 'package:freegram/repositories/game_repository.dart';
import 'package:meta/meta.dart';
import 'package:collection/collection.dart';

part 'game_event.dart';
part 'game_state.dart';

// CHANGED: Booster requirements are now all 7.
const Map<BoosterType, int> boosterRequirements = {
  BoosterType.bomb: 7,
  BoosterType.arrow: 7,
  BoosterType.hammer: 7,
  BoosterType.shuffle: 7,
};

class GameBloc extends Bloc<GameEvent, GameState> {
  final GameRepository _gameRepository;
  final GamificationRepository _gamificationRepository =
  locator<GamificationRepository>();
  final String _gameId;
  StreamSubscription? _gameSubscription;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  GameSession? _previousSession;

  GameBloc({required GameRepository gameRepository, required String gameId})
      : _gameRepository = gameRepository,
        _gameId = gameId,
        super(GameInitial()) {
    on<LoadGame>(_onLoadGame);
    on<_GameUpdated>(_onGameUpdated);
    // CHANGED: Using droppable() to prevent race conditions during animations/updates.
    on<SwapGems>(_onSwapGems, transformer: droppable());
    on<ActivateBooster>(_onActivateBooster, transformer: droppable());
    on<UseHammerOnGem>(_onUseHammerOnGem, transformer: droppable());
    on<ActivatePerk>(_onActivatePerk, transformer: droppable());
    on<EndTurnByTimer>(_onEndTurnByTimer, transformer: droppable());
  }

  void _onLoadGame(LoadGame event, Emitter<GameState> emit) {
    _gameSubscription?.cancel();
    _gameSubscription =
        _gameRepository.streamGameSession(_gameId).listen((doc) {
          if (doc.exists) {
            add(_GameUpdated(GameSession.fromDoc(doc)));
          } else {
            if (state is! GameError) {
              emit(const GameError("Game session not found or has ended."));
            }
          }
        }, onError: (error) {
          emit(GameError("Failed to load game session: $error"));
        });
  }

  void _onGameUpdated(_GameUpdated event, Emitter<GameState> emit) {
    final session = event.gameSession;
    AnimationDetails? animationDetails;

    // Reconstruct opponent's move for animation if it's now our turn.
    if (_previousSession != null && session.activePlayerId == _userId && _previousSession!.activePlayerId != _userId) {
      animationDetails = _reconstructOpponentMove(_previousSession!, session);
    }

    _previousSession = session;

    if (session.status == 'finished') {
      emit(GameLoaded(
        gameSession: session,
        isMyTurn: false,
      ));
      return;
    }

    // Auto-shuffle if no moves are possible.
    if (session.activePlayerId == _userId &&
        session.status == 'active' &&
        !_isMovePossible(session.board)) {
      final newBoard = _shuffleBoard(session.board);
      _gameRepository.updateGameState(_gameId, {
        'board': newBoard
            .expand((row) => row.map((tile) => tile.toMap()))
            .toList()
      });
      return;
    }

    // CHANGED: Pause the timer whenever an animation is being sent to the UI.
    bool isAnimating = animationDetails != null;

    if (state is GameLoaded) {
      final currentState = state as GameLoaded;
      emit(currentState.copyWith(
        gameSession: session,
        isMyTurn: session.activePlayerId == _userId,
        animationDetails: animationDetails,
        isTimerPaused: isAnimating,
        clearAnimationDetails: animationDetails == null,
      ));
    } else {
      emit(GameLoaded(
        gameSession: session,
        isMyTurn: session.activePlayerId == _userId,
        animationDetails: animationDetails,
        isTimerPaused: isAnimating,
      ));
    }
  }

  Future<void> _onSwapGems(SwapGems event, Emitter<GameState> emit) async {
    if (state is! GameLoaded) return;
    final currentState = state as GameLoaded;
    final session = currentState.gameSession;

    if (session.activePlayerId != _userId || session.movesLeftInTurn <= 0) {
      return;
    }

    var board = session.board.map((row) => List<GameTile>.from(row)).toList();
    final tile1 = board[event.from.y][event.from.x];
    final tile2 = board[event.to.y][event.to.x];

    // Optimistically swap on a temporary board to check for matches
    final temp = board[event.from.y][event.from.x];
    board[event.from.y][event.from.x] = board[event.to.y][event.to.x];
    board[event.to.y][event.to.x] = temp;

    final initialMatchGroups = _findAllMatches(board);
    final initialMatches = initialMatchGroups.expand((group) => group).toSet();

    // If the swap results in no match, emit an "invalid swap" animation.
    if (initialMatches.isEmpty && tile1.special == SpecialType.none.index && tile2.special == SpecialType.none.index) {
      final animationDetails = AnimationDetails(
        swapFrom: event.from,
        swapTo: event.to,
        finalBoard: session.board, // The original board before the bad swap
        specialEffect: AnimationEffect.invalidSwap,
      );
      emit(currentState.copyWith(animationDetails: animationDetails, isTimerPaused: true));
      return;
    }

    // Valid move, so pause the timer for the duration of the animations.
    emit(currentState.copyWith(isTimerPaused: true));

    try {
      Map<String, dynamic> finalUpdates;
      AnimationDetails animationDetails;

      if (tile1.special != SpecialType.none.index && tile2.special != SpecialType.none.index) {
        final result = _resolveSpecialCombination(session, board, event.from, event.to);
        finalUpdates = result['updates'] as Map<String, dynamic>;
        animationDetails = result['animationDetails'] as AnimationDetails;
      } else {
        // CHANGED: "Extra Move" Logic: Check if the initial match is 4 or 5 tiles long.
        int moveCost = 1;
        final isSpecialMatch = initialMatchGroups.any((group) => group.length >= 4);
        if (isSpecialMatch) {
          moveCost = 0;
        }

        final result = _resolveTurn(
          session: session,
          initialBoard: board,
          swappedPoints: {event.from, event.to},
          moveCost: moveCost,
        );
        finalUpdates = result['updates'] as Map<String, dynamic>;
        animationDetails = result['animationDetails'] as AnimationDetails;
      }

      emit(currentState.copyWith(animationDetails: animationDetails));
      finalUpdates.remove('_rawScore');
      await Future.delayed(const Duration(milliseconds: 100));
      await _gameRepository.updateGameState(_gameId, finalUpdates);

    } catch (e) {
      emit(GameError("An error occurred during your move: ${e.toString()}"));
    }
  }

  Map<String, dynamic> _createTurnResult(
      GameSession session,
      List<List<GameTile>> finalBoard,
      Set<Point<int>> allClearedGems,
      Map<int, int> clearedColors,
      int moveCost,
      Map<Point<int>, GameTile> newGems,
      ) {
    final scoreGained = allClearedGems.length * 10;
    final newMovesLeft = session.movesLeftInTurn - moveCost;

    final Map<String, dynamic> updates = {
      'board': finalBoard.expand((row) => row.map((tile) => tile.toMap())).toList(),
      'scores.$_userId': FieldValue.increment(scoreGained),
      'movesLeftInTurn': newMovesLeft,
      '_rawScore': scoreGained,
    };

    // CHANGED: New Mirrored Booster Logic: Only matching Star gems fills the current player's booster.
    if (clearedColors.containsKey(GemType.star.index)) {
      updates['boosterCharges.$_userId'] = FieldValue.increment(clearedColors[GemType.star.index]!);
    }

    if (newMovesLeft <= 0 && moveCost > 0) {
      _endTurn(updates, session, scoreGained);
    }
    return updates;
  }


  Map<String, dynamic> _resolveTurn({
    required GameSession session,
    required List<List<GameTile>> initialBoard,
    Set<Point<int>>? swappedPoints,
    int moveCost = 1,
    Set<Point<int>>? initialClearedPoints,
    AnimationEffect? specialEffect,
    Point<int>? specialEffectOrigin,
  }) {
    var currentBoard = initialBoard.map((row) => List<GameTile>.from(row)).toList();
    final allClearedGemsInTurn = <Point<int>>{};
    final clearedColors = <int, int>{};
    var swappedPointsForPlacement = swappedPoints ?? <Point<int>>{};
    final cascadedGems = <Point<int>, Point<int>>{};
    final clearedGemsByWave = <Set<Point<int>>>[];
    final createdSpecials = <Point<int>, GameTile>{};

    if(initialClearedPoints != null && initialClearedPoints.isNotEmpty) {
      clearedGemsByWave.add(Set.from(initialClearedPoints));
      allClearedGemsInTurn.addAll(initialClearedPoints);
      for (final point in initialClearedPoints) {
        final color = currentBoard[point.y][point.x].color;
        if (color != GemType.empty.index) {
          clearedColors[color] = (clearedColors[color] ?? 0) + 1;
        }
      }
      _clearGems(currentBoard, initialClearedPoints);
      final cascadeResult = _cascadeGems(currentBoard);
      cascadedGems.addAll(cascadeResult);
      _refillBoard(currentBoard);
    }

    while (true) {
      var activeMatchGroups = _findAllMatches(currentBoard);
      var activePoints = activeMatchGroups.expand((group) => group).toSet();

      var chainReactionPoints = <Point<int>>{};
      for (final point in Set.from(activePoints)) {
        chainReactionPoints.addAll(_getSpecialEffect(currentBoard, point));
      }
      activePoints.addAll(chainReactionPoints);

      if (activePoints.isEmpty) break;

      clearedGemsByWave.add(Set.from(activePoints));

      final boardBeforeClear = currentBoard.map((row) => List<GameTile>.from(row)).toList();
      final specialsToCreate = _analyzeMatches(boardBeforeClear, activeMatchGroups, swappedPointsForPlacement);
      swappedPointsForPlacement = {};

      allClearedGemsInTurn.addAll(activePoints);

      for (final point in activePoints) {
        final color = currentBoard[point.y][point.x].color;
        if (color != GemType.empty.index) {
          clearedColors[color] = (clearedColors[color] ?? 0) + 1;
        }
      }

      _clearGems(currentBoard, activePoints);
      _createSpecialGems(currentBoard, specialsToCreate, createdSpecials);

      final cascadeResult = _cascadeGems(currentBoard);
      cascadeResult.forEach((from, to) {
        cascadedGems[from] = to;
      });
      _refillBoard(currentBoard);
    }

    final updates = _createTurnResult(session, currentBoard, allClearedGemsInTurn, clearedColors, moveCost, createdSpecials);
    final animationDetails = AnimationDetails(
      swapFrom: swappedPoints?.isNotEmpty == true ? swappedPoints!.first : const Point(-1, -1),
      swapTo: swappedPoints?.isNotEmpty == true ? swappedPoints!.last : const Point(-1, -1),
      clearedGems: clearedGemsByWave,
      cascadedGems: cascadedGems,
      finalBoard: currentBoard,
      newGems: createdSpecials,
      specialEffect: specialEffect,
      specialEffectOrigin: specialEffectOrigin,
    );

    return {'updates': updates, 'animationDetails': animationDetails};
  }


  void _endTurn(
      Map<String, dynamic> updates, GameSession session, int currentTurnScore) {
    final opponentId = session.playerIds.firstWhere((id) => id != _userId);
    updates['activePlayerId'] = opponentId;
    updates['movesLeftInTurn'] = 2;
    updates['turnEndsAt'] =
        Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 20)));

    if (session.playerIds.indexOf(opponentId) == 0) {
      final myScore = (session.scores[_userId] ?? 0) + currentTurnScore;
      final opponentScore = session.scores[opponentId] ?? 0;
      final newRoundNumber = session.roundNumber + 1;

      if (myScore > opponentScore) {
        updates['roundWins.$_userId'] = FieldValue.increment(1);
      } else if (opponentScore > myScore) {
        updates['roundWins.$opponentId'] = FieldValue.increment(1);
      }

      if (newRoundNumber > totalRounds) {
        updates['status'] = 'finished';
        final myFinalWins = (session.roundWins[_userId] ?? 0) + (myScore > opponentScore ? 1 : 0);
        final oppFinalWins = (session.roundWins[opponentId] ?? 0) + (opponentScore > myScore ? 1 : 0);

        String? winnerId;
        if(myFinalWins > oppFinalWins) {
          winnerId = _userId;
        } else if (oppFinalWins > myFinalWins) {
          winnerId = opponentId;
        }
        updates['winnerId'] = winnerId;

        if(winnerId != null) {
          _gamificationRepository.addXp(winnerId, 100, isSeasonal: true);
          _gamificationRepository.addXp(winnerId == _userId ? opponentId : _userId, 25, isSeasonal: true);
        }
      } else {
        updates['roundNumber'] = FieldValue.increment(1);
      }
    }
  }


  Future<void> _onActivateBooster(
      ActivateBooster event, Emitter<GameState> emit) async {
    if (state is! GameLoaded) return;
    final currentState = state as GameLoaded;
    final session = currentState.gameSession;

    final boosterCharge = session.boosterCharges[_userId] ?? 0;
    final boosterTypeStr = session.equippedBoosters[_userId] ?? 'bomb';
    final boosterType = BoosterType.values.byName(boosterTypeStr);
    final requirement = boosterRequirements[boosterType] ?? 7;

    if (boosterCharge < requirement || !currentState.isMyTurn) {
      return;
    }

    if (boosterType == BoosterType.hammer) {
      emit(currentState.copyWith(isHammerActive: true));
      return;
    }

    emit(currentState.copyWith(isTimerPaused: true));

    try {
      var board = session.board.map((row) => List<GameTile>.from(row)).toList();
      var clearedPoints = <Point<int>>{};
      final random = Random();
      Map<String, dynamic> updates;
      AnimationEffect? effect;
      Point<int>? effectOrigin;

      switch(boosterType) {
        case BoosterType.bomb:
          effect = AnimationEffect.bomb;
          effectOrigin = Point(random.nextInt(boardSize - 2) + 1, random.nextInt(boardSize - 2) + 1);
          for (int i = effectOrigin.y - 1; i <= effectOrigin.y + 1; i++) {
            for (int j = effectOrigin.x - 1; j <= effectOrigin.x + 1; j++) {
              clearedPoints.add(Point(j, i));
            }
          }
          break;
        case BoosterType.arrow:
          effect = AnimationEffect.arrow;
          effectOrigin = Point(random.nextInt(boardSize), random.nextInt(boardSize));
          clearedPoints.addAll(_getSpecialEffect(board, effectOrigin, type: SpecialType.arrow_h));
          clearedPoints.addAll(_getSpecialEffect(board, effectOrigin, type: SpecialType.arrow_v));
          break;
        case BoosterType.shuffle:
          board = _shuffleBoard(board);
          updates = {'board': board.expand((row) => row.map((tile) => tile.toMap())).toList()};
          await _gameRepository.updateGameState(_gameId, updates);
          return;
        case BoosterType.hammer:
          break;
      }

      final turnResult = _resolveTurn(
        session: session,
        initialBoard: board,
        moveCost: 0,
        initialClearedPoints: clearedPoints,
        specialEffect: effect,
        specialEffectOrigin: effectOrigin,
      );
      updates = turnResult['updates'] as Map<String, dynamic>;
      final int rawScore = updates.remove('_rawScore') ?? 0;
      updates['scores.$_userId'] = FieldValue.increment(rawScore);
      updates['boosterCharges.$_userId'] = 0;

      emit(currentState.copyWith(animationDetails: turnResult['animationDetails'] as AnimationDetails?));
      await Future.delayed(const Duration(milliseconds: 100));
      await _gameRepository.updateGameState(_gameId, updates);

    } finally {
      // BLoC will emit new state with timer unpaused automatically upon receiving the next Firestore update.
    }
  }

  Future<void> _onUseHammerOnGem(UseHammerOnGem event, Emitter<GameState> emit) async {
    if (state is! GameLoaded) return;
    final currentState = state as GameLoaded;
    final session = currentState.gameSession;

    if (!currentState.isMyTurn || !currentState.isHammerActive) return;

    emit(currentState.copyWith(isTimerPaused: true));

    try {
      var board = session.board.map((row) => List<GameTile>.from(row)).toList();
      final clearedPoints = {event.target};

      final turnResult = _resolveTurn(session: session, initialBoard: board, moveCost: 0, initialClearedPoints: clearedPoints);
      final updates = turnResult['updates'] as Map<String, dynamic>;
      final int rawScore = updates.remove('_rawScore') ?? 0;
      updates['scores.$_userId'] = FieldValue.increment(rawScore);
      updates['boosterCharges.$_userId'] = 0;

      emit(currentState.copyWith(
          isHammerActive: false,
          animationDetails: turnResult['animationDetails'] as AnimationDetails?
      ));
      await Future.delayed(const Duration(milliseconds: 100));
      await _gameRepository.updateGameState(_gameId, updates);

    } finally {
      // BLoC will handle unpausing.
    }
  }


  Future<void> _onActivatePerk(
      ActivatePerk event, Emitter<GameState> emit) async {
    if (state is! GameLoaded) return;
    final currentState = state as GameLoaded;
    final session = currentState.gameSession;

    final usedPerks = session.usedPerks[_userId] ?? [];
    if (usedPerks.contains(event.perkType.name) || !currentState.isMyTurn) {
      return;
    }

    final updates = <String, dynamic>{
      'usedPerks.$_userId': FieldValue.arrayUnion([event.perkType.name])
    };

    if (event.perkType == PerkType.extraMove) {
      updates['movesLeftInTurn'] = FieldValue.increment(1);
      await _gameRepository.updateGameState(_gameId, updates);
      return;
    }

    if (event.perkType == PerkType.colorSplash) {
      emit(currentState.copyWith(isTimerPaused: true));
      try {
        var board = session.board.map((row) => List<GameTile>.from(row)).toList();
        final colorsOnBoard = board.expand((row) => row).map((tile) => tile.color).toSet();
        colorsOnBoard.remove(GemType.empty.index);

        if (colorsOnBoard.isNotEmpty) {
          final colorToClear = colorsOnBoard.elementAt(Random().nextInt(colorsOnBoard.length));
          final pointsToClear = <Point<int>>{};
          for (int y = 0; y < boardSize; y++) {
            for (int x = 0; x < boardSize; x++) {
              if (board[y][x].color == colorToClear) {
                pointsToClear.add(Point(x, y));
              }
            }
          }

          final turnResult = _resolveTurn(
            session: session,
            initialBoard: board,
            moveCost: 0,
            initialClearedPoints: pointsToClear,
            specialEffect: AnimationEffect.lightning,
            specialEffectOrigin: const Point(4, -1), // Off-screen origin
          );

          final resultUpdates = turnResult['updates'] as Map<String, dynamic>;
          final int rawScore = resultUpdates.remove('_rawScore') ?? 0;
          updates.addAll(resultUpdates);
          updates['scores.$_userId'] = FieldValue.increment(rawScore);

          emit(currentState.copyWith(animationDetails: turnResult['animationDetails'] as AnimationDetails?));
          await Future.delayed(const Duration(milliseconds: 100));
          await _gameRepository.updateGameState(_gameId, updates);
        }
      } finally {
        // BLoC will handle unpausing.
      }
    }
  }

  Future<void> _onEndTurnByTimer(
      EndTurnByTimer event, Emitter<GameState> emit) async {
    if (state is! GameLoaded) return;
    final currentState = state as GameLoaded;
    final session = currentState.gameSession;

    if (session.activePlayerId == _userId) {
      final updates = <String, dynamic>{};
      _endTurn(updates, session, 0);
      await _gameRepository.updateGameState(_gameId, updates);
    }
  }

  Map<Point<int>, Map<String, dynamic>> _analyzeMatches(
      List<List<GameTile>> board,
      List<Set<Point<int>>> groupedMatches,
      Set<Point<int>> swappedPoints,
      ) {
    final specialsToCreate = <Point<int>, Map<String, dynamic>>{};

    for (final group in groupedMatches) {
      Point<int>? creationPoint;
      final intersection = swappedPoints.intersection(group);
      if (intersection.isNotEmpty) {
        creationPoint = intersection.first;
      }
      creationPoint ??= group.first;

      final matchColor = board[creationPoint.y][creationPoint.x].color;
      if(matchColor == GemType.empty.index) continue;

      SpecialType? specialType;

      bool isHorizontal = group.every((p) => p.y == group.first.y);
      bool isVertical = group.every((p) => p.x == group.first.x);

      if (group.length >= 5 && (isHorizontal || isVertical)) {
        specialType = SpecialType.lightning;
      } else if (group.length == 4 && (isHorizontal || isVertical)) {
        if (isHorizontal) specialType = SpecialType.arrow_h;
        if (isVertical) specialType = SpecialType.arrow_v;
      } else if (group.length >= 5) { // L or T shape
        specialType = SpecialType.bomb;
      }

      if(specialType != null) {
        specialsToCreate[creationPoint] = {'type': specialType, 'color': matchColor};
      }
    }

    return specialsToCreate;
  }

  Set<Point<int>> _getSpecialEffect(List<List<GameTile>> board, Point<int> point, {SpecialType? type}) {
    Set<Point<int>> cleared = {};
    if (point.y < 0 || point.y >= boardSize || point.x < 0 || point.x >= boardSize) {
      return cleared;
    }

    final tile = board[point.y][point.x];
    final special = type ?? (tile.special >= 0 && tile.special < SpecialType.values.length ? SpecialType.values[tile.special] : SpecialType.none);

    if (special == SpecialType.none) return cleared;

    cleared.add(point);

    switch (special) {
      case SpecialType.arrow_h:
        for (int x = 0; x < boardSize; x++) cleared.add(Point(x, point.y));
        break;
      case SpecialType.arrow_v:
        for (int y = 0; y < boardSize; y++) cleared.add(Point(point.x, y));
        break;
      case SpecialType.bomb:
        for (int y = max(0, point.y - 1); y <= min(boardSize - 1, point.y + 1); y++) {
          for (int x = max(0, point.x - 1); x <= min(boardSize - 1, point.x + 1); x++) {
            cleared.add(Point(x, y));
          }
        }
        break;
      case SpecialType.lightning:
        final colorToClear = tile.color;
        if(colorToClear != GemType.empty.index) {
          for (int y = 0; y < boardSize; y++) {
            for (int x = 0; x < boardSize; x++) {
              if (board[y][x].color == colorToClear) cleared.add(Point(x, y));
            }
          }
        }
        break;
      default:
        break;
    }
    return cleared;
  }

  Map<String, dynamic> _resolveSpecialCombination(
      GameSession session, List<List<GameTile>> board, Point<int> p1, Point<int> p2) {

    final t1 = board[p1.y][p1.x];
    final t2 = board[p2.y][p2.x];
    var clearedPoints = <Point<int>>{p1, p2};
    AnimationEffect? effect;
    Point<int> effectOrigin = p1;
    List<Point<int>>? effectTargets;

    if (t1.special == SpecialType.bomb.index && t2.special == SpecialType.bomb.index) {
      effect = AnimationEffect.bomb;
      for (int y = max(0, p1.y - 2); y <= min(boardSize - 1, p1.y + 2); y++) {
        for (int x = max(0, p1.x - 2); x <= min(boardSize - 1, p1.x + 2); x++) {
          clearedPoints.add(Point(x, y));
        }
      }
    }
    else if ((t1.special == SpecialType.arrow_h.index || t1.special == SpecialType.arrow_v.index) &&
        (t2.special == SpecialType.arrow_h.index || t2.special == SpecialType.arrow_v.index)) {
      effect = AnimationEffect.arrow;
      clearedPoints.addAll(_getSpecialEffect(board, p1, type: SpecialType.arrow_h));
      clearedPoints.addAll(_getSpecialEffect(board, p1, type: SpecialType.arrow_v));
    }
    else if ((t1.special == SpecialType.bomb.index && (t2.special == SpecialType.arrow_h.index || t2.special == SpecialType.arrow_v.index)) ||
        (t2.special == SpecialType.bomb.index && (t1.special == SpecialType.arrow_h.index || t1.special == SpecialType.arrow_v.index))) {
      effect = AnimationEffect.arrow;
      for(int i = -1; i <= 1; i++) {
        clearedPoints.addAll(_getSpecialEffect(board, Point(p1.x, (p1.y + i).round()), type: SpecialType.arrow_h));
        clearedPoints.addAll(_getSpecialEffect(board, Point((p1.x + i).round(), p1.y), type: SpecialType.arrow_v));
      }
    }
    else if (t1.special == SpecialType.lightning.index || t2.special == SpecialType.lightning.index) {
      effect = AnimationEffect.lightning;
      final lightningPoint = t1.special == SpecialType.lightning.index ? p1 : p2;
      effectOrigin = lightningPoint;
      final otherTile = t1.special == SpecialType.lightning.index ? t2 : t1;
      final colorToTarget = otherTile.color;

      effectTargets = [];
      if(colorToTarget != GemType.empty.index) {
        for (int y = 0; y < boardSize; y++) {
          for (int x = 0; x < boardSize; x++) {
            if (board[y][x].color == colorToTarget) {
              clearedPoints.add(Point(x,y));
              effectTargets.add(Point(x,y));
            }
          }
        }
      }
    }

    final turnResult = _resolveTurn(
      session: session,
      initialBoard: board,
      initialClearedPoints: clearedPoints,
      swappedPoints: {p1, p2},
      specialEffect: effect,
      specialEffectOrigin: effectOrigin,
    );
    final animationDetails = (turnResult['animationDetails'] as AnimationDetails).copyWith(specialEffectTargets: effectTargets);
    turnResult['animationDetails'] = animationDetails;
    return turnResult;
  }

  void _createSpecialGems(List<List<GameTile>> board, Map<Point<int>, Map<String, dynamic>> specials, Map<Point<int>, GameTile> createdSpecials) {
    for (final entry in specials.entries) {
      final point = entry.key;
      final type = entry.value['type'] as SpecialType;
      final color = entry.value['color'] as int;

      if (point.y < boardSize && point.x < boardSize && point.y >= 0 && point.x >= 0) {
        final newTile = GameTile(
            color: color,
            special: type.index,
            id: board[point.y][point.x].id
        );
        board[point.y][point.x] = newTile;
        createdSpecials[point] = newTile;
      }
    }
  }

  List<Set<Point<int>>> _findAllMatches(List<List<GameTile>> board) {
    final List<Set<Point<int>>> allMatches = [];
    final Set<Point<int>> visited = {};

    for (int y = 0; y < boardSize; y++) {
      for (int x = 0; x < boardSize; x++) {
        final point = Point(x,y);
        if (visited.contains(point) || board[y][x].color == GemType.empty.index) continue;

        // Find all contiguous gems of the same color
        final group = <Point<int>>{};
        _floodFill(point, board[y][x].color, group, board);

        // From the group, find horizontal and vertical matches of 3+
        final yCoords = group.map((p) => p.y).toSet();
        for (final yCoord in yCoords) {
          final row = group.where((p) => p.y == yCoord).toList()..sort((a, b) => a.x.compareTo(b.x));
          if (row.length >= 3) {
            for (int i = 0; i <= row.length - 3; i++) {
              if (row[i+2].x - row[i].x == 2) {
                final match = {row[i], row[i+1], row[i+2]};
                allMatches.add(match);
                visited.addAll(match);
              }
            }
          }
        }

        final xCoords = group.map((p) => p.x).toSet();
        for(final xCoord in xCoords) {
          final col = group.where((p) => p.x == xCoord).toList()..sort((a,b) => a.y.compareTo(b.y));
          if(col.length >= 3) {
            for (int i = 0; i <= col.length - 3; i++) {
              if (col[i+2].y - col[i].y == 2) {
                final match = {col[i], col[i+1], col[i+2]};
                allMatches.add(match);
                visited.addAll(match);
              }
            }
          }
        }
      }
    }
    return allMatches;
  }

  void _floodFill(Point<int> point, int color, Set<Point<int>> group, List<List<GameTile>> board) {
    if (point.x < 0 || point.x >= boardSize || point.y < 0 || point.y >= boardSize ||
        group.contains(point) || board[point.y][point.x].color != color) {
      return;
    }
    group.add(point);
    _floodFill(Point(point.x + 1, point.y), color, group, board);
    _floodFill(Point(point.x - 1, point.y), color, group, board);
    _floodFill(Point(point.x, point.y + 1), color, group, board);
    _floodFill(Point(point.x, point.y - 1), color, group, board);
  }

  void _clearGems(List<List<GameTile>> board, Set<Point<int>> matches) {
    for (var point in matches) {
      board[point.y][point.x] = GameTile(color: GemType.empty.index, id: board[point.y][point.x].id);
    }
  }

  Map<Point<int>, Point<int>> _cascadeGems(List<List<GameTile>> board) {
    final movements = <Point<int>, Point<int>>{};
    for (int x = 0; x < boardSize; x++) {
      int emptyRow = boardSize - 1;
      for (int y = boardSize - 1; y >= 0; y--) {
        if (board[y][x].color != GemType.empty.index) {
          if (y != emptyRow) {
            movements[Point(x, y)] = Point(x, emptyRow);
            board[emptyRow][x] = board[y][x];
            board[y][x] = GameTile(color: GemType.empty.index, id: 'temp_${x}_${y}');
          }
          emptyRow--;
        }
      }
    }
    return movements;
  }

  void _refillBoard(List<List<GameTile>> board) {
    final random = Random();
    for (int y = 0; y < boardSize; y++) {
      for (int x = 0; x < boardSize; x++) {
        if (board[y][x].color == GemType.empty.index) {
          // Exclude 'empty' type from random generation
          board[y][x] = GameTile(color: random.nextInt(GemType.values.length - 1));
        }
      }
    }
  }

  bool _isMovePossible(List<List<GameTile>> board) {
    for (int y = 0; y < boardSize; y++) {
      for (int x = 0; x < boardSize; x++) {
        if (x < boardSize - 1) {
          if (_checkSwapCreatesMatch(board, Point(x, y), Point(x + 1, y))) return true;
        }
        if (y < boardSize - 1) {
          if (_checkSwapCreatesMatch(board, Point(x, y), Point(x, y + 1))) return true;
        }
      }
    }
    return false;
  }

  bool _checkSwapCreatesMatch(
      List<List<GameTile>> board, Point<int> p1, Point<int> p2) {
    final newBoard = board.map((row) => List<GameTile>.from(row)).toList();
    final temp = newBoard[p1.y][p1.x];
    newBoard[p1.y][p1.x] = newBoard[p2.y][p2.x];
    newBoard[p2.y][p2.x] = temp;
    return _findAllMatches(newBoard).isNotEmpty;
  }

  List<List<GameTile>> _shuffleBoard(List<List<GameTile>> board) {
    List<GameTile> flatBoard = board.expand((row) => row).toList();
    List<List<GameTile>> newBoard;
    int attempts = 0;
    while(attempts < 50) {
      flatBoard.shuffle();
      newBoard = [];
      for(var i = 0; i < boardSize; i++) {
        newBoard.add(flatBoard.sublist(i*boardSize, (i+1)*boardSize));
      }
      if (_findAllMatches(newBoard).isEmpty && _isMovePossible(newBoard)) {
        return newBoard;
      }
      attempts++;
    }
    return _gameRepository.getNewShuffledBoard();
  }

  AnimationDetails? _reconstructOpponentMove(GameSession oldState, GameSession newState) {
    Point<int>? swapFrom, swapTo;

    final newPositions = { for (var y=0; y<boardSize; y++) for (var x=0; x<boardSize; x++) newState.board[y][x].id: Point(x,y) };

    final movedGems = <String>[];
    for(var y=0; y < boardSize; y++) {
      for(var x=0; x<boardSize; x++) {
        final oldId = oldState.board[y][x].id;
        final newPos = newPositions[oldId];
        if (newPos != null && newPos != Point(x,y)) {
          movedGems.add(oldId);
        }
      }
    }

    if (movedGems.length == 2) {
      final p1Old = _findPointForGemId(movedGems[0], oldState.board);
      final p2Old = _findPointForGemId(movedGems[1], oldState.board);
      final p1New = newPositions[movedGems[0]];
      final p2New = newPositions[movedGems[1]];

      if (p1Old != null && p2Old != null && p1New != null && p2New != null && p1Old == p2New && p2Old == p1New) {
        swapFrom = p1Old;
        swapTo = p2Old;
      }
    }

    if (swapFrom == null || swapTo == null) return null;

    var boardAfterSwap = oldState.board.map((row) => List<GameTile>.from(row)).toList();
    final temp = boardAfterSwap[swapFrom.y][swapFrom.x];
    boardAfterSwap[swapFrom.y][swapFrom.x] = boardAfterSwap[swapTo.y][swapTo.x];
    boardAfterSwap[swapTo.y][swapTo.x] = temp;

    final result = _resolveTurn(session: oldState, initialBoard: boardAfterSwap, swappedPoints: {swapFrom, swapTo});
    return result['animationDetails'] as AnimationDetails;
  }

  Point<int>? _findPointForGemId(String id, List<List<GameTile>> board) {
    for (int y = 0; y < board.length; y++) {
      for (int x = 0; x < board[y].length; x++) {
        if (board[y][x].id == id) {
          return Point(x, y);
        }
      }
    }
    return null;
  }

  @override
  Future<void> close() {
    _gameSubscription?.cancel();
    return super.close();
  }
}