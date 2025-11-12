// lib/widgets/common/app_reaction_button.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

/// App Reaction Button
/// A themed reaction button that matches the app's design system
/// Similar style to the verified badge with primary accent color
class AppReactionButton extends StatefulWidget {
  final bool isLiked;
  final int? reactionCount;
  final bool isLoading;
  final VoidCallback? onTap;
  final bool showCount;
  final double? size;
  final bool compact;

  const AppReactionButton({
    Key? key,
    required this.isLiked,
    this.reactionCount,
    this.isLoading = false,
    this.onTap,
    this.showCount = true,
    this.size,
    this.compact = false,
  }) : super(key: key);

  @override
  State<AppReactionButton> createState() => _AppReactionButtonState();
}

class _AppReactionButtonState extends State<AppReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationTokens.normal,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AnimationTokens.elasticOut,
      ),
    );
  }

  @override
  void didUpdateWidget(AppReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger animation when liked state changes
    if (oldWidget.isLiked != widget.isLiked && widget.isLiked) {
      _controller.forward().then((_) {
        _controller.reverse();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = widget.size ??
        (widget.compact ? DesignTokens.iconMD : DesignTokens.iconLG);
    final iconSize = size * 0.6;

    return InkWell(
      onTap: widget.isLoading ? null : widget.onTap,
      borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal:
              widget.compact ? DesignTokens.spaceXS : DesignTokens.spaceSM,
          vertical:
              widget.compact ? DesignTokens.spaceXS : DesignTokens.spaceXS,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isLoading)
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.isLiked
                        ? SemanticColors.reactionLiked
                        : theme.colorScheme.onSurface
                            .withOpacity(DesignTokens.opacityMedium),
                  ),
                ),
              )
            else
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isLiked
                            ? SemanticColors.reactionLiked
                            : Colors.transparent,
                        border: Border.all(
                          color: widget.isLiked
                              ? SemanticColors.reactionLiked
                              : theme.colorScheme.onSurface
                                  .withOpacity(DesignTokens.opacityMedium),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.favorite,
                        size: iconSize,
                        color: widget.isLiked
                            ? Colors.white
                            : theme.colorScheme.onSurface
                                .withOpacity(DesignTokens.opacityMedium),
                      ),
                    ),
                  );
                },
              ),
            if (widget.showCount &&
                widget.reactionCount != null &&
                widget.reactionCount! > 0) ...[
              SizedBox(
                  width: widget.compact
                      ? DesignTokens.spaceXS
                      : DesignTokens.spaceSM),
              Text(
                _formatCount(widget.reactionCount!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: widget.isLiked
                      ? SemanticColors.reactionLiked
                      : theme.colorScheme.onSurface
                          .withOpacity(DesignTokens.opacityMedium),
                  fontWeight:
                      widget.isLiked ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
