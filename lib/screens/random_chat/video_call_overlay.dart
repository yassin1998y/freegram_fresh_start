import 'package:flutter/material.dart';
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

class VideoCallOverlay extends StatelessWidget {
  const VideoCallOverlay({super.key});

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
            // Blur Overlay (Safety & Connection Status)
            if (state.isBlurred)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.95),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 10),
                        const Text(
                          "Establishing secure connection...",
                          style: TextStyle(
                            color: Colors.white70,
                            decoration: TextDecoration.none,
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // HUD (Top & Bottom)
            _buildHeadsUpOverlay(context, state),

            // Interaction Layer (Gifts + Chat)
            const Positioned.fill(child: InteractionOverlay()),

            // Controls Overlay
            _buildControlsOverlay(context, state),
          ],
        );
      },
    );
  }

  Widget _buildHeadsUpOverlay(BuildContext context, RandomChatState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
        child: Row(
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
                    color: Colors.red.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flag, color: Colors.white, size: 22),
                ),
              )
            else
              const SizedBox(width: 40),

            // Add Friend (Center)
            if (state.partnerId != null &&
                state.status == RandomChatStatus.connected)
              GestureDetector(
                onTap: () {
                  context.read<InteractionBloc>().add(SendFriendRequestEvent());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friend Request Sent!')),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white54),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.person_add, color: Colors.white, size: 18),
                      SizedBox(width: 4),
                      Text("Add Friend", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),

            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay(BuildContext context, RandomChatState state) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 180,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black, Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.only(bottom: 40, left: 20, right: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Mic Toggle
            IconButton(
              icon: Icon(state.isMicOn ? Icons.mic : Icons.mic_off, size: 30),
              color: Colors.white,
              onPressed: () =>
                  context.read<RandomChatBloc>().add(RandomChatToggleMic()),
            ),

            // Cam Toggle
            IconButton(
              icon: Icon(state.isCameraOn ? Icons.videocam : Icons.videocam_off,
                  size: 30),
              color: Colors.white,
              onPressed: () =>
                  context.read<RandomChatBloc>().add(RandomChatToggleCamera()),
            ),

            // NEXT / SKIP Button
            SizedBox(
              width: 75,
              height: 75,
              child: FloatingActionButton(
                heroTag: 'skip_btn',
                onPressed: () {
                  context.read<RandomChatBloc>().add(RandomChatSwipeNext());
                },
                backgroundColor: Colors.white,
                elevation: 10,
                child:
                    const Icon(Icons.skip_next, color: Colors.black, size: 36),
              ),
            ),

            // Report Action
            if (state.status == RandomChatStatus.connected)
              _buildActionButton(
                icon: Icons.shield_outlined,
                label: "Report",
                color: Colors.red,
                onPressed: () => _handleReport(context),
              ),

            // Gift Button
            if (state.status == RandomChatStatus.connected)
              IconButton(
                icon: const Icon(Icons.card_giftcard, size: 30),
                color: Colors.amber,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const GiftPickerSheet(),
                  );
                },
              ),
          ],
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
