import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_event.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_state.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

class PersistentMediaControls extends StatelessWidget {
  const PersistentMediaControls({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RandomChatBloc, RandomChatState>(
      builder: (context, state) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXXL),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceSM,
                vertical: DesignTokens.spaceXS,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(DesignTokens.radiusXXL),
                border: Border.all(
                  color: Colors.white10,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mic Toggle
                  _MediaControlButton(
                    icon: state.isLocalMicOff ? Icons.mic_off : Icons.mic,
                    activeColor: state.isLocalMicOff
                        ? Colors.redAccent
                        : SonarPulseTheme.primaryAccent,
                    onPressed: () {
                      context
                          .read<RandomChatBloc>()
                          .add(const RandomChatToggleLocalMic());
                    },
                  ),

                  const SizedBox(width: DesignTokens.spaceXS),

                  // Camera Flip
                  _MediaControlButton(
                    icon: Icons.flip_camera_ios,
                    onPressed: () {
                      context
                          .read<RandomChatBloc>()
                          .add(const RandomChatToggleLocalCamera());
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MediaControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color activeColor;

  const _MediaControlButton({
    required this.icon,
    required this.onPressed,
    this.activeColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXXL),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceSM),
          child: Icon(
            icon,
            color: activeColor,
            size: DesignTokens.iconMD,
          ),
        ),
      ),
    );
  }
}
