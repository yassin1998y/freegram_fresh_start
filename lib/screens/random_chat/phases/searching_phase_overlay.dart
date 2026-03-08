import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/screens/random_chat/widgets/pulse_avatar.dart';
import 'package:freegram/screens/random_chat/widgets/ambient_bokeh_background.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_event.dart';
import 'package:freegram/theme/design_tokens.dart';

class SearchingPhaseOverlay extends StatefulWidget {
  const SearchingPhaseOverlay({super.key});

  @override
  State<SearchingPhaseOverlay> createState() => _SearchingPhaseOverlayState();
}

class _SearchingPhaseOverlayState extends State<SearchingPhaseOverlay> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Ambient Background Bokeh Effect
        const AmbientBokehBackground(),

        // 2. Dark Overlay
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black45,
            ),
          ),
        ),

        // 2. Central Pulse Avatar
        Center(
          child: Hero(
            tag: 'match_avatar',
            child: PulseAvatar(
              photoUrl: FirebaseAuth.instance.currentUser?.photoURL,
              size: 140,
            ),
          ),
        ),

        // 4. Searching Dynamic Typography pulse
        Positioned(
          bottom: 120.0,
          left: 0,
          right: 0,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.4, end: 0.8),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
            builder: (context, opacity, child) {
              return Opacity(
                opacity: opacity,
                child: const Text(
                  'SEARCHING FOR PARTNER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4.0,
                    fontSize: 12.0,
                  ),
                ),
              );
            },
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
