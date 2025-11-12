// lib/widgets/feed/post/post_actions.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/feed_widgets/comments_sheet.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:share_plus/share_plus.dart';

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
  final VoidCallback? onShareTap;

  const PostActions({
    super.key,
    required this.post,
    this.onReactionCountChanged,
    this.onCommentTap,
    this.onShareTap,
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
    } catch (e) {
      debugPrint('PostActions: Error sharing post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share post')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceXS,
        vertical: DesignTokens.spaceSM,
      ),
      child: Row(
        children: [
          // Like button - Minimum 44x44px hit area for accessibility
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleLike,
                borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 44.0, // Accessibility minimum
                    minWidth: 44.0,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMD,
                    vertical: DesignTokens.spaceSM,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _heartScaleAnimation,
                        child: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          size: DesignTokens.iconLG,
                          color: _isLiked
                              ? SemanticColors.reactionLiked
                              : theme.iconTheme.color,
                        ),
                      ),
                      if (_localReactionCount > 0) ...[
                        SizedBox(width: DesignTokens.spaceXS),
                        Text(
                          _localReactionCount.toString(),
                          style: theme.textTheme.labelLarge,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Comment button - Minimum 44x44px hit area
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onCommentTap ??
                    () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => CommentsSheet(post: widget.post),
                      );
                    },
                borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 44.0, // Accessibility minimum
                    minWidth: 44.0,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMD,
                    vertical: DesignTokens.spaceSM,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.comment_outlined,
                        size: DesignTokens.iconLG,
                        color: theme.iconTheme.color,
                      ),
                      if (widget.post.commentCount > 0) ...[
                        SizedBox(width: DesignTokens.spaceXS),
                        Text(
                          widget.post.commentCount.toString(),
                          style: theme.textTheme.labelLarge,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Share button - IconButton already has 48x48px hit area (meets requirement)
          Expanded(
            child: IconButton(
              icon: Icon(
                Icons.share_outlined,
                color: theme.iconTheme.color,
              ),
              onPressed: _sharePost,
            ),
          ),
        ],
      ),
    );
  }
}
