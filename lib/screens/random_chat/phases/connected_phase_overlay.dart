import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_state.dart';
import 'package:freegram/screens/random_chat/phases/sub_components/hideable_controls_wrapper.dart';
import 'package:freegram/screens/random_chat/phases/sub_components/partner_info_header.dart';
import 'package:freegram/screens/random_chat/phases/sub_components/random_chat_input_pill.dart';
import 'package:freegram/theme/design_tokens.dart';

class ConnectedPhaseOverlay extends StatefulWidget {
  const ConnectedPhaseOverlay({super.key});

  @override
  State<ConnectedPhaseOverlay> createState() => _ConnectedPhaseOverlayState();
}

class _ConnectedPhaseOverlayState extends State<ConnectedPhaseOverlay> {
  late final TextEditingController _chatController;

  @override
  void initState() {
    super.initState();
    _chatController = TextEditingController();
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RandomChatBloc, RandomChatState>(
      builder: (context, state) {
        return HideableControlsWrapper(
          overlay: Stack(
            children: [
              // Legibility Scrim
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 200,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Top Layer: Info and Report
              const PartnerInfoHeader(),

              // Middle Layer: Partner Muted Indicator
              if (state.isRemoteMicOff)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spaceLG,
                          vertical: DesignTokens.spaceSM),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusXL),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic_off_rounded,
                              color: Colors.redAccent,
                              size: DesignTokens.iconMD),
                          SizedBox(width: DesignTokens.spaceSM),
                          Text(
                            "Partner is Muted",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: DesignTokens.fontSizeMD,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Bottom Interaction Zone
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: DesignTokens.spaceMD,
                    left: 70, // Space for media controls
                    right: 70, // Space for skip button
                  ),
                  child: RandomChatInputPill(
                    controller: _chatController,
                    onSend: () {
                      // Logic to send message
                      _chatController.clear();
                    },
                  ),
                ),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Video Continuity Guard: Fading Avatar Placeholder
              if (state.partnerContext != null)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 1.0, end: 0.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeIn,
                  builder: (context, opacity, child) {
                    if (opacity <= 0.05) return const SizedBox.shrink();
                    return Positioned.fill(
                      child: Opacity(
                        opacity: opacity,
                        child: Image.network(
                          state.partnerContext!.avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.person,
                                size: 100, color: Colors.white54),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Progressive Unblur via BackdropFilter
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 20.0, end: 0.0),
                duration: const Duration(seconds: 2),
                curve: Curves.easeOut,
                builder: (context, blurValue, child) {
                  if (blurValue <= 0.1) return const SizedBox.shrink();

                  return Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                          sigmaX: blurValue, sigmaY: blurValue),
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
      },
    );
  }
}
