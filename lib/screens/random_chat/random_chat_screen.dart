import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:freegram/services/webrtc_service.dart';

class RandomChatScreen extends StatefulWidget {
  const RandomChatScreen({super.key});

  @override
  State<RandomChatScreen> createState() => _RandomChatScreenState();
}

class _RandomChatScreenState extends State<RandomChatScreen>
    with SingleTickerProviderStateMixin {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  late AnimationController _sonarController;

  bool _isMicOn = true;
  bool _isCameraOn = true;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _setupAnimation();

    // Initialize Service and Start Search
    WebRTCService.instance.initialize().then((_) {
      WebRTCService.instance.startRandomSearch();
    });

    // Listen to Streams
    WebRTCService.instance.localStream.addListener(_onLocalStreamChanged);
    WebRTCService.instance.remoteStream.addListener(_onRemoteStreamChanged);
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _onLocalStreamChanged() {
    setState(() {
      _localRenderer.srcObject = WebRTCService.instance.localStream.value;
    });
  }

  void _onRemoteStreamChanged() {
    setState(() {
      _remoteRenderer.srcObject = WebRTCService.instance.remoteStream.value;
    });
  }

  void _setupAnimation() {
    _sonarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    WebRTCService.instance.endCall();

    WebRTCService.instance.localStream.removeListener(_onLocalStreamChanged);
    WebRTCService.instance.remoteStream.removeListener(_onRemoteStreamChanged);

    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _sonarController.dispose();
    super.dispose();
  }

  void _handleNextMatch() {
    // End current call (if any) and restart search
    WebRTCService.instance.endCall();
    // Small delay to ensure cleanup before new search if needed,
    // or just call search immediately. Service handles logic.
    WebRTCService.instance.startRandomSearch();

    // Reset local controls state if desired, or keep them persistent
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Layer 1: Background / Remote Video / Sonar
          _buildBackgroundLayer(),

          // Layer 2: PiP Local Video
          _buildPipLayer(),

          // Layer 3: Controls
          _buildControlsLayer(),
        ],
      ),
    );
  }

  Widget _buildBackgroundLayer() {
    return ValueListenableBuilder<String>(
      valueListenable: WebRTCService.instance.connectionState,
      builder: (context, state, child) {
        // We consider 'searching' or 'connecting' as not yet "fully connected" for video purposes?
        // Actually, 'connecting' might have video starting.
        // But let's say only 'connected' (socket connected) AND remoteStream != null means we show remote video?
        // Let's rely on stream presence for video, and state for overlay text.

        final hasRemoteVideo =
            WebRTCService.instance.remoteStream.value != null;

        if (hasRemoteVideo) {
          return SizedBox.expand(
            child: RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          );
        } else {
          // Show Sonar if we are searching or connecting without video yet
          String statusText = 'Searching Global Network...';
          if (state == 'connecting') statusText = 'Connecting to Peer...';

          return _buildSonarRadar(statusText);
        }
      },
    );
  }

  Widget _buildSonarRadar(String statusText) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Ripple 1
        AnimatedBuilder(
          animation: _sonarController,
          builder: (context, child) {
            return Container(
              width: 100 + (_sonarController.value * 200),
              height: 100 + (_sonarController.value * 200),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.green.withOpacity(1 - _sonarController.value),
                  width: 2,
                ),
              ),
            );
          },
        ),
        // Ripple 2 (Delayed)
        AnimatedBuilder(
          animation: _sonarController,
          builder: (context, child) {
            final value = (_sonarController.value + 0.5) % 1.0;
            return Container(
              width: 100 + (value * 200),
              height: 100 + (value * 200),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.green.withOpacity(1 - value),
                  width: 2,
                ),
              ),
            );
          },
        ),
        // Center Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(Icons.radar, color: Colors.green, size: 40),
        ),
        // Status Text
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.3,
          child: Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPipLayer() {
    return ValueListenableBuilder<MediaStream?>(
      valueListenable: WebRTCService.instance.localStream,
      builder: (context, stream, child) {
        if (stream == null) return const SizedBox.shrink();

        return Positioned(
          top: 50,
          right: 20,
          child: Container(
            width: 100,
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 8,
                ),
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
          ),
        );
      },
    );
  }

  Widget _buildControlsLayer() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          // Blur Effect
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mic Toggle
                  _buildGlassIconButton(
                    icon: _isMicOn ? Icons.mic : Icons.mic_off,
                    onTap: () {
                      setState(() {
                        _isMicOn = !_isMicOn;
                        WebRTCService.instance.localStream.value
                            ?.getAudioTracks()
                            .forEach((track) {
                          track.enabled = _isMicOn;
                        });
                      });
                    },
                  ),
                  const SizedBox(width: 16),

                  // Camera Toggle
                  _buildGlassIconButton(
                    icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                    onTap: () {
                      setState(() {
                        _isCameraOn = !_isCameraOn;
                        WebRTCService.instance.localStream.value
                            ?.getVideoTracks()
                            .forEach((track) {
                          track.enabled = _isCameraOn;
                        });
                      });
                    },
                  ),
                  const SizedBox(width: 24),

                  // Next Match Button
                  _buildNextButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton(
      {required IconData icon, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildNextButton() {
    return GestureDetector(
      onTap: _handleNextMatch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Text(
          'Next Match',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
