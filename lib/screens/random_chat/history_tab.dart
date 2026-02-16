import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/history/history_bloc.dart';
import 'package:freegram/models/match_history_model.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocProvider(
      create: (context) => HistoryBloc()..add(LoadHistory()),
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Match History", style: theme.textTheme.titleLarge),
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: theme.colorScheme.onSurface),
                      onPressed: () {
                        context.read<HistoryBloc>().add(ClearHistory());
                      },
                    ),
                  )
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<HistoryBloc, HistoryState>(
                builder: (context, state) {
                  if (state is HistoryLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is HistoryError) {
                    return Center(
                        child: Text(state.message,
                            style: const TextStyle(color: Colors.red)));
                  } else if (state is HistoryLoaded) {
                    if (state.matches.isEmpty) {
                      return _buildEmptyState(context);
                    }
                    return ListView.builder(
                      itemCount: state.matches.length,
                      itemBuilder: (context, index) {
                        final match = state.matches[index];
                        return _buildHistoryItem(context, match);
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off,
              size: 80,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            "No matches yet.",
            style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            "Start swiping to meet new people!",
            style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, MatchHistoryModel match) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(match.avatarUrl),
        backgroundColor: theme.dividerColor,
      ),
      title: Text(match.nickname, style: theme.textTheme.bodyLarge),
      subtitle: Text(
        "Matched ${timeago.format(match.timestamp)} • ${match.durationSeconds}s",
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.person_add_alt_1,
            color: SonarPulseTheme.primaryAccent),
        onPressed: () {
          // Add friend logic
        },
      ),
    );
  }
}
