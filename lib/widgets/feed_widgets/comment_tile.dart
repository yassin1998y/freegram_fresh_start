// lib/widgets/feed_widgets/comment_tile.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:freegram/models/comment_model.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/widgets/feed_widgets/edit_comment_dialog.dart';
import 'package:freegram/screens/report_screen.dart';
import 'package:freegram/models/report_model.dart';
import 'package:intl/intl.dart';

class CommentTile extends StatefulWidget {
  final CommentModel comment;
  final String postId;
  final VoidCallback? onDeleted;
  final Function(CommentModel)? onEdited;

  const CommentTile({
    Key? key,
    required this.comment,
    required this.postId,
    this.onDeleted,
    this.onEdited,
  }) : super(key: key);

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _isLiked = false;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }

  @override
  void didUpdateWidget(CommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.commentId != widget.comment.commentId) {
      _checkIfLiked();
    }
  }

  Future<void> _checkIfLiked() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if user ID is in the reactions map
      final hasReacted = widget.comment.reactions.containsKey(user.uid);

      if (mounted) {
        setState(() => _isLiked = hasReacted);
      }
    } catch (e) {
      debugPrint('CommentTile: Error checking if liked: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLiking = true;
      _isLiked = !_isLiked;
    });

    try {
      if (_isLiked) {
        await locator<PostRepository>().likeComment(
          widget.postId,
          widget.comment.commentId,
          user.uid,
        );
      } else {
        await locator<PostRepository>().unlikeComment(
          widget.postId,
          widget.comment.commentId,
          user.uid,
        );
      }

      // Refresh like status
      await _checkIfLiked();
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLiking = false);
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(timestamp);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _reportComment(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportScreen(
          contentType: ReportContentType.comment,
          contentId: widget.comment.commentId,
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final TextEditingController controller =
        TextEditingController(text: widget.comment.text);
    final user = FirebaseAuth.instance.currentUser;
    final isOwner = user != null && user.uid == widget.comment.userId;

    if (!isOwner) return;

    final formKey = GlobalKey<FormState>();
    const maxLength = 500;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => EditCommentDialog(
        controller: controller,
        formKey: formKey,
        maxLength: maxLength,
      ),
    );

    // Dispose controller after dialog closes
    controller.dispose();

    if (result != null && result.isNotEmpty && result != widget.comment.text) {
      try {
        await locator<PostRepository>().editComment(
          widget.postId,
          widget.comment.commentId,
          result,
        );

        // Create updated comment model
        final updatedComment = widget.comment.copyWith(
          text: result,
          edited: true,
          editedAt: DateTime.now(),
        );

        if (widget.onEdited != null) {
          widget.onEdited!(updatedComment);
        }

        if (mounted) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment updated'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update comment: ${e.toString()}'),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _showEditDialog(context),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteComment() async {
    final user = FirebaseAuth.instance.currentUser;
    final isOwner = user != null && user.uid == widget.comment.userId;

    if (!isOwner) return;

    final confirm = await showDialog<bool>(
      context: this.context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await locator<PostRepository>()
            .deleteComment(widget.postId, widget.comment.commentId);

        if (widget.onDeleted != null) {
          widget.onDeleted!();
        }

        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(
              content: Text('Comment deleted'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete comment: ${e.toString()}'),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _deleteComment(),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundImage: widget.comment.photoUrl.isNotEmpty
            ? NetworkImage(widget.comment.photoUrl)
            : null,
        child:
            widget.comment.photoUrl.isEmpty ? const Icon(Icons.person) : null,
      ),
      title: Row(
        children: [
          Text(
            widget.comment.username,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 4),
          if (widget.comment.edited)
            Text(
              '(edited)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                  ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.comment.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _formatTimestamp(widget.comment.timestamp),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
              ),
              // Show reaction count if any
              if (widget.comment.reactions.isNotEmpty) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 12,
                      color: Colors.red[300],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${widget.comment.reactions.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Like button
          InkWell(
            onTap: _isLiking ? null : _toggleLike,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _isLiking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: _isLiked ? Colors.red : Colors.grey[600],
                    ),
            ),
          ),
          // More options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value == 'edit') {
                _showEditDialog(context);
              } else if (value == 'delete') {
                _deleteComment();
              } else if (value == 'report') {
                _reportComment(context);
              }
            },
            itemBuilder: (context) {
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              final isOwner = currentUserId == widget.comment.userId;

              return [
                if (isOwner) ...[
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                if (!isOwner)
                  const PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.flag, size: 18, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Report', style: TextStyle(color: Colors.orange)),
                      ],
                    ),
                  ),
              ];
            },
          ),
        ],
      ),
    );
  }
}
