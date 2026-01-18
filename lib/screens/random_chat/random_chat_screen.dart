import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/report_model.dart';
import 'package:freegram/repositories/friend_repository.dart';
import 'package:freegram/repositories/report_repository.dart';
import 'package:freegram/services/webrtc_service.dart';
import 'package:permission_handler/permission_handler.dart';

class RandomChatScreen extends StatefulWidget {
  const RandomChatScreen({super.key});

  @override
  State<RandomChatScreen> createState() => _RandomChatScreenState();
}

enum ChatState { searching, connected, peerLeft }

class _RandomChatScreenState extends State<RandomChatScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  // PiP Position
  Offset _localVideoPosition = const Offset(20, 50);

  @override
  void initState() {
    super.initState();
    _initRenderers();

    // Register UI Callback
    WebRTCService.instance.onShowMessage = (message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    };

    _initializeWebRTC();

    // Listen to Streams & Toggles
    WebRTCService.instance.localStream.addListener(_updateLocalStream);
    WebRTCService.instance.remoteStream.addListener(_updateRemoteStream);
    WebRTCService.instance.connectionState
        .addListener(_onConnectionStateChange);
  }

  Future<void> _initializeWebRTC() async {
    try {
      await WebRTCService.instance.initialize();
      WebRTCService.instance.startRandomSearch();
    } catch (e) {
      if (e.toString().contains('Permissions Missing')) {
        _showPermissionError();
      }
    }
  }

  void _showPermissionError() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Camera access is required"),
        content: const Text(
            "Please enable camera and microphone access to find a match."),
        actions: [
          ElevatedButton(
            onPressed: () {
              openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _updateLocalStream() {
    if (mounted) {
      setState(() {
        _localRenderer.srcObject = WebRTCService.instance.localStream.value;
      });
    }
  }

  void _updateRemoteStream() {
    if (mounted) {
      setState(() {
        _remoteRenderer.srcObject = WebRTCService.instance.remoteStream.value;
      });
    }
  }

  void _onConnectionStateChange() {
    if (mounted) setState(() {});
  }

  ChatState get _currentState {
    final status = WebRTCService.instance.connectionState.value;
    if (status == 'connected') return ChatState.connected;
    if (status == 'disconnected') return ChatState.peerLeft;
    // Default to searching if 'searching', 'connecting', 'new', etc.
    return ChatState.searching;
  }

  @override
  void dispose() {
    WebRTCService.instance.localStream.removeListener(_updateLocalStream);
    WebRTCService.instance.remoteStream.removeListener(_updateRemoteStream);
    WebRTCService.instance.connectionState
        .removeListener(_onConnectionStateChange);
    WebRTCService.instance.onShowMessage = null; // Clean up callback
    WebRTCService.instance.endCall();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  void _skipMatch() {
    WebRTCService.instance.endCall();
    WebRTCService.instance.startRandomSearch();
  }

  // --- Dialogs ---

  void _showReportDialog() {
    final partnerId = WebRTCService.instance.currentPartnerId.value;
    if (partnerId == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Report User"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReportOption("Nudity or Sexual Content",
                  ReportCategory.inappropriate, partnerId),
              _buildReportOption("Harassment or Abusive Language",
                  ReportCategory.harassment, partnerId),
              _buildReportOption(
                  "Spam or Scam", ReportCategory.spam, partnerId),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportOption(
      String title, ReportCategory category, String partnerId) {
    return ListTile(
      title: Text(title),
      onTap: () async {
        Navigator.pop(context); // Close dialog

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          try {
            await locator<ReportRepository>().reportContent(
              contentType: ReportContentType.user,
              contentId: partnerId,
              userId: currentUser.uid,
              category: category,
              reason: title,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("User reported and blocked.")),
              );
            }
          } catch (e) {
            debugPrint("Report failed: $e");
          }
        }
        _skipMatch();
      },
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const FilterSelectionSheet(),
    );
  }

  void _sendFriendRequest(String partnerId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await locator<FriendRepository>().sendFriendRequest(
          currentUser.uid,
          partnerId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Friend request sent!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to send request: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // --- Build ---

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Layer 1: Background (State aware)
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (_currentState == ChatState.connected &&
                  details.primaryVelocity != null &&
                  details.primaryVelocity! < -500) {
                _skipMatch();
              }
            },
            child: _buildSmartBackground(),
          ),

          // Layer 2: Heads Up Overlay (Top Controls)
          if (_currentState == ChatState.connected) _buildHeadsUpOverlay(),

          if (_currentState == ChatState.peerLeft) _buildPeerLeftOverlay(),

          // Layer 3: Controls Overlay (Bottom)
          _buildControlsOverlay(),

          // Layer 4: Draggable Local Preview (Only when connected or searching?)
          // Usually always visible so user sees themselves
          _buildLocalPreview(),
        ],
      ),
    );
  }

  // Layer 1
  // Layer 1
  Widget _buildSmartBackground() {
    final remoteStream = WebRTCService.instance.remoteStream.value;
    final state = _currentState;

    // Check if video track is enabled to detect "Dark Screen"
    bool isRemoteVideoOn = false;
    if (remoteStream != null) {
      final videoTracks = remoteStream.getVideoTracks();
      if (videoTracks.isNotEmpty && videoTracks[0].enabled) {
        isRemoteVideoOn = true;
      }
    }

    Widget child;

    if (state == ChatState.connected && remoteStream != null) {
      if (isRemoteVideoOn) {
        child = SizedBox.expand(
          key: const ValueKey('remoteVideo'),
          child: RTCVideoView(
            _remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        );
      } else {
        // Connected but Video OFF -> Voice Pulse Effect
        child = SizedBox.expand(
          key: const ValueKey('voicePulse'),
          child: _buildVoicePulseView(),
        );
      }
    } else if (state == ChatState.peerLeft) {
      // Peer Left State
      child = Container(
        key: const ValueKey('peerLeft'),
        color: Colors.black, // Or blurred last frame if we could capture it
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 80, color: Colors.white54),
              const SizedBox(height: 20),
              const Text("Partner disconnected",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    } else {
      // Searching state
      child = Container(
        key: const ValueKey('searching'),
        child: _buildSearchingView(),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: child,
    );
  }

  // Sub-widgets for Background
  Widget _buildSearchingView() {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred BG
        if (photoUrl != null)
          Image.network(
            photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: Colors.grey.shade900),
          )
        else
          Container(color: Colors.grey.shade900),

        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.black.withValues(alpha: 0.5)),
        ),

        // Pulse Animation
        Center(
          child: PulseAvatar(photoUrl: photoUrl),
        ),

        // Text
        Positioned(
          bottom: 200,
          left: 0,
          right: 0,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.2, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              builder: (context, val, _) => Opacity(
                opacity: val,
                child: const Text(
                  "Finding your match...",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              onEnd: () {/* Repeat manually if needed */},
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoicePulseView() {
    // Shows when connected but remote user disabled camera
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.grey.shade900),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PulseAvatar(
                  photoUrl: null,
                  isVoiceMode: true), // Use default or specific asset
              const SizedBox(height: 20),
              const Text(
                "Audio Only",
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Layer 2
  Widget _buildHeadsUpOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report Button
            GestureDetector(
              onTap: _showReportDialog,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag, color: Colors.white, size: 22),
              ),
            ),

            // Add Friend (Center) - Only if connected/partner known
            ValueListenableBuilder<String?>(
              valueListenable: WebRTCService.instance.currentPartnerId,
              builder: (context, partnerId, _) {
                if (partnerId == null) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => _sendFriendRequest(partnerId),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white54),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.person_add, color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Text("Add Friend",
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Close Button
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeerLeftOverlay() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  // Layer 3
  Widget _buildControlsOverlay() {
    final state = _currentState;

    // If Peer Left, show "Find Next"
    if (state == ChatState.peerLeft) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: SizedBox(
            width: 200,
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: _skipMatch,
              icon: const Icon(Icons.search, color: Colors.black),
              label: const Text("Find Next",
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      );
    }

    // If Searching, show minimal or nothing (Text is in background)
    if (state == ChatState.searching) {
      return const SizedBox.shrink(); // Hide controls when searching
    }

    // If Connected, show full controls
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 180, // Taller for better gradient
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

            // SKIP Button (Big)
            SizedBox(
              width: 75,
              height: 75,
              child: FloatingActionButton(
                onPressed: _skipMatch,
                backgroundColor: Colors.white,
                elevation: 10,
                child:
                    const Icon(Icons.skip_next, color: Colors.black, size: 36),
              ),
            ),

            // Gift Button
            IconButton(
              icon: const Icon(Icons.card_giftcard, size: 30),
              color: Colors.amber,
              onPressed: () {
                // Open Gift Sheet
              },
            ),

            // Filter Button
            IconButton(
              icon: const Icon(Icons.tune, size: 30),
              color: Colors.white,
              onPressed: _showFilterSheet,
            ),
          ],
        ),
      ),
    );
  }

  // Layer 4
  Widget _buildLocalPreview() {
    return UserVideoDraggable(
      renderer: _localRenderer,
      initialPosition: _localVideoPosition,
      onDragEnd: (pos) => setState(() => _localVideoPosition = pos),
    );
  }
}

