import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/history/history_bloc.dart';
import 'package:freegram/models/match_history_model.dart';
import 'package:timeago/timeago.dart' as timeago;

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HistoryBloc()..add(LoadHistory()),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text("Match History",
              style: TextStyle(color: Colors.white)),
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: () {
                  context.read<HistoryBloc>().add(ClearHistory());
                },
              ),
            )
          ],
        ),
        body: BlocBuilder<HistoryBloc, HistoryState>(
          builder: (context, state) {
            if (state is HistoryLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is HistoryError) {
              return Center(
                  child: Text(state.message,
                      style: const TextStyle(color: Colors.red)));
            } else if (state is HistoryLoaded) {
              if (state.matches.isEmpty) {
                return _buildEmptyState();
              }
              return ListView.builder(
                itemCount: state.matches.length,
                itemBuilder: (context, index) {
                  final match = state.matches[index];
                  return _buildHistoryItem(match);
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            "No matches yet.",
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            "Start swiping to meet new people!",
            style: TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(MatchHistoryModel match) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(match.avatarUrl),
        backgroundColor: Colors.grey.shade800,
      ),
      title: Text(match.nickname, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        "Matched ${timeago.format(match.timestamp)} • ${match.durationSeconds}s",
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: IconButton(
        icon:
            const Icon(Icons.person_add_alt_1, color: Colors.deepPurpleAccent),
        onPressed: () {
          // Add friend logic
        },
      ),
    );
  }
}
