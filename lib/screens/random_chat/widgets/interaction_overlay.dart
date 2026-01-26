import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:freegram/blocs/interaction/interaction_bloc.dart';
import 'package:freegram/blocs/interaction/interaction_state.dart';

class InteractionOverlay extends StatefulWidget {
  const InteractionOverlay({super.key});

  @override
  State<InteractionOverlay> createState() => _InteractionOverlayState();
}

class _InteractionOverlayState extends State<InteractionOverlay>
    with TickerProviderStateMixin {
  // --- Gift Animation State ---
  String? _currentAnimationAsset;
  bool _isPlaying = false;
  AnimationController? _lottieController;

  // --- Chat Bubble State ---
  final List<_ChatMessage> _messages = [];
  // final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>(); // Unused

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _lottieController?.dispose();
    super.dispose();
  }

  void _playGiftAnimation(String assetUrl) {
    setState(() {
      _currentAnimationAsset = assetUrl;
      _isPlaying = true;
    });

    _lottieController?.duration = const Duration(seconds: 3);
    _lottieController?.forward(from: 0).whenComplete(() {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  void _addChatMessage(String text, String sender) {
    final message = _ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      sender: sender,
    );

    setState(() {
      _messages.add(message);
    });

    // Auto-remove after 5 seconds
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _messages.remove(message);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InteractionBloc, InteractionState>(
      listener: (context, state) {
        if (state is GiftReceivedState) {
          if (state.gift.animationUrl.isNotEmpty) {
            _playGiftAnimation(state.gift.animationUrl);
          }
        } else if (state is ChatReceivedState) {
          _addChatMessage(state.text, state.senderName);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Gift Animation Layer (Centered)
          if (_isPlaying && _currentAnimationAsset != null)
            Center(
              child: Lottie.asset(
                _currentAnimationAsset!,
                controller: _lottieController,
                onLoaded: (composition) {
                  _lottieController?.duration = composition.duration;
                  _lottieController?.forward(from: 0);
                },
                height: 300,
                width: 300,
                // createWindow: false, // Removed invalid param
              ),
            ),

          // 2. Chat Bubbles Layer (Bottom Left)
          Positioned(
            left: 16,
            bottom: 120, // Above control bar
            right: 100, // Leave space for right controls
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children:
                  _messages.map((msg) => _ChatBubble(message: msg)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String id;
  final String text;
  final String sender;

  _ChatMessage({required this.id, required this.text, required this.sender});
}

class _ChatBubble extends StatefulWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.message.sender,
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.message.text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
