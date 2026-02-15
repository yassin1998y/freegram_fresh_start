// lib/widgets/story_widgets/feed/story_feed_card.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/models/story_media_model.dart';
import 'package:freegram/models/drawing_path_model.dart';
import 'package:freegram/theme/design_tokens.dart';
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
      duration: AnimationTokens.fast,
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
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMD),
                      border: widget.isUnread
                          ? null // Gradient border handled separately
                          : Border.all(
                              color: const Color(0xFF2C2C2E)
                                  .withValues(alpha: 0.6), // Dim Slate
                              width: 1.0,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: _shadowAnimation.value),
                          blurRadius: DesignTokens.elevation2 +
                              (_scaleController.value * 4),
                          spreadRadius: _scaleController.value * 1,
                          offset: Offset(0, 2 + (_scaleController.value * 2)),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMD),
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
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: Center(
                                    child: Icon(
                                      Icons.image,
                                      size: DesignTokens.iconXL,
                                      color: theme.colorScheme.onSurface
                                          .withValues(
                                              alpha:
                                                  DesignTokens.opacityMedium),
                                    ),
                                  ),
                                ),

                          // Story overlays (text, drawings, stickers) - scaled to card size
                          if (widget.story.textOverlays != null ||
                              widget.story.drawings != null ||
                              widget.story.stickerOverlays != null)
                            _StoryOverlaysPreview(
                              story: widget.story,
                              cardWidth: 110.0,
                              cardHeight: 160.0,
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
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF00BFA5),
                                        Color(0xFF8B5CF6)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    width: 2.0,
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
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFF00BFA5),
                                          Color(0xFF8B5CF6)
                                        ],
                                      )
                                    : null,
                                border: !widget.isUnread
                                    ? Border.all(
                                        color: const Color(0xFF2C2C2E)
                                            .withValues(alpha: 0.6),
                                        width: 1.0,
                                      )
                                    : null,
                              ),
                              child: CircleAvatar(
                                radius: DesignTokens.iconMD,
                                backgroundColor: theme.colorScheme.surface,
                                backgroundImage: ImageUrlValidator.isValidUrl(
                                        widget.userAvatarUrl)
                                    ? CachedNetworkImageProvider(
                                        widget.userAvatarUrl)
                                    : null,
                                child: !ImageUrlValidator.isValidUrl(
                                        widget.userAvatarUrl)
                                    ? Icon(
                                        Icons.person,
                                        size: DesignTokens.iconSM,
                                        color: theme.colorScheme.onSurface
                                            .withValues(
                                                alpha:
                                                    DesignTokens.opacityMedium),
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

/// Scaled overlays widget for story card preview
/// Renders overlays scaled to card dimensions instead of screen size
class _StoryOverlaysPreview extends StatelessWidget {
  final StoryMedia story;
  final double cardWidth;
  final double cardHeight;

  const _StoryOverlaysPreview({
    required this.story,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Calculate scale factor from story dimensions to card dimensions
    // Story dimensions are 1080x1920 (9:16 aspect ratio)
    const double storyWidth = 1080.0;
    const double storyHeight = 1920.0;
    final scaleX = cardWidth / storyWidth;
    final scaleY = cardHeight / storyHeight;
    // Use uniform scaling to maintain aspect ratio
    final scale = scaleX < scaleY ? scaleX : scaleY;

    return Stack(
      children: [
        // Text overlays
        if (story.textOverlays != null && story.textOverlays!.isNotEmpty)
          ...story.textOverlays!.map((overlay) {
            final x = overlay.x * cardWidth;
            final y = overlay.y * cardHeight;
            final fontSize = overlay.fontSize * scale;

            Color textColor;
            try {
              textColor =
                  Color(int.parse(overlay.color.replaceFirst('#', '0xFF')));
            } catch (e) {
              textColor = theme.colorScheme.onSurface;
            }

            TextStyle textStyle = TextStyle(
              color: textColor,
              fontSize: fontSize.clamp(8.0, 20.0), // Clamp font size for card
              fontWeight: FontWeight.bold,
            );

            if (overlay.style == 'outline') {
              final outlineColor = theme.brightness == Brightness.dark
                  ? theme.colorScheme.surface
                  : theme.colorScheme.primary;
              textStyle = textStyle.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = DesignTokens.elevation1 * scale
                  ..color = outlineColor,
              );
            }

            if (overlay.style == 'neon') {
              textStyle = textStyle.copyWith(
                shadows: [
                  Shadow(
                    color: textColor,
                    blurRadius: DesignTokens.blurLight * scale,
                  ),
                  Shadow(
                    color: textColor,
                    blurRadius: DesignTokens.blurMedium * scale,
                  ),
                ],
              );
            }

            return Positioned(
              left: x.clamp(0.0, cardWidth - 10),
              top: y.clamp(0.0, cardHeight - 10),
              child: Transform.rotate(
                angle: overlay.rotation * 3.14159 / 180,
                child: Transform.scale(
                  scale: scale,
                  child: Text(
                    overlay.text,
                    style: textStyle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          }),

        // Drawing overlays (scaled to card size)
        if (story.drawings != null && story.drawings!.isNotEmpty)
          Positioned.fill(
            child: CustomPaint(
              painter: _ScaledDrawingPainter(
                story.drawings!,
                fallbackColor: theme.colorScheme.onSurface,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
              ),
            ),
          ),

        // Sticker overlays (scaled)
        if (story.stickerOverlays != null && story.stickerOverlays!.isNotEmpty)
          ...story.stickerOverlays!.map((sticker) {
            final x = sticker.x * cardWidth;
            final y = sticker.y * cardHeight;

            return Positioned(
              left: x.clamp(0.0, cardWidth - 10),
              top: y.clamp(0.0, cardHeight - 10),
              child: Transform.rotate(
                angle: sticker.rotation * 3.14159 / 180,
                child: Transform.scale(
                  scale: sticker.scale * scale,
                  child: Text(
                    sticker.stickerId,
                    style: TextStyle(
                      fontSize: DesignTokens.iconXXL * scale,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// Scaled drawing painter for card preview
class _ScaledDrawingPainter extends CustomPainter {
  final List<DrawingPath> drawings;
  final Color fallbackColor;
  final double cardWidth;
  final double cardHeight;

  const _ScaledDrawingPainter(
    this.drawings, {
    this.fallbackColor = Colors.white,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scale factor
    const double storyWidth = 1080.0;
    const double storyHeight = 1920.0;
    final scaleX = cardWidth / storyWidth;
    final scaleY = cardHeight / storyHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    for (final drawingPath in drawings) {
      Color pathColor;
      try {
        pathColor =
            Color(int.parse(drawingPath.color.replaceFirst('#', '0xFF')));
      } catch (e) {
        pathColor = fallbackColor;
      }

      final paint = Paint()
        ..color = pathColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (drawingPath.strokeWidth * scale).clamp(0.5, 5.0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = ui.Path();
      if (drawingPath.points.isNotEmpty) {
        final firstPoint = drawingPath.points.first;
        path.moveTo(firstPoint.x * size.width, firstPoint.y * size.height);

        for (int i = 1; i < drawingPath.points.length; i++) {
          final point = drawingPath.points[i];
          path.lineTo(point.x * size.width, point.y * size.height);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ScaledDrawingPainter oldDelegate) {
    return oldDelegate.drawings != drawings ||
        oldDelegate.cardWidth != cardWidth ||
        oldDelegate.cardHeight != cardHeight;
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
