import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/matchmaking_bloc/matchmaking_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/game_session.dart';
import 'package:freegram/repositories/game_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/match3_screen.dart';

class MatchmakingScreen extends StatelessWidget {
  // FIX: Added fields to accept booster and perk selections.
  final BoosterType selectedBooster;
  final List<PerkType> selectedPerks;

  const MatchmakingScreen({
    super.key,
    required this.selectedBooster,
    required this.selectedPerks,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MatchmakingBloc(
        gameRepository: locator<GameRepository>(),
        userRepository: locator<UserRepository>(),
        // FIX: Pass selections to the BLoC.
        selectedBooster: selectedBooster,
        selectedPerks: selectedPerks,
      ),
      child: const _MatchmakingView(),
    );
  }
}

class _MatchmakingView extends StatelessWidget {
  const _MatchmakingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade800,
      appBar: AppBar(
        title: const Text("Find a Match"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BlocConsumer<MatchmakingBloc, MatchmakingState>(
        listener: (context, state) {
          if (state is MatchmakingSuccess) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => Match3Screen(gameId: state.gameSession.id),
              ),
            );
          }
          if (state is MatchmakingError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Error: ${state.message}"),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          // Automatically start searching when the screen loads
          if (state is MatchmakingInitial) {
            context.read<MatchmakingBloc>().add(FindGame());
          }

          if (state is MatchmakingSearching) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 24),
                  const Text(
                    "Searching for an opponent...",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      context.read<MatchmakingBloc>().add(CancelSearch());
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

