import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_state.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/screens/random_chat/widgets/pulse_avatar.dart';
import 'package:freegram/screens/random_chat/widgets/glass_overlay_container.dart';

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
              child: GlassOverlayContainer(
                borderRadius: BorderRadius.circular(32),
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMD,
                  vertical: DesignTokens.spaceSM,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hero Avatar
                    Hero(
                      tag: 'match_avatar',
                      flightShuttleBuilder: (
                        flightContext,
                        animation,
                        flightDirection,
                        fromHeroContext,
                        toHeroContext,
                      ) {
                        return PulseAvatar(
                          photoUrl: partner.avatarUrl,
                          size:
                              140, // Keeps the larger pulse dimension during flight
                          showAvatar: true,
                        );
                      },
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white12,
                        backgroundImage: partner.avatarUrl.isNotEmpty
                            ? NetworkImage(partner.avatarUrl)
                            : null,
                        child: partner.avatarUrl.isEmpty
                            ? const Icon(Icons.person,
                                size: 24, color: Colors.white54)
                            : null,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceMD),

                    // Name and Age
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${partner.name}, ${partner.age}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: DesignTokens.fontSizeLG,
                              ),
                            ),
                            const SizedBox(width: DesignTokens.spaceSM),
                            const _LiveIndicator(),
                          ],
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

class _LiveIndicator extends StatefulWidget {
  const _LiveIndicator();

  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: SemanticColors.primary(context),
            boxShadow: [
              BoxShadow(
                color: SemanticColors.primary(context)
                    .withValues(alpha: 0.8 * _controller.value),
                blurRadius: 8 * _controller.value,
                spreadRadius: 3 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
