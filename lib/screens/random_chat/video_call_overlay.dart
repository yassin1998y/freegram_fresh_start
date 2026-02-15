import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/random_chat/random_chat_bloc.dart';
import 'package:freegram/blocs/random_chat/random_chat_event.dart';
import 'package:freegram/blocs/random_chat/random_chat_state.dart';
import 'package:freegram/services/webrtc_service.dart';
import 'package:freegram/screens/random_chat/widgets/gift_picker_sheet.dart';
import 'package:freegram/screens/random_chat/widgets/interaction_overlay.dart';
import 'package:freegram/screens/random_chat/widgets/report_bottom_sheet.dart';
import 'package:freegram/blocs/interaction/interaction_bloc.dart';
import 'package:freegram/blocs/interaction/interaction_event.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';

class VideoCallOverlay extends StatelessWidget {
  final GlobalKey? giftButtonKey;

  const VideoCallOverlay({
    super.key,
    this.giftButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RandomChatBloc, RandomChatState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.partnerId != current.partnerId ||
          previous.isBlurred != current.isBlurred ||
          previous.isMicOn != current.isMicOn ||
          previous.isCameraOn != current.isCameraOn,
      builder: (context, state) {
        return Stack(
          children: [
            // Blur Overlay (Safety Shield & Privacy)
            if (state.isBlurred && state.remoteStream != null)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                      sigmaX: 15, sigmaY: 15), // Glass Effect
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.privacy_tip_outlined,
                              color: Colors.white, size: 48),
                          SizedBox(height: 16),
                          Text(
                            "Safety Shield Active",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Gradient Scrim (Bottom 35%)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.35,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xAA0A0A0B), // ~67% opacity dark background
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),

            // HUD (Top & Bottom)
            _buildHeadsUpOverlay(context, state),

            // Interaction Layer (Gifts + Chat)
            const Positioned.fill(child: InteractionOverlay()),

            // ACTION DOCK (Glassmorphic)
            _buildActionDock(context, state),
          ],
        );
      },
    );
  }

  Widget _buildHeadsUpOverlay(BuildContext context, RandomChatState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Report (Top Left)
                if (state.status == RandomChatStatus.connected)
                  GestureDetector(
                    onTap: () => _handleReport(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.flag, color: Colors.white, size: 22),
                    ),
                  )
                else
                  const SizedBox(width: 40),

                // LIVE Badge (Top Right)
                if (state.status == RandomChatStatus.connected)
                  const LiveBadge(),
              ],
            ),

            // Add Friend (Center - moved down slightly or kept in flow if needed,
            // but prompt says "Top Right" for Live badge.
            // The previous "Add Friend" was center. I'll keep it there but purely layout-wise it might overlap.
            // Let's create a separate row or just stack it if needed.
            // Actually, we can put it in the same Row if we use proper alignment.
            // But "Add Friend" logic:
            if (state.partnerId != null &&
                state.status == RandomChatStatus.connected)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: GestureDetector(
                  onTap: () {
                    context
                        .read<InteractionBloc>()
                        .add(SendFriendRequestEvent());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Friend Request Sent!')),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white54),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add, color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Text("Add Friend",
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionDock(BuildContext context, RandomChatState state) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: Containers.glassDecoration(context).copyWith(
            borderRadius: BorderRadius.circular(30),
            color: Colors.black.withValues(alpha: 0.3), // Fallback/Base
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mic Toggle
              _buildDockButton(
                context,
                icon: state.isMicOn ? Icons.mic : Icons.mic_off,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.read<RandomChatBloc>().add(RandomChatToggleMic());
                },
              ),
              const SizedBox(width: 16),

              // Camera Toggle
              _buildDockButton(
                context,
                icon: state.isCameraOn ? Icons.videocam : Icons.videocam_off,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.read<RandomChatBloc>().add(RandomChatToggleCamera());
                },
              ),
              const SizedBox(width: 16),

              // End/Next Call
              _buildDockButton(
                context,
                icon: Icons.call_end,
                color: SemanticColors.error,
                isRounded: true,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.read<RandomChatBloc>().add(RandomChatSwipeNext());
                },
              ),

              // Gift Button (only if connected)
              if (state.status == RandomChatStatus.connected) ...[
                const SizedBox(width: 16),
                GestureDetector(
                  key: giftButtonKey,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => BackdropFilter(
                              filter:
                                  ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: const GiftPickerSheet(),
                            ));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: SonarPulseTheme.socialAccent, // Cyber Violet
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: SonarPulseTheme.socialAccent
                                .withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]),
                    child: const Icon(Icons.card_giftcard,
                        color: Colors.white, size: DesignTokens.iconLG),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    bool isRounded = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRounded ? color : Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: isRounded ? Colors.white : color,
            size: DesignTokens.iconLG // 24.0
            ),
      ),
    );
  }

  void _handleReport(BuildContext context) {
    final partnerId = WebRTCService.instance.currentPartnerId;
    if (partnerId != null) {
      ReportBottomSheet.show(context, userId: partnerId, onReported: () {
        WebRTCService.instance.blockUser(partnerId);
        context.read<RandomChatBloc>().add(RandomChatSwipeNext());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No active user to report.")),
      );
    }
  }
}

class LiveBadge extends StatefulWidget {
  const LiveBadge({super.key});

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _opacity,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: SemanticColors.success,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            "LIVE",
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          )
        ],
      ),
    );
  }
}
