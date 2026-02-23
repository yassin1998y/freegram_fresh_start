import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

class SecondaryActionBar extends StatelessWidget {
  const SecondaryActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DesignTokens.radiusXXL),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceLG,
            vertical: DesignTokens.spaceSM,
          ),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(DesignTokens.radiusXXL),
            border: Border.all(
              color: Colors.white10,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SecondaryIconAction(
                icon: Icons.card_giftcard_rounded,
                onPressed: () {
                  // Open Gift Picker
                },
              ),
              const SizedBox(width: DesignTokens.spaceXL),
              _SecondaryIconAction(
                icon: Icons.casino_rounded,
                onPressed: () {
                  // Icebreakers / Dice logic
                },
              ),
              const SizedBox(width: DesignTokens.spaceXL),
              _SecondaryIconAction(
                icon: Icons.face_rounded,
                onPressed: () {
                  // Reactions / Smile logic
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryIconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _SecondaryIconAction({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: DesignTokens.iconLG),
      style: IconButton.styleFrom(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
