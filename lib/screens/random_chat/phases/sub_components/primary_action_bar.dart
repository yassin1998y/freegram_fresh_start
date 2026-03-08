import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_event.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_state.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/screens/random_chat/widgets/glass_overlay_container.dart';
import 'package:freegram/screens/random_chat/widgets/report_bottom_sheet.dart';

class PrimaryActionBar extends StatelessWidget {
  const PrimaryActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RandomChatBloc, RandomChatState>(
      builder: (context, state) {
        final partner = state.partnerContext;

        return GlassOverlayContainer(
          borderRadius: BorderRadius.circular(100),
          padding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: DesignTokens.spaceMD,
          ),
          child: SizedBox(
            width: 56.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionItem(
                  icon: Icons.card_giftcard_rounded,
                  onPressed: () {
                    // Open Gift Picker
                  },
                ),
                const SizedBox(height: DesignTokens.spaceMD),
                _ActionItem(
                  icon: Icons.person_add_rounded,
                  onPressed: () {
                    // Dispatch add friend
                  },
                ),
                const SizedBox(height: DesignTokens.spaceMD),
                _ActionItem(
                  icon: Icons.shield_outlined,
                  onPressed: () {
                    if (partner != null) {
                      context
                          .read<RandomChatBloc>()
                          .add(const RandomChatSetGesturesEnabled(false));
                      ReportBottomSheet.show(
                        context,
                        userId: partner.id,
                        userName: partner.name,
                      ).then((_) {
                        if (context.mounted) {
                          context
                              .read<RandomChatBloc>()
                              .add(const RandomChatSetGesturesEnabled(true));
                        }
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionItem({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: DesignTokens.iconMD),
    );
  }
}
