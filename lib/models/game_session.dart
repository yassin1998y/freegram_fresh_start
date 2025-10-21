import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

// --- CORE GAME CONSTANTS ---
const int boardSize = 8;
const int totalRounds = 5;

// --- ENUMS ---
enum BoosterType { bomb, arrow, hammer, shuffle }
enum PerkType { extraMove, colorSplash }
// FIX: Added 'star' as a new gem type
enum GemType { blue, green, purple, red, yellow, star, empty }
enum SpecialType { none, arrow_h, arrow_v, bomb, lightning }

class GameTile extends Equatable {
  final String id;
  final int color;
  final int special;

  GameTile({
    String? id,
    required this.color,
    this.special = 0,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {'id': id, 'c': color, 's': special};

  factory GameTile.fromMap(Map<String, dynamic> map) => GameTile(
    id: map['id'] ?? const Uuid().v4(), // Ensure ID always exists
    color: map['c'] ?? 0,
    special: map['s'] ?? 0,
  );

  @override
  List<Object?> get props => [id, color, special];
}

class GameSession extends Equatable {
  final String id;
  final List<String> playerIds;
  final Map<String, String> playerNames;
  final Map<String, String> playerPhotoUrls;
  final List<List<GameTile>> board;
  final Map<String, int> scores;
  final String activePlayerId;
  final String status;
  final String? winnerId;
  final int roundNumber;
  final Map<String, int> roundWins;
  final int movesLeftInTurn;
  final DateTime turnEndsAt;
  final Map<String, String> equippedBoosters;
  final Map<String, List<String>> equippedPerks;
  final Map<String, List<String>> usedPerks;
  final Map<String, int> boosterCharges;

  const GameSession({
    required this.id,
    required this.playerIds,
    required this.playerNames,
    required this.playerPhotoUrls,
    required this.board,
    required this.scores,
    required this.activePlayerId,
    required this.status,
    this.winnerId,
    required this.roundNumber,
    required this.roundWins,
    required this.movesLeftInTurn,
    required this.turnEndsAt,
    required this.equippedBoosters,
    required this.equippedPerks,
    required this.usedPerks,
    required this.boosterCharges,
  });

  factory GameSession.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<List<GameTile>> board = [];
    List<dynamic> flatBoard = data['board'] ?? [];
    if (flatBoard.isNotEmpty && flatBoard.length == boardSize * boardSize) {
      for (var i = 0; i < boardSize; i++) {
        board.add(flatBoard
            .sublist(i * boardSize, (i + 1) * boardSize)
            .map((tileMap) => GameTile.fromMap(tileMap))
            .toList());
      }
    }

    final perks = data['equippedPerks'] as Map<String, dynamic>? ?? {};
    final used = data['usedPerks'] as Map<String, dynamic>? ?? {};

    return GameSession(
      id: doc.id,
      playerIds: List<String>.from(data['playerIds'] ?? []),
      playerNames: Map<String, String>.from(data['playerNames'] ?? {}),
      playerPhotoUrls: Map<String, String>.from(data['playerPhotoUrls'] ?? {}),
      board: board,
      scores: Map<String, int>.from(data['scores'] ?? {}),
      activePlayerId: data['activePlayerId'] ?? '',
      status: data['status'] ?? 'finished',
      winnerId: data['winnerId'],
      roundNumber: data['roundNumber'] ?? 1,
      roundWins: Map<String, int>.from(data['roundWins'] ?? {}),
      movesLeftInTurn: data['movesLeftInTurn'] ?? 2,
      turnEndsAt: (data['turnEndsAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      equippedBoosters: Map<String, String>.from(data['equippedBoosters'] ?? {}),
      equippedPerks: perks.map((key, value) => MapEntry(key, List<String>.from(value))),
      usedPerks: used.map((key, value) => MapEntry(key, List<String>.from(value))),
      boosterCharges: Map<String, int>.from(data['boosterCharges'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerIds': playerIds,
      'playerNames': playerNames,
      'playerPhotoUrls': playerPhotoUrls,
      'board': board.expand((row) => row.map((tile) => tile.toMap()).toList()).toList(),
      'scores': scores,
      'activePlayerId': activePlayerId,
      'status': status,
      'winnerId': winnerId,
      'roundNumber': roundNumber,
      'roundWins': roundWins,
      'movesLeftInTurn': movesLeftInTurn,
      'turnEndsAt': Timestamp.fromDate(turnEndsAt),
      'equippedBoosters': equippedBoosters,
      'equippedPerks': equippedPerks,
      'usedPerks': usedPerks,
      'boosterCharges': boosterCharges,
    };
  }

  @override
  List<Object?> get props => [
    id, playerIds, playerNames, board, scores, activePlayerId, status,
    winnerId, roundNumber, roundWins, movesLeftInTurn, turnEndsAt,
    equippedBoosters, equippedPerks, usedPerks, boosterCharges
  ];
}