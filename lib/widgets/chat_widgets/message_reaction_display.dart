// lib/widgets/chat_widgets/message_reaction_display.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Professional reaction display for messages
/// Improvement #34 - Redesign message reactions with avatars and tap-to-see-who
class MessageReactionDisplay extends StatelessWidget {
  final Map<String, String> reactions;
  final bool isMe;
  final VoidCallback? onTap;

  const MessageReactionDisplay({
    super.key,
    required this.reactions,
    required this.isMe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    // Group reactions by emoji
    final Map<String, int> reactionCounts = {};
    for (final emoji in reactions.values) {
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    return GestureDetector(
      onTap: onTap ??
          () {
            // Show who reacted
            _showReactionDetails(context);
          },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceSM,
          vertical: DesignTokens.spaceXS,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: reactionCounts.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (entry.value > 1) ...[
                    const SizedBox(width: 2),
                    Text(
                      entry.value.toString(),
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeXS,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showReactionDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusXL)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: DesignTokens.spaceMD),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Text(
                'Reactions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: DesignTokens.spaceMD),

              // List of reactions
              ...reactions.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: DesignTokens.spaceSM),
                  child: Row(
                    children: [
                      Text(
                        entry.value,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: DesignTokens.spaceMD),
                      Expanded(
                        child: Text(
                          entry.key == reactions.entries.first.key
                              ? 'You'
                              : 'User ${entry.key.substring(0, 8)}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}

























