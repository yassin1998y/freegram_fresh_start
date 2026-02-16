// lib/widgets/feed/post/post_actions.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/feed_widgets/comments_sheet.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui';

/// Post actions component (Like, Comment, Share)
///
/// Features:
/// - Optimistic UI for like button (instant animation)
/// - Heart scaling animation using AnimationTokens
/// - Uses DesignTokens for spacing
class PostActions extends StatefulWidget {
  final PostModel post;
  final ValueChanged<int>? onReactionCountChanged;
  final VoidCallback? onCommentTap;
  final VoidCallback? onGiftTap;
  final VoidCallback? onShareTap;
  final bool isFloating;

  const PostActions({
    super.key,
    required this.post,
    this.onReactionCountChanged,
    this.onCommentTap,
    this.onGiftTap,
    this.onShareTap,
    this.isFloating = false,
  });

  @override
  State<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<PostActions>
    with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  bool _isLoading = false;
  int _localReactionCount = 0;
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;

  @override
  void initState() {
    super.initState();
    _localReactionCount = widget.post.reactionCount;
    _checkIfLiked();

    // Initialize heart animation
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: AnimationTokens.fast,
    );
    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: AnimationTokens.elasticOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
    ]).animate(_heartAnimationController);
  }

  @override
  void didUpdateWidget(PostActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _localReactionCount = widget.post.reactionCount;
      _checkIfLiked();
    } else if ((_localReactionCount - widget.post.reactionCount).abs() > 2) {
      _localReactionCount = widget.post.reactionCount;
    }
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkIfLiked() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final liked = await locator<PostRepository>().hasUserLiked(
        widget.post.id,
        user.uid,
      );

      if (mounted) {
        setState(() => _isLiked = liked);
      }
    } catch (e) {
      debugPrint('PostActions: Error checking if liked: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_isLoading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to like posts')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final wasLiked = _isLiked;
    final previousCount = _localReactionCount;

    // OPTIMISTIC UPDATE: Update UI immediately
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _localReactionCount++;
      } else {
        _localReactionCount--;
      }
    });

    // Notify parent of reaction count change
    widget.onReactionCountChanged?.call(_localReactionCount);

    // Animate heart
    _heartAnimationController.forward(from: 0.0);
    HapticFeedback.lightImpact();

    try {
      if (wasLiked) {
        await locator<PostRepository>().unlikePost(
          widget.post.id,
          user.uid,
        );
      } else {
        await locator<PostRepository>().likePost(
          widget.post.id,
          user.uid,
        );
      }
    } catch (e) {
      debugPrint('PostActions: Error toggling like: $e');
      // Revert optimistic update on error
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _localReactionCount = previousCount;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sharePost() async {
    if (widget.onShareTap != null) {
      widget.onShareTap!();
      return;
    }

    try {
      final authorName = widget.post.pageName ?? widget.post.authorUsername;
      final deepLink = 'https://freegram.app/post/${widget.post.id}';

      String shareText;
      if (widget.post.content.isNotEmpty) {
        final contentPreview = widget.post.content.length > 100
            ? '${widget.post.content.substring(0, 100)}...'
            : widget.post.content;
        shareText =
            '$authorName: $contentPreview\n\nCheck out this post on Freegram: $deepLink';
      } else {
        shareText =
            '$authorName shared a post via Freegram\n\nCheck it out: $deepLink';
      }

      await Share.share(
        shareText,
        subject: 'Post by $authorName',
      );
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('PostActions: Error sharing post: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share post')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isSelfPost =
        currentUser != null && widget.post.authorId == currentUser.uid;

    Widget actionsRow = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // Like button
        _buildActionButton(
          onTap: _toggleLike,
          icon: _isLiked ? Icons.favorite : Icons.favorite_border,
          color: _isLiked ? theme.colorScheme.primary : theme.iconTheme.color!,
          label:
              _localReactionCount > 0 ? _localReactionCount.toString() : null,
          isLottie: _isLiked,
        ),
        const SizedBox(width: DesignTokens.spaceXS),

        // Comment button
        _buildActionButton(
          onTap: () {
            HapticFeedback.lightImpact();
            if (widget.onCommentTap != null) {
              widget.onCommentTap!();
            } else {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CommentsSheet(post: widget.post),
              );
            }
          },
          icon: Icons.chat_bubble_outline,
          color: theme.iconTheme.color!,
          label: widget.post.commentCount > 0
              ? widget.post.commentCount.toString()
              : null,
          labelColor: widget.post.commentCount > 0
              ? SemanticColors.textSecondary(context)
              : null,
        ),
        const SizedBox(width: DesignTokens.spaceXS),

        // Share button
        _buildActionButton(
          onTap: () {
            HapticFeedback.lightImpact();
            _sharePost();
          },
          icon: Icons.share_outlined,
          color: theme.iconTheme.color!,
        ),

        const Spacer(),

        // Gift button
        if (!isSelfPost)
          _buildActionButton(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onGiftTap?.call();
            },
            icon: Icons.card_giftcard,
            color: theme.iconTheme.color!,
          ),
      ],
    );

    if (widget.isFloating) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.0,
              ),
            ),
            child: IconTheme(
              data: theme.iconTheme.copyWith(color: Colors.white),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: actionsRow,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: actionsRow,
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    String? label,
    Color? labelColor,
    bool isLottie = false,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
      highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isLottie
                  ? ScaleTransition(
                      scale: _heartScaleAnimation,
                      child: SizedBox(
                        width: DesignTokens.iconMD,
                        height: DesignTokens.iconMD,
                        child: Lottie.network(
                          'https://assets9.lottiefiles.com/packages/lf20_lY397y.json',
                          controller: _heartAnimationController,
                          onLoaded: (composition) {
                            _heartAnimationController.duration =
                                composition.duration;
                          },
                          delegates: LottieDelegates(
                            values: [
                              ValueDelegate.color(
                                const ['**', 'Fill 1'],
                                value: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ScaleTransition(
                      scale: (icon == Icons.favorite ||
                              icon == Icons.favorite_border)
                          ? _heartScaleAnimation
                          : const AlwaysStoppedAnimation(1.0),
                      child:
                          Icon(icon, size: DesignTokens.iconMD, color: color),
                    ),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: widget.isFloating
                        ? Colors.white
                        : (labelColor ?? color),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
