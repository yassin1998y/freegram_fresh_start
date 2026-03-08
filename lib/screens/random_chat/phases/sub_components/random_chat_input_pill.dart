import 'package:flutter/material.dart';
import 'package:freegram/screens/random_chat/widgets/glass_overlay_container.dart';
import 'package:freegram/theme/design_tokens.dart';

class RandomChatInputPill extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const RandomChatInputPill({
    super.key,
    required this.controller,
    required this.onSend,
  });

  @override
  State<RandomChatInputPill> createState() => _RandomChatInputPillState();
}

class _RandomChatInputPillState extends State<RandomChatInputPill> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassOverlayContainer(
      borderRadius: BorderRadius.circular(24.0),
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
      child: SizedBox(
        height: 48.0,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: DesignTokens.fontSizeMD,
                ),
                decoration: InputDecoration(
                  hintText: 'Say something...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: DesignTokens.fontSizeMD,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_hasText)
              GestureDetector(
                onTap: widget.onSend,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
