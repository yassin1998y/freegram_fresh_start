import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_state.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

class PartnerInfoHeader extends StatelessWidget {
  const PartnerInfoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RandomChatBloc, RandomChatState>(
      builder: (context, state) {
        final partner = state.partnerContext;
        if (partner == null) return const SizedBox.shrink();

        return Stack(
          children: [
            // Top Left Info
            Positioned(
              top: MediaQuery.of(context).padding.top + DesignTokens.spaceSM,
              left: DesignTokens.spaceMD,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(DesignTokens.spaceSM),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMD),
                      border: Border.all(color: Colors.white12, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name and Age
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${partner.name}, ${partner.age}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: DesignTokens.fontSizeLG,
                              ),
                            ),
                            if (partner.mutualInterests.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: DesignTokens.spaceXS),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: DesignTokens.spaceSM,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SonarPulseTheme.primaryAccent
                                        .withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(
                                        DesignTokens.radiusXS),
                                  ),
                                  child: Text(
                                    '${partner.mutualInterests.length} Mutual Interests',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: DesignTokens.fontSizeXS,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(width: DesignTokens.spaceMD),

                        // Add Friend Button
                        IconButton(
                          onPressed: () {
                            // Dispatch add friend
                          },
                          icon: const Icon(Icons.person_add_rounded,
                              color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Top Right Report Button
            Positioned(
              top: MediaQuery.of(context).padding.top + DesignTokens.spaceSM,
              right: DesignTokens.spaceMD,
              child: IconButton(
                onPressed: () {
                  // Open Report Dialog
                },
                icon: const Icon(Icons.shield_outlined, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black26,
                  padding: const EdgeInsets.all(DesignTokens.spaceSM),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
