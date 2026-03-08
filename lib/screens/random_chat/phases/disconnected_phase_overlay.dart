import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_event.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_state.dart';
import 'package:freegram/theme/design_tokens.dart';

class DisconnectedPhaseOverlay extends StatelessWidget {
  const DisconnectedPhaseOverlay({super.key});

  String _formatDuration(int? seconds) {
    if (seconds == null) return "0s";
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) {
      return "${m}m ${s}s";
    }
    return "${s}s";
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RandomChatBloc, RandomChatState>(
      builder: (context, state) {
        final partner = state.partnerContext;
        final duration = state.lastMatchDurationSeconds;

        return Stack(
          children: [
            // 1. The Contextual Memory Background
            if (partner != null && partner.avatarUrl.isNotEmpty) ...[
              Positioned.fill(
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.black54,
                    BlendMode.darken,
                  ),
                  child: Image.network(
                    partner.avatarUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.2), // Additional softening
                  ),
                ),
              ),
            ] else ...[
               Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.8),
                  ),
               ),
            ],

            // 2. The Main Content Overlay
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_off_rounded,
                      color: Colors.white54,
                      size: 80,
                    ),
                    const SizedBox(height: DesignTokens.spaceMD),
                    const Text(
                      "Connection Lost",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: DesignTokens.fontSizeXL,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceXL),
                    if (partner != null) ...[
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white12,
                        backgroundImage: partner.avatarUrl.isNotEmpty 
                            ? NetworkImage(partner.avatarUrl) 
                            : null,
                        child: partner.avatarUrl.isEmpty 
                            ? const Icon(Icons.person, size: 50, color: Colors.white54)
                            : null,
                      ),
                      const SizedBox(height: DesignTokens.spaceMD),
                      Text(
                        "${partner.name}, ${partner.age}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: DesignTokens.fontSizeLG,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: DesignTokens.spaceMD),
                    Text(
                      "Lasted ${_formatDuration(duration)}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: DesignTokens.fontSizeMD,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceXXL),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade900,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceXL,
                              vertical: DesignTokens.spaceMD,
                            ),
                          ),
                          onPressed: () {
                            context.read<RandomChatBloc>().add(const RandomChatLeaveMatchTab());
                          },
                          child: const Text("Exit"),
                        ),
                        const SizedBox(width: DesignTokens.spaceMD),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceXL,
                              vertical: DesignTokens.spaceMD,
                            ),
                          ),
                          onPressed: () {
                            context.read<RandomChatBloc>().add(const RandomChatStartSearching());
                          },
                          icon: const Icon(Icons.search),
                          label: const Text("Search Again"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
