// lib/widgets/reels/reels_video_ui_overlay.dart
// Facebook Reels-style UI overlay

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/common/app_reaction_button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/screens/random_chat/widgets/gift_picker_sheet.dart';

class ReelsVideoUIOverlay extends StatefulWidget {
  final ReelModel reel;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onProfileTap;
  final String? currentUserId;
  final VoidCallback? onDelete;
  final double progress; // 0.0 to 1.0
  final ValueChanged<double>? onScrub;

  const ReelsVideoUIOverlay({
    Key? key,
    required this.reel,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onProfileTap,
    this.currentUserId,
    this.onDelete,
    this.progress = 0.0,
    this.onScrub,
  }) : super(key: key);

  @override
  State<ReelsVideoUIOverlay> createState() => _ReelsVideoUIOverlayState();
}

class _ReelsVideoUIOverlayState extends State<ReelsVideoUIOverlay> {
  bool _isScrubbing = false;

  void _handleGiftTap(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const GiftPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final isOwnReel = widget.currentUserId != null &&
        widget.currentUserId == widget.reel.uploaderId;

    return Stack(
      children: [
        // Task 2: Subtle gradient for top legibility
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 100 + safeAreaTop,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Top-right menu button (only for own reels)
        if (isOwnReel && widget.onDelete != null)
          Positioned(
            top: safeAreaTop + DesignTokens.spaceSM,
            right: DesignTokens.spaceMD,
            child: _GlassIconButton(
              icon: Icons.more_vert,
              onTap: () {
                HapticFeedback.lightImpact();
                _showDeleteConfirmation(context);
              },
            ),
          ),

        // User info and caption (bottom-left)
        Positioned(
          bottom: safeAreaBottom + DesignTokens.spaceXXL,
          left: DesignTokens.spaceMD,
          right: 100, // Space for right actions
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // User info
              GestureDetector(
                onTap: widget.onProfileTap,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: widget.reel.uploaderAvatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.reel.uploaderAvatarUrl,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.person,
                                        color: Colors.white),
                              )
                            : const Icon(Icons.person, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceSM),
                    Expanded(
                      child: Text(
                        widget.reel.uploaderUsername,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: DesignTokens.fontSizeMD,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.8),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spaceSM),
              // Caption with Task 2: Contrast Architecture (BoxShadow)
              if (widget.reel.caption != null &&
                  widget.reel.caption!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    widget.reel.caption!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: DesignTokens.fontSizeSM,
                      height: 1.4,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.8),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),

        // Task 2: Interaction Column (Right Side)
        Positioned(
          bottom: safeAreaBottom + DesignTokens.spaceXXL,
          right: DesignTokens.spaceMD,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Like Button
              _VerticalAction(
                label: _formatCount(widget.reel.likeCount),
                child: AppReactionButton(
                  isLiked: widget.isLiked,
                  reactionCount: widget.reel.likeCount,
                  isLoading: false,
                  onTap: widget.onLike,
                  showCount: false,
                  size: 32,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceLG),

              // Comment Button
              _VerticalAction(
                label: _formatCount(widget.reel.commentCount),
                child: _GlassIconButton(
                  icon: Icons.chat_bubble_outline,
                  onTap: widget.onComment,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceLG),

              // Share Button
              _VerticalAction(
                label: _formatCount(widget.reel.shareCount),
                child: _GlassIconButton(
                  icon: Icons.share_outlined,
                  onTap: widget.onShare,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceLG),

              // Task 2: The "Gift" Surge
              _VerticalAction(
                label: "Gift",
                child: _GlassIconButton(
                  icon: Icons.card_giftcard,
                  color: SonarPulseTheme.primaryAccent,
                  onTap: () => _handleGiftTap(context),
                ),
              ),
            ],
          ),
        ),

        // Task 4: Minimalist Scrubber (Neon Pulse)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: GestureDetector(
            onHorizontalDragStart: (_) => setState(() => _isScrubbing = true),
            onHorizontalDragUpdate: (details) {
              final box = context.findRenderObject() as RenderBox;
              final width = box.size.width;
              final newProgress =
                  (details.localPosition.dx / width).clamp(0.0, 1.0);
              widget.onScrub?.call(newProgress);
            },
            onHorizontalDragEnd: (_) => setState(() => _isScrubbing = false),
            onLongPressStart: (_) => setState(() => _isScrubbing = true),
            onLongPressEnd: (_) => setState(() => _isScrubbing = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _isScrubbing ? 6.0 : 2.0,
              width: double.infinity,
              color: Colors.transparent,
              child: Stack(
                children: [
                  // Background track
                  Container(
                    width: double.infinity,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  // Pulse/Progress line
                  FractionallySizedBox(
                    widthFactor: widget.progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: SonarPulseTheme.primaryAccent,
                        boxShadow: [
                          BoxShadow(
                            color: SonarPulseTheme.primaryAccent
                                .withValues(alpha: 0.6),
                            blurRadius: _isScrubbing ? 8 : 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  void _showDeleteConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radiusXL),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: DesignTokens.spaceSM),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMD),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Colors.red, size: DesignTokens.iconLG),
                title: const Text('Delete Reel',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: DesignTokens.fontSizeMD,
                        fontWeight: FontWeight.w600)),
                subtitle: const Text('This action cannot be undone',
                    style: TextStyle(fontSize: DesignTokens.fontSizeSM)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog(context);
                },
              ),
              const SizedBox(height: DesignTokens.spaceSM),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reel?'),
        content: const Text(
            'Are you sure you want to delete this reel? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ColorFilter.mode(
              Colors.white.withValues(alpha: 0.1),
              BlendMode.srcOver,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
      ),
    );
  }
}

class _VerticalAction extends StatelessWidget {
  final Widget child;
  final String label;

  const _VerticalAction({required this.child, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: DesignTokens.fontSizeXS,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
