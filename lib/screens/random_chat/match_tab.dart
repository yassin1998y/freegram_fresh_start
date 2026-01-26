import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:freegram/blocs/random_chat/random_chat_bloc.dart';
import 'package:freegram/blocs/random_chat/random_chat_event.dart';
import 'package:freegram/blocs/random_chat/random_chat_state.dart';
import 'package:freegram/screens/random_chat/video_call_overlay.dart';

class MatchTab extends StatefulWidget {
  const MatchTab({super.key});

  @override
  State<MatchTab> createState() => _MatchTabState();
}

class _MatchTabState extends State<MatchTab> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  // Draggable PiP
  Offset _pipPosition = const Offset(20, 50);

  // Swipe Logic
  final PageController _pageController = PageController(initialPage: 0);

  @override
  void initState() {
    super.initState();
    _initRenderers();
    context.read<RandomChatBloc>().add(RandomChatJoinQueue());
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    // 🛑 GHOST TASK FIX: Strictly dispose renderers when widget is killed.
    // This ensures no lingering texture registries or memory leaks.
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<RandomChatBloc, RandomChatState>(
        listener: (context, state) {
          if (state.localStream != null) {
            _localRenderer.srcObject = state.localStream;
            if (mounted) setState(() {});
          }
          if (state.remoteStream != null) {
            _remoteRenderer.srcObject = state.remoteStream;
            if (mounted) setState(() {});
          } else {
            _remoteRenderer.srcObject = null;
          }
        },
        builder: (context, state) {
          // Use PageView for "Slide" Effect
          // Page 0: Active Call (or Searching)
          // Page 1: "Next" Placeholder (Force swipe back to 0 logic)
          return PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (index == 1) {
                // Trigger Next
                context.read<RandomChatBloc>().add(RandomChatSwipeNext());
                // Animate back to 0 instantly or after small delay to show "New Card"
                // For infinite swipe effect, usually we reset controller.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _pageController.jumpToPage(0);
                });
              }
            },
            children: [
              _buildMainContent(state),
              // Placeholder for slide animation target
              Container(color: Colors.black),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainContent(RandomChatState state) {
    return Stack(
      children: [
        // 1. Main View (Remote or Local)
        _buildMainView(state),

        // 2. Searching Overlay
        if (state.status == RandomChatStatus.searching)
          _buildSearchingOverlay(),

        // 3. Match Overlay (HUD, Blur)
        const VideoCallOverlay(),

        // 4. PiP (Local Camera) - Only when connected
        if (state.status == RandomChatStatus.connected) _buildPiPView(),
      ],
    );
  }

  Widget _buildMainView(RandomChatState state) {
    // If connected, show Remote.
    // Else show Local (Mirror).
    if (state.status == RandomChatStatus.connected &&
        state.remoteStream != null) {
      // Remote View
      return SizedBox.expand(
        child: RTCVideoView(
          _remoteRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    } else {
      // Local View (Searching or Idle)
      return SizedBox.expand(
        child: RTCVideoView(
          _localRenderer,
          mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    }
  }

  Widget _buildPiPView() {
    return Positioned(
      left: _pipPosition.dx,
      top: _pipPosition.dy,
      child: Draggable(
        feedback: _buildPiPContent(isDragging: true),
        childWhenDragging: Container(),
        onDragEnd: (details) {
          setState(() {
            _pipPosition = details.offset;
          });
        },
        child: _buildPiPContent(),
      ),
    );
  }

  Widget _buildPiPContent({bool isDragging = false}) {
    return Container(
      width: 100,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!isDragging)
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: RTCVideoView(
          _localRenderer,
          mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      ),
    );
  }

  Widget _buildSearchingOverlay() {
    // Semi-transparent overlay or blur over the local camera
    return Stack(children: [
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(color: Colors.black.withOpacity(0.3)),
      ),
      const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: Colors.white),
        SizedBox(height: 20),
        Text("Finding Match...",
            style: TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w300))
      ]))
    ]);
  }
}
