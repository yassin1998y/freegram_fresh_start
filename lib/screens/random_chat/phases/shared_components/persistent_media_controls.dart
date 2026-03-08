import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_event.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_state.dart';
import 'package:freegram/screens/random_chat/widgets/glass_overlay_container.dart';
import 'package:freegram/theme/design_tokens.dart';

class MinimalistMediaControls extends StatelessWidget {
  const MinimalistMediaControls({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RandomChatBloc, RandomChatState>(
      builder: (context, state) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GlassMediaButton(
              icon: state.isLocalMicOff
                  ? Icons.mic_off_rounded
                  : Icons.mic_rounded,
              activeColor:
                  state.isLocalMicOff ? Colors.redAccent : Colors.white,
              onPressed: () {
                context
                    .read<RandomChatBloc>()
                    .add(const RandomChatToggleLocalMic());
              },
            ),
            const SizedBox(width: DesignTokens.spaceSM),
            _GlassMediaButton(
              icon: Icons.flip_camera_ios_rounded,
              onPressed: () {
                context
                    .read<RandomChatBloc>()
                    .add(const RandomChatToggleLocalCamera());
              },
            ),
          ],
        );
      },
    );
  }
}

class _GlassMediaButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color activeColor;

  const _GlassMediaButton({
    required this.icon,
    required this.onPressed,
    this.activeColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: GlassOverlayContainer(
        borderRadius: BorderRadius.circular(24.0),
        padding: const EdgeInsets.all(0),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(
              icon,
              color: activeColor,
              size: DesignTokens.iconMD,
            ),
          ),
        ),
      ),
    );
  }
}
