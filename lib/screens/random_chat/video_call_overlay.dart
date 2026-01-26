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
import 'package:freegram/blocs/interaction/interaction_event.dart';
// import 'package:freegram/services/webrtc_service.dart'; // Duplicate

class VideoCallOverlay extends StatelessWidget {
  const VideoCallOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RandomChatBloc, RandomChatState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.partnerId != current.partnerId ||
          previous.isBlurred != current.isBlurred,
      builder: (context, state) {
        // if (state.status != RandomChatStatus.connected)
        //   return const SizedBox.shrink();

        return Stack(
          children: [
            // Blur Overlay (Safety & Connection Status)
            // Placed FIRST so it covers the video (behind this widget) but stays BEHIND controls
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
                            decoration:
                                TextDecoration.none, // Fix for text style
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
            // Report Button
            GestureDetector(
              onTap: () {
                // TODO: Show Report Dialog
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag, color: Colors.white, size: 22),
              ),
            ),

            // Add Friend (Center)
            if (state.partnerId != null)
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
            ValueListenableBuilder<bool>(
              valueListenable: WebRTCService.instance.isMicOn,
              builder: (context, isMic, _) => IconButton(
                icon: Icon(isMic ? Icons.mic : Icons.mic_off, size: 30),
                color: Colors.white,
                onPressed: WebRTCService.instance.toggleMic,
              ),
            ),

            // Cam Toggle
            ValueListenableBuilder<bool>(
              valueListenable: WebRTCService.instance.isCameraOn,
              builder: (context, isCam, _) => IconButton(
                icon:
                    Icon(isCam ? Icons.videocam : Icons.videocam_off, size: 30),
                color: Colors.white,
                onPressed: WebRTCService.instance.toggleCamera,
              ),
            ),

            // NEXT / SKIP Button (Primary Action)
            // Even if connected, we show this to skip to next
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

            // Report (Only when connected)
            if (state.status == RandomChatStatus.connected)
              _buildActionButton(
                icon: Icons.shield_outlined,
                label: "Report",
                color: Colors.red,
                onPressed: () {
                  final partnerId =
                      WebRTCService.instance.currentPartnerId.value;
                  if (partnerId != null) {
                    ReportBottomSheet.show(context, userId: partnerId);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("No active user to report.")),
                    );
                  }
                },
              ),

            // Gift Button (Only when connected)
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

            // Effects / Filter Button
            IconButton(
              icon: const Icon(Icons.auto_fix_high, size: 30),
              color: Colors.white,
              onPressed: () {
                // TODO: Effects Logic
              },
            ),
          ],
        ),
      ),
    );
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
