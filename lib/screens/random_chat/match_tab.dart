import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:shimmer/shimmer.dart';
import 'package:freegram/blocs/random_chat/random_chat_bloc.dart';
import 'package:freegram/blocs/random_chat/random_chat_event.dart';
import 'package:freegram/blocs/random_chat/random_chat_state.dart';
import 'package:freegram/screens/random_chat/video_call_overlay.dart';
import 'package:freegram/services/webrtc_service.dart';

class PulseAvatar extends StatefulWidget {
  final double radius;
  const PulseAvatar({super.key, required this.radius});

  @override
  State<PulseAvatar> createState() => _PulseAvatarState();
}

class _PulseAvatarState extends State<PulseAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
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
          width: widget.radius * 2 + (20 * _controller.value),
          height: widget.radius * 2 + (20 * _controller.value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.3 * (1 - _controller.value)),
          ),
          child: child,
        );
      },
      child: Center(
        child: CircleAvatar(
          radius: widget.radius,
          backgroundColor: Colors.white,
          child: const Icon(Icons.person, color: Colors.blue, size: 40),
        ),
      ),
    );
  }
}

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

  Future<void> _enableSecureMode(bool enable) async {
    try {
      if (enable) {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } else {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      }
      debugPrint("🛡️ [PRIVACY] Secure Mode: $enable");
    } catch (e) {
      debugPrint("⚠️ [PRIVACY] Failed to set secure mode: $e");
    }
  }

  @override
  void dispose() {
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _showPremiumFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 48),
            const SizedBox(height: 16),
            const Text(
              "Upgrade to Filter?",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "You need 50 coins or a Filter Pass to use Gender/Region filters.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                // Navigate to Store
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Redirecting to Store...")));
              },
              child: const Text("Get Premium"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<RandomChatBloc, RandomChatState>(
        listener: (context, state) {
          // Renderers
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

          // Secure Mode Trigger
          if (state.status == RandomChatStatus.matching ||
              state.status == RandomChatStatus.connected) {
            _enableSecureMode(true);
          } else {
            _enableSecureMode(false);
          }

          // Errors/Messages
          if (state.errorMessage == 'PREMIUM_FILTER_REQUIRED') {
            _showPremiumFilterSheet();
          }

          if (state.infoMessage != null && state.infoMessage!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.infoMessage!),
                backgroundColor: Colors.orange));
          }
        },
        builder: (context, state) {
          return PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (index == 1) {
                context.read<RandomChatBloc>().add(RandomChatSwipeNext());
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _pageController.jumpToPage(0);
                });
              }
            },
            children: [
              _buildMainContent(state),
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
        _buildMainView(state),

        // Searching Overlay (Pulse)
        if (state.status == RandomChatStatus.searching)
          _buildSearchingOverlay(),

        // Matching Overlay (Shimmer)
        if (state.status == RandomChatStatus.matching) _buildMatchingOverlay(),

        const VideoCallOverlay(),

        if (state.status == RandomChatStatus.connected) _buildPiPView(),
      ],
    );
  }

  Widget _buildMainView(RandomChatState state) {
    if (state.status == RandomChatStatus.connected &&
        state.remoteStream != null) {
      return SizedBox.expand(
        child: RTCVideoView(
          _remoteRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    } else {
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
    return Stack(children: [
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(color: Colors.black.withOpacity(0.3)),
      ),
      Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const PulseAvatar(radius: 60), // New Pulse Widget
        const SizedBox(height: 20),
        const Text("Finding Match...",
            style: TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w300))
      ]))
    ]);
  }

  Widget _buildMatchingOverlay() {
    // 1.5s Shimmer during "matching" state before connection
    return Stack(children: [
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(color: Colors.black.withOpacity(0.5)),
      ),
      Center(
        child: Shimmer.fromColors(
          baseColor: Colors.white70,
          highlightColor: Colors.white,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.white),
              SizedBox(height: 20),
              Text(
                "Securing Connection...",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}
