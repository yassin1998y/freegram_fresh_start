// lib/widgets/feed_widgets/like_button.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/widgets/common/app_reaction_button.dart';

class LikeButton extends StatefulWidget {
  final PostModel post;

  const LikeButton({
    Key? key,
    required this.post,
  }) : super(key: key);

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool _isLiked = false;
  bool _isLoading = false;
  int _localReactionCount = 0;

  @override
  void initState() {
    super.initState();
    _localReactionCount = widget.post.reactionCount;
    _checkIfLiked();
  }

  @override
  void didUpdateWidget(LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local count if post changes or if server count differs significantly
    if (oldWidget.post.id != widget.post.id) {
      _localReactionCount = widget.post.reactionCount;
      _checkIfLiked();
    } else if ((_localReactionCount - widget.post.reactionCount).abs() > 2) {
      // Sync if there's a significant difference (likely server update)
      _localReactionCount = widget.post.reactionCount;
    }
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
      debugPrint('LikeButton: Error checking if liked: $e');
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

    // Optimistic update
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _localReactionCount++;
      } else {
        _localReactionCount--;
      }
    });

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

      // Refresh the like status in case it changed externally
      await _checkIfLiked();
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _localReactionCount = previousCount;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update reaction: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _toggleLike(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppReactionButton(
      isLiked: _isLiked,
      reactionCount: _localReactionCount,
      isLoading: _isLoading,
      onTap: _toggleLike,
      showCount: true,
    );
  }
}
