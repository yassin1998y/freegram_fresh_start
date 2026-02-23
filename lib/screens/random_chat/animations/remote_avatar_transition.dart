import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/random_chat/animations/match_sonar_view.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_state.dart';
import 'package:freegram/theme/design_tokens.dart';

class RemoteAvatarTransition extends StatelessWidget {
  const RemoteAvatarTransition({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RandomChatBloc, RandomChatState>(
      builder: (context, state) {
        final partner = state.partnerContext;
        if (partner == null) return const SizedBox.shrink();

        final screenSize = MediaQuery.of(context).size;

        // Approximated Header Position
        const double startX =
            DesignTokens.spaceMD + 24; // Padding + avatar radius
        final double startY =
            MediaQuery.of(context).padding.top + DesignTokens.spaceSM + 24;

        final double endX = screenSize.width / 2;
        final double endY = screenSize.height / 2;

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            final double currentX = startX + (endX - startX) * value;
            final double currentY = startY + (endY - startY) * value;
            final double currentSize = 48 + (52 * value); // Grow from 48 to 100

            return Stack(
              children: [
                // Sonar only active when fully centered
                if (value > 0.9)
                  Center(
                    child: MatchSonarView(size: currentSize * 2.5),
                  ),

                Positioned(
                  left: currentX - (currentSize / 2),
                  top: currentY - (currentSize / 2),
                  child: Container(
                    width: currentSize,
                    height: currentSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      backgroundImage: NetworkImage(partner.avatarUrl),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