// --- Helpers Widgets ---

class PulseAvatar extends StatefulWidget {
  final String? photoUrl;
  final bool isVoiceMode;
  const PulseAvatar({super.key, this.photoUrl, this.isVoiceMode = false});

  @override
  State<PulseAvatar> createState() => _PulseAvatarState();
}

class _PulseAvatarState extends State<PulseAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Ripple 1
        FadeTransition(
          opacity: Tween(begin: 0.6, end: 0.0).animate(_controller),
          child: ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.5).animate(_controller),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
        // Avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            color: Colors.grey.shade800,
            image: widget.photoUrl != null
                ? DecorationImage(
                    image: NetworkImage(widget.photoUrl!),
                    fit: BoxFit.cover,
                    onError: (_, __) =>
                        {}) // Basic error handling, though image provider might still throw
                : null,
          ),
          child: widget.photoUrl == null
              ? const Icon(Icons.person, color: Colors.white, size: 50)
              : Image.network(
                  widget.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.person, color: Colors.white, size: 50),
                ), // Use Child image for better error handling than DecorationImage
        ),
        if (widget.isVoiceMode)
          const Icon(Icons.mic, color: Colors.white, size: 40),
      ],
    );
  }
}

class UserVideoDraggable extends StatefulWidget {
  final RTCVideoRenderer renderer;
  final Offset initialPosition;
  final Function(Offset) onDragEnd;

