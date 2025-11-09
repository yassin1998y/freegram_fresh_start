import 'package:flutter/material.dart';
import 'package:freegram/services/presence_manager.dart';
import 'package:freegram/utils/chat_presence_constants.dart';
import 'package:freegram/widgets/chat_widgets/professional_typing_indicator.dart';

/// Professional Presence Indicator Widget
///
/// Shows user's online status with:
/// - Animated transitions
/// - Multiple states (Active/Online/Away/Offline)
/// - Optional pulse animation for active users
/// - Accessibility support
class ProfessionalPresenceIndicator extends StatefulWidget {
  final Stream<PresenceData> presenceStream;
  final double size;
  final bool showPulse;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;

  const ProfessionalPresenceIndicator({
    super.key,
    required this.presenceStream,
    this.size = ChatPresenceConstants.onlineIndicatorSize,
    this.showPulse = true,
    this.showBorder = true,
    this.borderColor,
    this.borderWidth = ChatPresenceConstants.onlineIndicatorBorderWidth,
  });

  @override
  State<ProfessionalPresenceIndicator> createState() =>
      _ProfessionalPresenceIndicatorState();
}

class _ProfessionalPresenceIndicatorState
    extends State<ProfessionalPresenceIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: ChatPresenceConstants.pulseAnimationDuration,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.showPulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PresenceData>(
      stream: widget.presenceStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Loading state - shimmer
          return _buildShimmer();
        }

        final presence = snapshot.data!;
        final shouldPulse = presence.showActiveNow && widget.showPulse;

        // Start/stop pulse based on active status
        if (shouldPulse && !_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        } else if (!shouldPulse && _pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.value = 0;
        }

        return Semantics(
          label: presence.showActiveNow
              ? ChatPresenceConstants.semanticActive
              : '${ChatPresenceConstants.semanticLastSeen} ${presence.getDisplayText(includePrefix: false)}',
          child: AnimatedContainer(
            duration: ChatPresenceConstants.statusTransitionDuration,
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: presence.color,
              border: widget.showBorder
                  ? Border.all(
                      color: widget.borderColor ??
                          Theme.of(context).scaffoldBackgroundColor,
                      width: widget.borderWidth,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: presence.color.withOpacity(0.4),
                  blurRadius: ChatPresenceConstants.onlineIndicatorShadowBlur,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: shouldPulse
                ? AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: presence.color.withOpacity(
                              0.3 * (1 - _pulseController.value),
                            ),
                            width: 2 * _pulseAnimation.value,
                          ),
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: ChatPresenceConstants.shimmerDuration,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
              border: widget.showBorder
                  ? Border.all(
                      color: widget.borderColor ??
                          Theme.of(context).scaffoldBackgroundColor,
                      width: widget.borderWidth,
                    )
                  : null,
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }
}

/// Status text widget with proper formatting
class ProfessionalPresenceText extends StatelessWidget {
  final Stream<PresenceData> presenceStream;
  final bool isTyping;
  final TextStyle? style;
  final TextStyle? typingStyle;
  final bool includePrefix;

  const ProfessionalPresenceText({
    super.key,
    required this.presenceStream,
    this.isTyping = false,
    this.style,
    this.typingStyle,
    this.includePrefix = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isTyping) {
      return ProfessionalTypingIndicator(
        color: typingStyle?.color ?? ChatPresenceConstants.typingColor,
        fontSize: typingStyle?.fontSize ?? 12,
      );
    }

    return StreamBuilder<PresenceData>(
      stream: presenceStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text(
            '',
            style: style,
          );
        }

        final presence = snapshot.data!;
        final displayText =
            presence.getDisplayText(includePrefix: includePrefix);
        final isActive = presence.showActiveNow;

        return AnimatedSwitcher(
          duration: ChatPresenceConstants.statusTransitionDuration,
          child: Text(
            displayText,
            key: ValueKey(displayText),
            style: style?.copyWith(
                  color: isActive
                      ? ChatPresenceConstants.activeColor
                      : style?.color,
                ) ??
                TextStyle(
                  color: isActive
                      ? ChatPresenceConstants.activeColor
                      : Colors.grey[600],
                  fontSize: 12,
                ),
          ),
        );
      },
    );
  }
}

/// Badge for chat list showing short last seen
class PresenceBadge extends StatelessWidget {
  final Stream<PresenceData> presenceStream;
  final EdgeInsets? padding;

  const PresenceBadge({
    super.key,
    required this.presenceStream,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PresenceData>(
      stream: presenceStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final presence = snapshot.data!;
        final shortText = presence.getShortDisplayText();

        if (shortText.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: padding ??
              const EdgeInsets.symmetric(
                horizontal: ChatPresenceConstants.lastSeenBadgePadding,
                vertical: ChatPresenceConstants.lastSeenBadgePadding / 2,
              ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.grey,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            shortText,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: ChatPresenceConstants.lastSeenBadgeFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}
