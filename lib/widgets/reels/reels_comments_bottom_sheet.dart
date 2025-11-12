// lib/widgets/reels/reels_comments_bottom_sheet.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/models/comment_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/reel_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/widgets/common/keyboard_safe_area.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/common/app_bottom_sheet.dart';
import 'package:freegram/widgets/common/app_reaction_button.dart';

class ReelsCommentsBottomSheet extends StatefulWidget {
  final String reelId;
  final ReelModel reel;

  const ReelsCommentsBottomSheet({
    Key? key,
    required this.reelId,
    required this.reel,
  }) : super(key: key);

  @override
  State<ReelsCommentsBottomSheet> createState() =>
      _ReelsCommentsBottomSheetState();
}

class _ReelsCommentsBottomSheetState extends State<ReelsCommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ReelRepository _reelRepository = locator<ReelRepository>();

  List<CommentModel> _comments = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  int _localCommentCount = 0;
  StreamSubscription<List<CommentModel>>? _commentsStreamSubscription;
  static const int _maxCommentLength = 500;

  @override
  void initState() {
    super.initState();
    _localCommentCount = widget.reel.commentCount;
    _loadComments();
    _startCommentsStream();
    _scrollController.addListener(_onScroll);
    _commentController.addListener(_onCommentTextChanged);
  }

  @override
  void dispose() {
    _commentsStreamSubscription?.cancel();
    _commentController.removeListener(_onCommentTextChanged);
    _commentController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onCommentTextChanged() {
    setState(() {}); // Rebuild to update character counter
  }

  void _startCommentsStream() {
    // Subscribe to real-time comment updates
    _commentsStreamSubscription =
        _reelRepository.getCommentsStream(widget.reelId).listen(
      (newComments) {
        if (mounted) {
          setState(() {
            // Remove any temp comments (optimistic updates that were added)
            _comments.removeWhere((c) => c.commentId.startsWith('temp_'));

            // Update existing comments or add new ones
            final existingIds = _comments.map((c) => c.commentId).toSet();
            final updatedComments = _comments.map((existingComment) {
              final updatedComment = newComments.firstWhere(
                (c) => c.commentId == existingComment.commentId,
                orElse: () => existingComment,
              );
              // Update if text, reactions, or other fields changed
              if (updatedComment.commentId == existingComment.commentId &&
                  (updatedComment.text != existingComment.text ||
                      updatedComment.reactions != existingComment.reactions ||
                      updatedComment.edited != existingComment.edited)) {
                return updatedComment;
              }
              return existingComment;
            }).toList();

            // Add new comments that don't exist yet
            final newCommentsToAdd = newComments
                .where((c) => !existingIds.contains(c.commentId))
                .toList();

            // Merge: existing updated comments + new comments
            _comments = [...updatedComments, ...newCommentsToAdd];
            _localCommentCount = newComments.length;
          });
        }
      },
      onError: (error) {
        debugPrint(
            'ReelsCommentsBottomSheet: Error in comments stream: $error');
      },
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        _hasMore &&
        !_isLoading) {
      _loadComments();
    }
  }

  Future<void> _loadComments() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final comments = await _reelRepository.getComments(
        widget.reelId,
        lastDocument: _lastDocument,
      );

      if (comments.isNotEmpty) {
        // Remove temp comments before adding loaded comments
        _comments.removeWhere((c) => c.commentId.startsWith('temp_'));

        // Get existing comment IDs (excluding temp comments)
        final existingIds = _comments.map((c) => c.commentId).toSet();

        // Only add comments that don't already exist
        final newCommentsToAdd =
            comments.where((c) => !existingIds.contains(c.commentId)).toList();

        // Get last document for pagination if needed
        DocumentSnapshot? newLastDoc;
        if (newCommentsToAdd.isNotEmpty && comments.length == 20) {
          // Get the last document from the query result for pagination
          // We'll need to modify getComments to return the last document
          // For now, we'll use a simpler approach
          try {
            final lastCommentId = comments.last.commentId;
            final lastDoc = await FirebaseFirestore.instance
                .collection('reels')
                .doc(widget.reelId)
                .collection('comments')
                .doc(lastCommentId)
                .get();
            newLastDoc = lastDoc;
          } catch (e) {
            debugPrint(
                'ReelsCommentsBottomSheet: Error getting last document: $e');
          }
        }

        setState(() {
          _comments.addAll(newCommentsToAdd);
          _hasMore = comments.length == 20;
          if (newLastDoc != null) {
            _lastDocument = newLastDoc;
          }
        });
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load comments: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to comment')),
      );
      return;
    }

    // Get user info for optimistic update
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data() ?? {};
    final username = userData['username'] ?? 'Anonymous';
    final photoUrl = userData['photoUrl'] ?? '';

    // Optimistic update: Create temporary comment
    final tempComment = CommentModel(
      commentId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      postId: widget.reelId, // CommentModel uses postId field
      userId: user.uid,
      username: username,
      photoUrl: photoUrl,
      text: text,
      timestamp: DateTime.now(),
    );

    // Clear input immediately
    _commentController.clear();

    // Update UI optimistically
    setState(() {
      _comments.add(tempComment);
      _localCommentCount++;
    });

    // Scroll to bottom to show new comment
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      // Submit comment to backend
      await _reelRepository.addComment(widget.reelId, user.uid, text);
      // Stream will handle the real update
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c.commentId == tempComment.commentId);
          _localCommentCount--;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                _commentController.text = text;
                _addComment();
              },
            ),
          ),
        );
      }
    }
  }

  void _handleCommentDeleted() {
    setState(() {
      _localCommentCount =
          (_localCommentCount - 1).clamp(0, double.infinity).toInt();
    });
  }

  void _handleCommentEdited(CommentModel updatedComment) {
    setState(() {
      final index =
          _comments.indexWhere((c) => c.commentId == updatedComment.commentId);
      if (index != -1) {
        _comments[index] = updatedComment;
      }
    });
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Comments',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_localCommentCount > 0) ...[
            const SizedBox(width: DesignTokens.spaceSM),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceSM,
                vertical: DesignTokens.spaceXS,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
              ),
              child: Text(
                '$_localCommentCount',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.close,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ThemeData theme) {
    return KeyboardAwareInput(
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: theme.dividerColor,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                maxLength: _maxCommentLength,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMD,
                    vertical: DesignTokens.spaceSM,
                  ),
                  counterText: _commentController.text.length >
                          _maxCommentLength * 0.8
                      ? '${_commentController.text.length}/$_maxCommentLength'
                      : '',
                ),
                style: theme.textTheme.bodyMedium,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _addComment(),
              ),
            ),
            const SizedBox(width: DesignTokens.spaceSM),
            IconButton(
              icon: Icon(
                Icons.send,
                color: _commentController.text.trim().isEmpty
                    ? theme.colorScheme.onSurface
                        .withOpacity(DesignTokens.opacityMedium)
                    : SonarPulseTheme.primaryAccent,
                size: DesignTokens.iconLG,
              ),
              onPressed:
                  _commentController.text.trim().isEmpty ? null : _addComment,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBottomSheet(
      isDraggable: true,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      adjustForKeyboard: true,
      header: _buildHeader(context, theme),
      footer: _buildFooter(context, theme),
      isComplexLayout: true,
      childBuilder: (scrollController) {
        // Use the scrollController from DraggableScrollableSheet if available
        final effectiveScrollController = scrollController;

        // Update pagination listener if scrollController is provided
        if (scrollController != null) {
          scrollController.addListener(() {
            if (scrollController.position.pixels >=
                    scrollController.position.maxScrollExtent * 0.8 &&
                _hasMore &&
                !_isLoading) {
              _loadComments();
            }
          });
        }

        return _comments.isEmpty && !_isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: DesignTokens.iconXXL,
                      color: theme.colorScheme.onSurface
                          .withOpacity(DesignTokens.opacityMedium),
                    ),
                    const SizedBox(height: DesignTokens.spaceMD),
                    Text(
                      'No comments yet',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withOpacity(DesignTokens.opacityMedium),
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceSM),
                    Text(
                      'Be the first to comment!',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withOpacity(DesignTokens.opacityMedium),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                controller: effectiveScrollController,
                padding: const EdgeInsets.symmetric(
                  vertical: DesignTokens.spaceSM,
                ),
                itemCount: _comments.length + (_hasMore && _isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _comments.length) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(DesignTokens.spaceMD),
                        child: AppProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    );
                  }

                  final comment = _comments[index];
                  return ReelCommentTile(
                    comment: comment,
                    reelId: widget.reelId,
                    onDeleted: _handleCommentDeleted,
                    onEdited: _handleCommentEdited,
                  );
                },
              );
      },
      child: const SizedBox.shrink(), // Not used when childBuilder is provided
    );
  }
}

