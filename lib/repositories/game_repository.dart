import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/game_session.dart';
import 'package:freegram/models/user_model.dart';

/// A repository for all game-related Firestore operations.
class GameRepository {
  final FirebaseFirestore _db;
  final Random _random = Random();

  GameRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Looks for a waiting game session or creates a new one.
  Future<String> findOrCreateGameSession(
      UserModel currentUser, BoosterType booster, List<PerkType> perks) async {
    final query = _db
        .collection('games')
        .where('status', isEqualTo: 'waiting')
        .limit(1);

    final waitingGames = await query.get();

    if (waitingGames.docs.isNotEmpty) {
      final gameToJoinDoc = waitingGames.docs.first;
      final gameSession = GameSession.fromDoc(gameToJoinDoc);

      if (gameSession.playerIds.isEmpty ||
          gameSession.playerIds.first == currentUser.id) {
        if (gameSession.playerIds.isNotEmpty) {
          await gameToJoinDoc.reference.delete();
        }
        return _createNewGameSession(currentUser, booster, perks);
      }

      final opponentId = gameSession.playerIds.first;
      await gameToJoinDoc.reference.update({
        'playerIds': FieldValue.arrayUnion([currentUser.id]),
        'playerNames.${currentUser.id}': currentUser.username,
        'playerPhotoUrls.${currentUser.id}': currentUser.photoUrl,
        'scores.${currentUser.id}': 0,
        'roundWins.${currentUser.id}': 0,
        'equippedBoosters.${currentUser.id}': booster.name,
        'equippedPerks.${currentUser.id}': perks.map((p) => p.name).toList(),
        'usedPerks.${currentUser.id}': [],
        'boosterCharges.${currentUser.id}': 0,
        'roundWins.${opponentId}': 0, // Also initialize for opponent
        'status': 'active',
      });
      return gameToJoinDoc.id;
    } else {
      return _createNewGameSession(currentUser, booster, perks);
    }
  }

  /// Creates a new document for a game session.
  Future<String> _createNewGameSession(
      UserModel currentUser, BoosterType booster, List<PerkType> perks) async {
    final newGameRef = _db.collection('games').doc();
    final initialBoard = getNewShuffledBoard();
    const int movesPerTurn = 2; // Defined locally as it's a creation-time constant

    final newGameSession = GameSession(
      id: newGameRef.id,
      playerIds: [currentUser.id],
      playerNames: {currentUser.id: currentUser.username},
      playerPhotoUrls: {currentUser.id: currentUser.photoUrl},
      board: initialBoard,
      scores: {currentUser.id: 0},
      activePlayerId: currentUser.id,
      status: 'waiting',
      winnerId: null,
      roundNumber: 1,
      roundWins: {currentUser.id: 0},
      movesLeftInTurn: movesPerTurn,
      turnEndsAt: DateTime.now().add(const Duration(seconds: 20)),
      equippedBoosters: {currentUser.id: booster.name},
      equippedPerks: {
        currentUser.id: perks.map((p) => p.name).toList()
      },
      usedPerks: {currentUser.id: []},
      boosterCharges: {currentUser.id: 0},
    );

    await newGameRef.set(newGameSession.toMap());
    return newGameRef.id;
  }

  Future<void> cancelSearch(String userId, String gameId) async {
    final gameRef = _db.collection('games').doc(gameId);
    final gameDoc = await gameRef.get();
    if(gameDoc.exists) {
      final gameSession = GameSession.fromDoc(gameDoc);
      if(gameSession.status == 'waiting' && gameSession.playerIds.length == 1 && gameSession.playerIds.first == userId) {
        await gameRef.delete();
      }
    }
  }

  Stream<DocumentSnapshot> streamGameSession(String gameId) {
    return _db.collection('games').doc(gameId).snapshots();
  }

  Future<void> updateGameState(String gameId, Map<String, dynamic> data) {
    return _db.collection('games').doc(gameId).update(data);
  }

  // Helper method to generate a valid, shuffled board.
  List<List<GameTile>> getNewShuffledBoard() {
    List<List<GameTile>> board;
    do {
      board = List.generate(
        boardSize,
            (_) => List.generate(
          boardSize,
              (_) => GameTile(color: _random.nextInt(GemType.values.length - 1)),
        ),
      );
    } while (_findMatches(board).isNotEmpty);
    return board;
  }

  Set<Point<int>> _findMatches(List<List<GameTile>> board) {
    Set<Point<int>> matches = {};
    for (int y = 0; y < boardSize; y++) {
      for (int x = 0; x < boardSize - 2; x++) {
        if (board[y][x].color != GemType.empty.index &&
            board[y][x].color == board[y][x + 1].color &&
            board[y][x].color == board[y][x + 2].color) {
          matches.addAll({Point(x, y), Point(x + 1, y), Point(x + 2, y)});
        }
      }
    }
    for (int x = 0; x < boardSize; x++) {
      for (int y = 0; y < boardSize - 2; y++) {
        if (board[y][x].color != GemType.empty.index &&
            board[y][x].color == board[y + 1][x].color &&
            board[y][x].color == board[y + 2][x].color) {
          matches.addAll({Point(x, y), Point(x, y + 1), Point(x, y + 2)});
        }
      }
    }
    return matches;
  }
}
