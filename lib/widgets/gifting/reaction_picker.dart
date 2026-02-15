import 'package:flutter/material.dart';
import 'package:freegram/utils/haptic_helper.dart';

/// Quick reaction picker for gifts
class ReactionPicker extends StatelessWidget {
  final Function(String) onReactionSelected;
  final bool showThankYou;

  const ReactionPicker({
    super.key,
    required this.onReactionSelected,
    this.showThankYou = true,
  });

  static const List<String> reactions = [
    '❤️',
    '😍',
    '🎉',
    '🙏',
    '😊',
    '🔥',
    '👏',
    '🎁'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Text(
            'React to this gift',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 16),

          // Reactions grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: reactions.map((reaction) {
              return _ReactionButton(
                reaction: reaction,
                onTap: () {
                  HapticHelper.light();
                  onReactionSelected(reaction);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),

          if (showThankYou) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Thank you button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticHelper.success();
                  onReactionSelected('thank_you');
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.favorite, size: 20),
                label: const Text('Send Thank You'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatefulWidget {
  final String reaction;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.reaction,
    required this.onTap,
  });

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              widget.reaction,
              style: const TextStyle(fontSize: 32),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact reaction display for gift cards
class ReactionDisplay extends StatelessWidget {
  final List<String> reactions;
  final int totalCount;
  final VoidCallback? onTap;

  const ReactionDisplay({
    super.key,
    required this.reactions,
    required this.totalCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final displayReactions = reactions.take(3).toList();
    final hasMore = reactions.length > 3;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...displayReactions.map((reaction) => Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Text(reaction, style: const TextStyle(fontSize: 16)),
                )),
            if (hasMore)
              Text(
                '+${reactions.length - 3}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (totalCount > reactions.length) ...[
              const SizedBox(width: 4),
              Text(
                '($totalCount)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Animated reaction bubble that floats up
class ReactionBubble extends StatefulWidget {
  final String reaction;
  final VoidCallback? onComplete;

  const ReactionBubble({
    super.key,
    required this.reaction,
    this.onComplete,
  });

  @override
  State<ReactionBubble> createState() => _ReactionBubbleState();
}

class _ReactionBubbleState extends State<ReactionBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 0, end: -100).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
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
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Text(
                widget.reaction,
                style: const TextStyle(fontSize: 48),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One-tap thank you button
class QuickThankYouButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final bool hasThanked;

  const QuickThankYouButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.hasThanked = false,
  });

  @override
  Widget build(BuildContext context) {
    if (hasThanked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
            const SizedBox(width: 4),
            Text(
              'Thanked',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.favorite, size: 16),
      label: Text(isLoading ? 'Sending...' : 'Say Thanks'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
      ),
    );
  }
}
