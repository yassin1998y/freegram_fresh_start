import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/random_chat/widgets/radar_scan_animation.dart'; // Added
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:freegram/services/window_manager_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:freegram/blocs/random_chat/random_chat_bloc.dart';
import 'package:freegram/blocs/random_chat/random_chat_event.dart';
import 'package:freegram/blocs/random_chat/random_chat_state.dart';
import 'package:freegram/screens/random_chat/video_call_overlay.dart';
import 'package:freegram/theme/app_theme.dart'; // Added
import 'package:freegram/theme/design_tokens.dart'; // Added
import 'package:freegram/widgets/guided_overlay.dart';

class MatchTab extends StatefulWidget {
  const MatchTab({super.key});

  @override
  State<MatchTab> createState() => _MatchTabState();
}

class _MatchTabState extends State<MatchTab>
    with SingleTickerProviderStateMixin {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _areRenderersInitialized = false;

  // Draggable PiP
  Offset _pipPosition = const Offset(20, 50);

  // Swipe Logic
  final PageController _pageController = PageController(initialPage: 0);

  // Pulse Animation for Search
  late AnimationController _pulseController;

  // Showcase Keys
  final GlobalKey _giftButtonKey = GlobalKey();
  bool _showTutorial = false;
  bool _hasSubscribedToTutorial = false;

  @override
  void initState() {
    super.initState();
    // Pulse Animation: Scales from 1.0 to 1.1 scale
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 1.0,
      upperBound: 1.1,
    )..repeat(reverse: true);

    // Defer renderer initialization until ungated
    // _initRenderers();
    context.read<RandomChatBloc>().add(RandomChatJoinQueue());
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (mounted) setState(() => _areRenderersInitialized = true);
  }

  Future<void> _enableSecureMode(bool enable) async {
    try {
      if (enable) {
        await WindowManagerService.addFlags(WindowManagerService.FLAG_SECURE);
      } else {
        await WindowManagerService.clearFlags(WindowManagerService.FLAG_SECURE);
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
    _pulseController.dispose(); // Dispose controller
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
        listenWhen: (previous, current) {
          return previous.status != current.status ||
              previous.errorMessage != current.errorMessage ||
              previous.infoMessage != current.infoMessage ||
              previous.isMicOn != current.isMicOn ||
              previous.isCameraOn != current.isCameraOn;
        },
        listener: (context, state) {
          // 0. Initialize Renderers when ungated
          if (!state.isGated && !_areRenderersInitialized) {
            _initRenderers();
          }

          // Haptics: Match Found
          if (state.status == RandomChatStatus.matching) {
            HapticFeedback.mediumImpact();
          }

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
          // Trigger tutorial when connected for the first time
          if (state.status == RandomChatStatus.connected &&
              !_hasSubscribedToTutorial) {
            _hasSubscribedToTutorial = true;
            // Short delay to let the UI settle
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) setState(() => _showTutorial = true);
            });
          }

          return Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  if (index == 1) {
                    // Swipe detected
                    context.read<RandomChatBloc>().add(RandomChatSwipeNext());
                    // Haptic feedback for swipe could be here too
                    HapticFeedback.lightImpact();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _pageController.jumpToPage(0);
                    });
                  }
                },
                children: [
                  _buildMainContent(state),
                  Container(color: Colors.black),
                ],
              ),
              if (_showTutorial)
                GuidedOverlay(
                  steps: [
                    GuideStep(
                      targetKey: _giftButtonKey,
                      title: 'Surprise Them! 🎁',
                      description:
                          'Send a cinematic gift to break the ice and make a lasting impression.',
                    ),
                  ],
                  onFinish: () {
                    setState(() => _showTutorial = false);
                  },
                ),
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

        // Matching Overlay (Shimmer) (Only if not searching)
        if (state.status == RandomChatStatus.matching) _buildMatchingOverlay(),

        VideoCallOverlay(giftButtonKey: _giftButtonKey),

        if (state.status == RandomChatStatus.connected) _buildPiPView(),
      ],
    );
  }

  Widget _buildMainView(RandomChatState state) {
    if (state.isGated || !_areRenderersInitialized) {
      return const SizedBox.shrink();
    }

    // Full-Bleed Remote Video (No Padding)
    if (state.status == RandomChatStatus.connected &&
        state.remoteStream != null) {
      return SizedBox.expand(
        child: RTCVideoView(
          _remoteRenderer,
          key: ValueKey(state.partnerId ?? DateTime.now().toString()),
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    } else {
      // Local preview full screen (Mirror)
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
    if (!_areRenderersInitialized) return const SizedBox();
    return Container(
      width: 100,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.black,
        // Squircle Style: Radius 16 + Border
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD), // 16.0
        border: Border.all(
            color: Colors.white, width: DesignTokens.borderWidthThin),
        boxShadow: [
          if (!isDragging)
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: DesignTokens.elevation2),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD - 1),
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
        child: Container(color: Colors.black.withValues(alpha: 0.3)),
      ),
      Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Pulse Animation for Search (Scale 1.0 -> 1.1)
        ScaleTransition(
          scale: _pulseController,
          child: const RadarScanAnimation(
            size: 200,
            color: SonarPulseTheme.primaryAccent,
          ),
        ),
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
        child: Container(color: Colors.black.withValues(alpha: 0.5)),
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
