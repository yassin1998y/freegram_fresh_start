import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/widgets/gifting/gift_visual.dart';
import '../../repositories/random_chat_repository.dart';
import 'widgets/pulse_avatar.dart';

class RandomChatScreen extends StatefulWidget {
  final bool isVisible;
  const RandomChatScreen({super.key, this.isVisible = true});

  @override
  State<RandomChatScreen> createState() => _RandomChatScreenState();
}

class _RandomChatScreenState extends State<RandomChatScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final RandomChatRepository _repository = RandomChatRepository();
  final GiftRepository _giftRepository = GiftRepository();

  bool _initialized = false;
  String _statusText = "Initializing...";
  bool _isCameraOn = true;
  bool _isMicOn = true;
  bool _isConnected = false;
  bool _isSearching = false;
  bool _controlsVisible = true;
  bool _showDebug = false;

  // Gifting
  late AnimationController _giftAnimationController;
  late Animation<double> _giftScaleAnimation;
  GiftModel? _currentGift;

  @override
  void didUpdateWidget(RandomChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isVisible && oldWidget.isVisible) {
      debugPrint("🙈 [RandomChatScreen] Tab hidden, pausing connection...");
      _stopSearch(); // Stop active searching/connection
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _giftAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _giftScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.5)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: 1.5, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 50),
    ]).animate(_giftAnimationController);

    _giftAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _currentGift = null);
        _giftAnimationController.reset();
      }
    });

    _checkToS();
  }

  Future<void> _checkToS() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('random_chat_tos_accepted') ?? false;

    if (!accepted && mounted) {
      await _showToSModal();
    }

    // Continue with initialization
    await _initializeRenderers(); // Init Video Renderers ONCE
    await _setupConnection(); // Setup logic and stream
  }

  Future<void> _showToSModal() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Community Guidelines",
            style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "Welcome to Random Chat! Please follow these rules to keep our community safe:",
                style: TextStyle(color: Colors.white70)),
            SizedBox(height: 16),
            Text("1. No Nudity or Sexual Content.",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            Text("2. No Harassment or Hate Speech.",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            Text("3. No Illegal Activities.",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text("Violations will result in a permanent ban.",
                style: TextStyle(color: Colors.redAccent)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close screen
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5)),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('random_chat_tos_accepted', true);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text("I Agree", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      debugPrint("⏸️ [RandomChatScreen] App paused, releasing resources...");
      // Full dispose on pause to release camera hardware
      _repository.dispose();

      if (mounted) {
        setState(() {
          _isConnected = false;
          _isSearching = false;
          // We DO detach streams on pause because we disposed the tracks
          _localRenderer.srcObject = null;
          _remoteRenderer.srcObject = null;
          _statusText = "Paused";
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("▶️ [RandomChatScreen] App resumed, re-initializing...");
      // Re-initialize connection (will restart camera)
      // Note: renderers are still initialized, we just need new stream
      _setupConnection();
    }
  }

  // 1. Initialize View Renderers (Once per screen lifecycle)
  Future<void> _initializeRenderers() async {
    debugPrint("🎥 [RandomChatScreen] Initializing Video Renderers...");
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  // 2. Setup Logic & Streams (Can be called repeatedly)
  Future<void> _setupConnection() async {
    debugPrint("🔄 [RandomChatScreen] Setting up connection logic...");
    _repository.onLocalStream = (stream) {
      if (mounted && _localRenderer.srcObject != stream) {
        debugPrint("🎥 [RandomChatScreen] Attaching Local Stream");
        setState(() {
          _localRenderer.srcObject = stream;
        });
      }
    };
    _repository.onRemoteStream = (stream) {
      if (mounted && _remoteRenderer.srcObject != stream) {
        debugPrint("📺 [RandomChatScreen] Attaching Remote Stream");
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      }
    };

    _repository.onGiftReceived = (data) {
      if (mounted) {
        // Construct a partial GiftModel from the received data for visualization
        final gift = GiftModel.fromMap(data['giftId'], data);
        setState(() {
          _currentGift = gift;
        });
        _giftAnimationController.forward(from: 0.0);
      }
    };

    _repository.onConnected = () {
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isSearching = false;
          _statusText = "Connected";
        });
      }
    };
    _repository.onDisconnected = () {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isSearching = false;
          _remoteRenderer.srcObject = null; // Detach remote only
          _statusText = "Disconnected";
        });
      }
    };
    _repository.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        setState(() {
          _statusText = "Error: $error";
        });
      }
    };

    _repository.onStatusChanged = (status) {
      if (mounted) {
        setState(() {
          _statusText = status;
        });
      }
    };

    await [Permission.camera, Permission.microphone].request();
    await _repository.initialize(); // Starts camera if needed

    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // 0. STOP LISTENING to prevents crashes during dispose
    _repository.onStatusChanged = null;
    _repository.onLocalStream = null;
    _repository.onRemoteStream = null;
    _repository.onConnected = null;
    _repository.onDisconnected = null;
    _repository.onError = null;
    _repository.onGiftReceived = null;

    // Strict Cleanup Order:
    // 1. Detach streams from renderers (prevents "in use" errors)
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;

    // 2. Dispose renderers
    _localRenderer.dispose();
    _remoteRenderer.dispose();

    // 3. Dispose controller
    _giftAnimationController.dispose();

    // 4. Dispose repository (Stops camera/mic/connection)
    _repository.dispose();

    super.dispose();
  }

  void _startSearch([String reason = "Unknown"]) {
    debugPrint("🚀 [RandomChatScreen] _startSearch called. Reason: $reason");
    setState(() {
      _isSearching = true;
      _isConnected = false;
      _statusText = "Searching for nearby people...";
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _repository.enterQueue(user.uid);
    }
  }

  void _nextMatch() {
    debugPrint("⏭️ [RandomChatScreen] _nextMatch called");
    _startSearch("Next Match");
  }

  Future<void> _stopSearch() async {
    debugPrint("🛑 [RandomChatScreen] _stopSearch called");
    // ONLY stop the connection logic, preserve the camera!
    await _repository.stopConnection();

    if (mounted) {
      setState(() {
        _isSearching = false;
        _isConnected = false;
        // Keep local renderer attached!
        _remoteRenderer.srcObject = null;
        _statusText = "Ready";
      });
    }
  }

  void _handleSwipe(DragEndDetails details) {
    if (!_isConnected) return;
    if (details.primaryVelocity! < -500) {
      _nextMatch();
    }
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOn = !_isCameraOn;
    });
    _repository.toggleVideo(_isCameraOn);
  }

  void _toggleMic() {
    setState(() {
      _isMicOn = !_isMicOn;
    });
    _repository.toggleAudio(_isMicOn);
  }

  void _showOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.orangeAccent),
              title: const Text("Report User",
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.redAccent),
              title: const Text("Block User",
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmDialog();
              },
            ),
            ListTile(
              leading: Icon(
                  _showDebug ? Icons.bug_report : Icons.bug_report_outlined,
                  color: Colors.lightGreenAccent),
              title: Text(_showDebug ? "Hide Debug Info" : "Show Debug Info",
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _showDebug = !_showDebug);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.grey),
              title:
                  const Text("Cancel", style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    final reasons = ["Inappropriate Content", "Harassment", "Spam", "Other"];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Report User", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map((r) => ListTile(
                    title:
                        Text(r, style: const TextStyle(color: Colors.white70)),
                    onTap: () {
                      Navigator.pop(context);
                      _submitReport(r);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    final remoteId = _repository.currentRemoteUserId;
    if (myId != null && remoteId != null) {
      await _repository.reportUser(
          myId: myId, remoteId: remoteId, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User reported. Skipping...")),
        );
        _nextMatch();
      }
    }
  }

  void _showBlockConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Block User", style: TextStyle(color: Colors.white)),
        content: const Text(
            "Are you sure? You won't be matched with this user again.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child:
                const Text("Block", style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              Navigator.pop(context);
              _performBlock();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _performBlock() async {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    final remoteId = _repository.currentRemoteUserId;
    if (myId != null && remoteId != null) {
      await _repository.blockUser(myId: myId, remoteId: remoteId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User blocked. Skipping...")),
        );
        _nextMatch();
      }
    }
  }

  void _showGiftPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Send a Gift",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<GiftModel>>(
                stream: _giftRepository.getAvailableGifts(),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return Center(
                        child: Text("Error: ${snapshot.error}",
                            style: const TextStyle(color: Colors.white)));
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  final gifts = snapshot.data!;
                  if (gifts.isEmpty)
                    return const Center(
                        child: Text("No gifts available",
                            style: TextStyle(color: Colors.white)));

                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: gifts.length,
                    itemBuilder: (context, index) {
                      final gift = gifts[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _sendGift(gift);
                        },
                        child: Column(
                          children: [
                            Expanded(
                                child: GiftVisual(
                                    gift: gift,
                                    size: 80,
                                    showRarityBackground: true)),
                            const SizedBox(height: 4),
                            Text(gift.name,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                            Text("${gift.priceInCoins} 💰",
                                style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendGift(GiftModel gift) async {
    // Show locally
    if (mounted) {
      setState(() {
        _currentGift = gift;
      });
      _giftAnimationController.forward(from: 0.0);
    }
    await _repository.sendGift(
      senderId: FirebaseAuth.instance.currentUser!.uid,
      giftId: gift.id,
      name: gift.name,
      animationUrl: gift.animationUrl,
      thumbnailUrl: gift.thumbnailUrl,
    );
  }

  Future<void> _sendFriendRequest() async {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    final remoteId = _repository.currentRemoteUserId;
    if (myId != null && remoteId != null) {
      await _repository.sendFriendRequest(myId: myId, remoteId: remoteId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Friend request sent!")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not connected to anyone.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFF00BFA5))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onHorizontalDragEnd: _handleSwipe,
        onTap: _toggleControls,
        child: Stack(
          children: [
            // 1. Full Screen Layer
            Positioned.fill(
              child: _isConnected && _remoteRenderer.srcObject != null
                  ? RTCVideoView(
                      _remoteRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_isCameraOn)
                          RTCVideoView(
                            _localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          )
                        else
                          Container(
                            color: Colors.grey[900],
                            child: Center(
                              child: PulseAvatar(
                                photoUrl:
                                    FirebaseAuth.instance.currentUser?.photoURL,
                                size: 80,
                              ),
                            ),
                          ),
                        // Overlay Gradient
                        Container(
                          decoration: BoxDecoration(
                              gradient: RadialGradient(
                            colors: [
                              Colors.black.withOpacity(0.2),
                              Colors.black.withOpacity(0.8)
                            ],
                            radius: 0.85,
                          )),
                        ),
                      ],
                    ),
            ),

            // 2. State Overlay
            if (!_isConnected)
              Positioned.fill(
                child: Center(
                  child: _isSearching
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Replaced Radar with Simple Activity Indicator
                            const SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF00BFA5)),
                              ),
                            ),
                            const SizedBox(height: 120),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Text(
                                  _statusText.isEmpty
                                      ? "Searching..."
                                      : _statusText,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.1),
                                  border: Border.all(
                                      color: Colors.white24, width: 2)),
                              child: const Icon(Icons.video_chat,
                                  color: Colors.white, size: 60),
                            ),
                            const SizedBox(height: 32),
                            const Text("Meet New People",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                          blurRadius: 15,
                                          color: Colors.black,
                                          offset: Offset(0, 2))
                                    ])),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Text(
                                  "Tap Start to begin. Be polite!",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                ),
              ),

            // 3. PiP Layer
            if (_isConnected)
              Positioned(
                right: 16,
                top: MediaQuery.of(context).padding.top + 16,
                width: 100,
                height: 150,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                        color: Colors.grey[900],
                        border: Border.all(color: Colors.white24),
                        boxShadow: [
                          const BoxShadow(
                              color: Colors.black54,
                              blurRadius: 10,
                              spreadRadius: 2)
                        ]),
                    child: _isCameraOn
                        ? RTCVideoView(
                            _localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          )
                        : Center(
                            child: PulseAvatar(
                              photoUrl:
                                  FirebaseAuth.instance.currentUser?.photoURL,
                              size: 40,
                            ),
                          ),
                  ),
                ),
              ),

            // 3.5. Mic/Cam Toggles (Top Left)
            // Always visible comfortably on top left
            Positioned(
              left: 16,
              top: MediaQuery.of(context).padding.top + 16,
              child: Row(
                children: [
                  _buildToggle(
                    icon: _isMicOn ? Icons.mic : Icons.mic_off,
                    isOn: _isMicOn,
                    onTap: _toggleMic,
                  ),
                  const SizedBox(width: 12),
                  _buildToggle(
                    icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                    isOn: _isCameraOn,
                    onTap: _toggleCamera,
                  ),
                  if (_isConnected) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _showOptionsModal,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.more_vert,
                            color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _showGiftPicker,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.pinkAccent.withOpacity(0.8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.pinkAccent.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1)
                            ]),
                        child: const Icon(Icons.card_giftcard,
                            color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _sendFriendRequest,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.blueAccent.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1)
                            ]),
                        child: const Icon(Icons.person_add,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 3.8 Gift Animation Overlay
            if (_currentGift != null)
              Positioned.fill(
                child: Center(
                  child: ScaleTransition(
                    scale: _giftScaleAnimation,
                    child: GiftVisual(
                      gift: _currentGift!,
                      size: 200,
                      animate: true,
                      showRarityBackground: false,
                    ),
                  ),
                ),
              ),

            // 4. Debug Overlay
            if (_showDebug && _controlsVisible)
              Positioned(
                top: 100,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _repository.getDebugInfo().entries.map((e) {
                      return Text("${e.key}: ${e.value}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontFamily: 'monospace'));
                    }).toList(),
                  ),
                ),
              ),

            // 4. Glassmorphic Bottom Controls
            if (_controlsVisible)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(35),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      height: 85,
                      color: Colors.black.withOpacity(0.6),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (!_isSearching && !_isConnected)
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00BFA5),
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  shadowColor:
                                      const Color(0xFF00BFA5).withOpacity(0.5),
                                  shape: const StadiumBorder(),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 20),
                                ),
                                onPressed: () =>
                                    _startSearch("User Button Tap"),
                                child: const Text("START MATCHING",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        letterSpacing: 1.0)),
                              ),
                            )
                          else if (_isSearching)
                            Container(
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white24, width: 2)),
                              child: IconButton(
                                onPressed: _stopSearch,
                                icon: const Icon(Icons.close,
                                    color: Colors.redAccent, size: 32),
                                style: IconButton.styleFrom(
                                    backgroundColor: Colors.white10,
                                    padding: const EdgeInsets.all(12)),
                              ),
                            )
                          else ...[
                            _buildGlassIcon(Icons.message, () {}),
                            _buildGlassIcon(Icons.person_add, () {}),
                            _buildGlassIcon(Icons.flag, () {}),
                            const SizedBox(width: 20),
                            FloatingActionButton(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 10,
                              onPressed: _nextMatch,
                              child: const Icon(Icons.arrow_forward, size: 28),
                            )
                          ]
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(
      {required IconData icon,
      required bool isOn,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOn
              ? Colors.black.withOpacity(0.4)
              : Colors.redAccent.withOpacity(0.8),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildGlassIcon(IconData icon, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      style: IconButton.styleFrom(
          backgroundColor: Colors.white24,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(14),
          side: const BorderSide(color: Colors.white12)),
    );
  }
}
