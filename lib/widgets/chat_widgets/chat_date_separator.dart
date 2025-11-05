// lib/widgets/chat_widgets/chat_date_separator.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:intl/intl.dart';

/// Sticky date separator for chat messages
/// Improvement #25 - Implement sticky date headers with glassmorphic background
class ChatDateSeparator extends StatelessWidget {
  final DateTime date;
  final bool isSticky;

  const ChatDateSeparator({
    super.key,
    required this.date,
    this.isSticky = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final formattedDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (formattedDate.isAtSameMomentAs(today)) {
      dateText = 'Today';
    } else if (formattedDate.isAtSameMomentAs(yesterday)) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat.yMMMd().format(date);
    }

    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: DesignTokens.spaceMD),
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMD,
          vertical: DesignTokens.spaceSM,
        ),
        decoration: BoxDecoration(
          color: isSticky
              ? Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
            width: 0.5,
          ),
          boxShadow: isSticky ? DesignTokens.shadowLight : null,
        ),
        child: Text(
          dateText,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: DesignTokens.fontSizeSM,
            fontWeight: FontWeight.w600,
            letterSpacing: DesignTokens.letterSpacingWide,
          ),
        ),
      ),
    );
  }
}

/// Auto-dismissing unread divider
/// Improvement #26 - Add auto-dismissing unread divider with animation
class UnreadMessagesDivider extends StatefulWidget {
  final int unreadCount;
  final VoidCallback? onDismiss;

  const UnreadMessagesDivider({
    super.key,
    this.unreadCount = 0,
    this.onDismiss,
  });

  @override
  State<UnreadMessagesDivider> createState() => _UnreadMessagesDividerState();
}

class _UnreadMessagesDividerState extends State<UnreadMessagesDivider>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: DesignTokens.durationNormal,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: DesignTokens.curveEaseOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: DesignTokens.curveEaseOut,
    ));

    _controller.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    if (mounted) {
      setState(() => _isVisible = false);
      widget.onDismiss?.call();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: DesignTokens.spaceMD),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Theme.of(context).colorScheme.primary,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: DesignTokens.spaceSM),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMD,
                    vertical: DesignTokens.spaceXS,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.unreadCount > 0
                            ? '${widget.unreadCount} Unread Message${widget.unreadCount > 1 ? 's' : ''}'
                            : 'Unread Messages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: DesignTokens.fontSizeXS,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}