// Reel-specific comment tile that uses ReelRepository instead of PostRepository
class ReelCommentTile extends StatefulWidget {
  final CommentModel comment;
  final String reelId;
  final VoidCallback? onDeleted;
  final Function(CommentModel)? onEdited;

  const ReelCommentTile({
    Key? key,
    required this.comment,
    required this.reelId,
    this.onDeleted,
    this.onEdited,
  }) : super(key: key);

  @override
  State<ReelCommentTile> createState() => _ReelCommentTileState();
}

class _ReelCommentTileState extends State<ReelCommentTile> {
  bool _isLiked = false;
  bool _isLiking = false;
  final ReelRepository _reelRepository = locator<ReelRepository>();

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }

  @override
  void didUpdateWidget(ReelCommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.commentId != widget.comment.commentId) {
      _checkIfLiked();
    }
  }

  Future<void> _checkIfLiked() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final hasReacted = widget.comment.reactions.containsKey(user.uid);
      if (mounted) {
        setState(() => _isLiked = hasReacted);
      }
    } catch (e) {
      debugPrint('ReelCommentTile: Error checking if liked: $e');
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
        await _reelRepository.likeComment(
          widget.reelId,
          widget.comment.commentId,
          user.uid,
        );
      } else {
        await _reelRepository.unlikeComment(
          widget.reelId,
          widget.comment.commentId,
          user.uid,
        );
      }

      await _checkIfLiked();
    } catch (e) {
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
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
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

  Future<void> _showEditDialog(BuildContext context) async {
    final TextEditingController controller =
        TextEditingController(text: widget.comment.text);
    final user = FirebaseAuth.instance.currentUser;
    final isOwner = user != null && user.uid == widget.comment.userId;

    if (!isOwner) return;

    const maxLength = 500;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Edit your comment...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result != null && result.isNotEmpty && result != widget.comment.text) {
      try {
        await _reelRepository.editComment(
          widget.reelId,
          widget.comment.commentId,
          result,
        );

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
      context: context,
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
        await _reelRepository.deleteComment(
            widget.reelId, widget.comment.commentId);

        if (widget.onDeleted != null) {
          widget.onDeleted!();
        }

        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment deleted'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete comment: ${e.toString()}'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          if (widget.comment.edited)
            Text(
              '(edited)',
              style: theme.textTheme.bodySmall?.copyWith(
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
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _formatTimestamp(widget.comment.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
              if (widget.comment.reactions.isNotEmpty) ...[
                const SizedBox(width: 8),
                AppReactionButton(
                  isLiked: true,
                  reactionCount: widget.comment.reactions.length,
                  showCount: true,
                  compact: true,
                  size: DesignTokens.iconXS,
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppReactionButton(
            isLiked: _isLiked,
            reactionCount: widget.comment.reactions.length,
            isLoading: _isLiking,
            onTap: _toggleLike,
            showCount: false,
            compact: true,
            size: DesignTokens.iconSM,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value == 'edit') {
                _showEditDialog(context);
              } else if (value == 'delete') {
                _deleteComment();
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
              ];
            },
          ),
        ],
      ),
    );
  }
}
