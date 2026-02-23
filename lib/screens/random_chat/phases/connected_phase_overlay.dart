import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:freegram/screens/random_chat/phases/sub_components/hideable_controls_wrapper.dart';
import 'package:freegram/screens/random_chat/phases/sub_components/partner_info_header.dart';
import 'package:freegram/screens/random_chat/phases/sub_components/primary_action_bar.dart';
import 'package:freegram/screens/random_chat/phases/sub_components/secondary_action_bar.dart';
import 'package:freegram/theme/design_tokens.dart';

class ConnectedPhaseOverlay extends StatelessWidget {
  const ConnectedPhaseOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return HideableControlsWrapper(
      overlay: const Stack(
        children: [
          // Top Layer: Info and Report
          PartnerInfoHeader(),

          // Bottom Layer: Actions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.only(bottom: DesignTokens.spaceXL),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SecondaryActionBar(),
                  SizedBox(height: DesignTokens.spaceXL),
                  PrimaryActionBar(),
                ],
              ),
            ),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Progressive Unblur via BackdropFilter
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 20.0, end: 0.0),
            duration: const Duration(seconds: 2),
            curve: Curves.easeOut,
            builder: (context, blurValue, child) {
              if (blurValue <= 0.1) return const SizedBox.shrink();

              return Positioned.fill(
                child: BackdropFilter(
                  filter:
                      ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
                  child: Container(
                    color: Colors.black
                        .withValues(alpha: blurValue / 40.0), // Subtle fade
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