  const UserVideoDraggable({
    super.key,
    required this.renderer,
    required this.initialPosition,
    required this.onDragEnd,
  });

  @override
  State<UserVideoDraggable> createState() => _UserVideoDraggableState();
}

class _UserVideoDraggableState extends State<UserVideoDraggable> {
  late Offset _offset;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialPosition;
  }

  @override
  void didUpdateWidget(covariant UserVideoDraggable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _offset = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset += details.delta;
          });
        },
        onPanEnd: (details) {
          widget.onDragEnd(_offset);
        },
        child: ValueListenableBuilder<bool>(
          valueListenable: WebRTCService.instance.isCameraOn,
          builder: (context, isCam, _) {
            return Container(
              width: 100,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 8),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: isCam
                    ? RTCVideoView(
                        widget.renderer,
                        mirror: true,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : Container(
                        color: Colors.grey.shade900,
                        child:
                            const Icon(Icons.videocam_off, color: Colors.white),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class FilterSelectionSheet extends StatefulWidget {
  const FilterSelectionSheet({super.key});

  @override
  State<FilterSelectionSheet> createState() => _FilterSelectionSheetState();
}

class _FilterSelectionSheetState extends State<FilterSelectionSheet> {
  bool isPremium = false; // Mock Variable
  String _selectedGender = 'Both';
  String _selectedRegion = 'Global';

  void _showPaywall() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Unlock Premium Filters 💎"),
        content: const Text(
            "Filter by Gender and Location is available only for Freegram+ members."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/store');
            },
            child: const Text("Get Premium"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Match Filters",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text("Gender", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildFilterChip('Both', true),
              const SizedBox(width: 8),
              _buildFilterChip('Male', false),
              const SizedBox(width: 8),
              _buildFilterChip('Female', false),
            ],
          ),
          const SizedBox(height: 20),
          const Text("Region", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildFilterChip('Global', true, isRegion: true),
              const SizedBox(width: 8),
              _buildFilterChip('Nearby', false, isRegion: true),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isDefault,
      {bool isRegion = false}) {
    final bool isSelected =
        isRegion ? _selectedRegion == label : _selectedGender == label;
    final bool isLocked = !isPremium && !isDefault;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isLocked) ...[
            const SizedBox(width: 4),
            const Icon(Icons.lock, size: 14, color: Colors.grey),
          ]
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          if (isLocked) {
            _showPaywall();
          } else {
            setState(() {
              if (isRegion) {
                _selectedRegion = label;
              } else {
                _selectedGender = label;
              }
            });
          }
        }
      },
    );
  }
}
