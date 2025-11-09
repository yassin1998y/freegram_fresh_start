// lib/widgets/story_widgets/feed/story_feed_card.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/models/story_media_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/utils/image_url_validator.dart';
import 'package:freegram/widgets/lqip_image.dart';

/// Story preview card for the feed tray
/// Shows story thumbnail with avatar, username, and border styling
/// Unread stories have gradient borders, watched stories have gray borders
class StoryFeedCard extends StatefulWidget {
  final StoryMedia story;
  final String username;
  final String userAvatarUrl;
  final bool isUnread;
  final VoidCallback onTap;

  const StoryFeedCard({
    Key? key,
    required this.story,
    required this.username,
    required this.userAvatarUrl,
    required this.isUnread,
    required this.onTap,
  }) : super(key: key);

  @override
  State<StoryFeedCard> createState() => _StoryFeedCardState();
}

class _StoryFeedCardState extends State<StoryFeedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: DesignTokens.durationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutCubic,
      ),
    );
    _shadowAnimation = Tween<double>(begin: 0.1, end: 0.25).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewUrl = widget.story.thumbnailUrl ?? widget.story.mediaUrl;

    return Padding(
      padding: const EdgeInsets.only(left: DesignTokens.spaceSM),
      child: SizedBox(
        width: 110,
        height: 160,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: AnimatedBuilder(
            animation: _scaleController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: RepaintBoundary(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                      border: widget.isUnread
                          ? null // Gradient border handled separately
                          : Border.all(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                              width: 2.0,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(_shadowAnimation.value),
                          blurRadius: DesignTokens.elevation2 + (_scaleController.value * 4),
                          spreadRadius: _scaleController.value * 1,
                          offset: Offset(0, 2 + (_scaleController.value * 2)),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                      // Background - Story Media
                      ImageUrlValidator.isValidUrl(previewUrl)
                          ? LQIPImage(
                              imageUrl: previewUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Icon(
                                  Icons.image,
                                  size: DesignTokens.iconXL,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: DesignTokens.opacityMedium),
                                ),
                              ),
                            ),

                      // Gradient overlay for text readability
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),

                      // Gradient border for unread stories (drawn as overlay)
                      if (widget.isUnread)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: GradientBorderPainter(
                                gradient: SonarPulseTheme.appLinearGradient,
                                width: 3.0,
                                borderRadius: DesignTokens.radiusMD,
                              ),
                            ),
                          ),
                        ),

                      // Avatar (Top-Left)
                      Positioned(
                        top: DesignTokens.spaceSM,
                        left: DesignTokens.spaceSM,
                        child: Container(
                          padding: const EdgeInsets.all(2.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: widget.isUnread
                                ? SonarPulseTheme.appLinearGradient
                                : null,
                            border: !widget.isUnread
                                ? Border.all(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.3),
                                    width: 2.0,
                                  )
                                : null,
                          ),
                          child: CircleAvatar(
                            radius: DesignTokens.iconMD,
                            backgroundColor: theme.colorScheme.surface,
                            backgroundImage:
                                ImageUrlValidator.isValidUrl(widget.userAvatarUrl)
                                    ? CachedNetworkImageProvider(
                                        widget.userAvatarUrl)
                                    : null,
                            child: !ImageUrlValidator.isValidUrl(
                                    widget.userAvatarUrl)
                                ? Icon(
                                    Icons.person,
                                    size: DesignTokens.iconSM,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: DesignTokens.opacityMedium),
                                  )
                                : null,
                          ),
                        ),
                      ),

                      // Username (Bottom-Left)
                      Positioned(
                        bottom: DesignTokens.spaceSM,
                        left: DesignTokens.spaceSM,
                        right: DesignTokens.spaceSM,
                        child: Text(
                          widget.username,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: DesignTokens.fontSizeSM,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            child: null,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for gradient border
class GradientBorderPainter extends CustomPainter {
  final Gradient gradient;
  final double width;
  final double borderRadius;

  GradientBorderPainter({
    required this.gradient,
    required this.width,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Create rect for gradient shader
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    // Create a slightly larger rect for the border path
    final borderRect = Rect.fromLTWH(
      width / 2,
      width / 2,
      size.width - width,
      size.height - width,
    );
    final borderRrect = RRect.fromRectAndRadius(
      borderRect,
      Radius.circular(borderRadius - width / 2),
    );

    // Create gradient shader
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = gradient.createShader(rect);

    // Draw the border
    canvas.drawRRect(borderRrect, paint);
  }

  @override
  bool shouldRepaint(GradientBorderPainter oldDelegate) => false;
}
