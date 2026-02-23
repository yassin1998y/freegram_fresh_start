import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_event.dart';
import 'package:freegram/theme/design_tokens.dart';

class PrimaryActionBar extends StatelessWidget {
  const PrimaryActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: FloatingActionButton(
            onPressed: () {
              // In our BLoC logic, starting a new search while connected effectively skips the current partner
              context.read<RandomChatBloc>().add(const RandomChatStartSearching());
            },
            backgroundColor: SemanticColors.error,
            elevation: 8,
            shape: const CircleBorder(),
            child: const Icon(
              Icons.skip_next_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.spaceSM),
        Text(
          'Next Match',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              const Shadow(blurRadius: 4, color: Colors.black54),
            ],
          ),
        ),
      ],
    );
  }
}
