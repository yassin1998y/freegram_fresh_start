import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:freegram/models/game_session.dart';
import 'package:freegram/screens/booster_selection_screen.dart';

class GameResultsScreen extends StatelessWidget {
  final GameSession gameSession;
  final String currentUserId;

  const GameResultsScreen({
    super.key,
    required this.gameSession,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final opponentId =
    gameSession.playerIds.firstWhere((id) => id != currentUserId);
    final myScore = gameSession.scores[currentUserId] ?? 0;
    final opponentScore = gameSession.scores[opponentId] ?? 0;
    final winnerId = gameSession.winnerId;

    String resultText;
    Color resultColor;
    if (winnerId == currentUserId) {
      resultText = 'You Won!';
      resultColor = Colors.green;
    } else if (winnerId == opponentId) {
      resultText = 'You Lost';
      resultColor = Colors.red;
    } else {
      resultText = 'It\'s a Draw!';
      resultColor = Colors.amber;
    }

    return Scaffold(
      backgroundColor: Colors.indigo.shade800,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                resultText,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: resultColor,
                    fontSize: 48,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              _buildPlayerResult(
                name: gameSession.playerNames[currentUserId] ?? 'You',
                photoUrl: gameSession.playerPhotoUrls[currentUserId] ?? '',
                score: myScore,
                isWinner: winnerId == currentUserId,
              ),
              const SizedBox(height: 16),
              _buildPlayerResult(
                name: gameSession.playerNames[opponentId] ?? 'Opponent',
                photoUrl: gameSession.playerPhotoUrls[opponentId] ?? '',
                score: opponentScore,
                isWinner: winnerId == opponentId,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  // FIX: Navigate to the BoosterSelectionScreen to start a new game flow.
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const BoosterSelectionScreen()),
                        (route) => route.isFirst,
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Play Again'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Back to Menu',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerResult(
      {required String name,
        required String photoUrl,
        required int score,
        required bool isWinner}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: isWinner ? Border.all(color: Colors.amber, width: 2) : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage:
            photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
            child: photoUrl.isEmpty ? Text(name[0]) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            score.toString(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

