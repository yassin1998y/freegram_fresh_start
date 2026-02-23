import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/random_chat/animations/match_sonar_view.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_event.dart';
import 'package:freegram/theme/design_tokens.dart';

class SearchingPhaseOverlay extends StatefulWidget {
  const SearchingPhaseOverlay({super.key});

  @override
  State<SearchingPhaseOverlay> createState() => _SearchingPhaseOverlayState();
}

class _SearchingPhaseOverlayState extends State<SearchingPhaseOverlay> {
  late Timer _timer;
  int _tipIndex = 0;

  final List<String> _searchTips = [
    "Finding someone amazing...",
    "Smiling helps! ✨",
    "Adjusting the radar...",
    "Global connections incoming...",
    "The perfect match takes time...",
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted) {
        setState(() {
          _tipIndex = (_tipIndex + 1) % _searchTips.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Dark Overlay (Deeper than idle)
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
            ),
          ),
        ),

        // 2. Central Sonar
        const Center(
          child: MatchSonarView(),
        ),

        // 3. Cycling Search Tips
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.35,
          left: DesignTokens.spaceXL,
          right: DesignTokens.spaceXL,
          child: AnimatedSwitcher(
            duration: AnimationTokens.normal,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              _searchTips[_tipIndex],
              key: ValueKey<int>(_tipIndex),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
        ),

        // 4. Stop Button
        Positioned(
          bottom:
              MediaQuery.of(context).padding.bottom + DesignTokens.spaceXXXL,
          left: 0,
          right: 0,
          child: Column(
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: FloatingActionButton(
                  onPressed: () {
                    context
                        .read<RandomChatBloc>()
                        .add(const RandomChatStopSearching());
                  },
                  backgroundColor: SemanticColors.error,
                  elevation: 0,
                  focusElevation: 0,
                  highlightElevation: 0,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.stop_rounded,
                      color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMD),
              Text(
                'Cancel Search',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
