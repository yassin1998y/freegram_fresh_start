import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/interaction/interaction_bloc.dart';
import 'package:freegram/blocs/interaction/interaction_state.dart';
import 'package:freegram/screens/random_chat/widgets/gift_reveal_modal.dart';

class InteractionOverlay extends StatefulWidget {
  const InteractionOverlay({super.key});

  @override
  State<InteractionOverlay> createState() => _InteractionOverlayState();
}

class _InteractionOverlayState extends State<InteractionOverlay> {
  // --- Gift Animation State ---
  String? _currentAnimationAsset;
  bool _isPlaying = false;

  // --- Chat Bubble State ---
  final List<_ChatMessage> _messages = [];

  void _playGiftAnimation(String assetUrl) {
    if (mounted) {
      setState(() {
        _currentAnimationAsset = assetUrl;
        _isPlaying = true;
      });
    }
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
          // 1. Gift Reveal Layer (Full Screen with Blur)
          if (_isPlaying && _currentAnimationAsset != null)
            GiftRevealModal(
              animationUrl: _currentAnimationAsset!,
              onComplete: () {
                if (mounted) {
                  setState(() {
                    _isPlaying = false;
                    _currentAnimationAsset = null;
                  });
                }
              },
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
          color: Colors.black.withValues(alpha: 0.6),
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
