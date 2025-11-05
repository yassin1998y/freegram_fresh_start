// lib/widgets/feed_widgets/comments_sheet.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/comment_model.dart';
import 'package:freegram/widgets/feed_widgets/comment_tile.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/post_repository.dart';

class CommentsSheet extends StatefulWidget {
  final PostModel post;
  final String? scrollToCommentId; // Optional: scroll to specific comment

  const CommentsSheet({
    Key? key,
    required this.post,
    this.scrollToCommentId,
  }) : super(key: key);

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
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
    _localCommentCount = widget.post.commentCount;
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
        locator<PostRepository>().getCommentsStream(widget.post.id).listen(
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
        debugPrint('CommentsSheet: Error in comments stream: $error');
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
      final comments = await locator<PostRepository>().getComments(
        widget.post.id,
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

        setState(() {
          _comments.addAll(newCommentsToAdd);
          _hasMore = comments.length == 20; // Assuming limit is 20
          // Store the last comment's ID to use for pagination (simplified approach)
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
      postId: widget.post.id,
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
      // Call repository
      await locator<PostRepository>().addComment(
        widget.post.id,
        user.uid,
        text,
      );

      // Don't reload all comments - the stream will handle the update
      // Just remove the temp comment and let the stream add the real one
      setState(() {
        _comments.removeWhere((c) => c.commentId == tempComment.commentId);
      });

      // The stream will add the real comment automatically
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

  void _onCommentDeleted() {
    setState(() {
      _localCommentCount--;
      // Reload comments to refresh the list
      _comments.clear();
      _lastDocument = null;
      _hasMore = true;
      _loadComments();
    });
  }

  void _onCommentEdited(CommentModel updatedComment) {
    setState(() {
      final index =
          _comments.indexWhere((c) => c.commentId == updatedComment.commentId);
      if (index != -1) {
        _comments[index] = updatedComment;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        // Merge our scroll controller with the draggable one
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              _scrollController.position.copyWith(
                pixels: scrollController.position.pixels,
              );
            }
            return false;
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey[300]!,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Comments',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                      ),
                      if (_localCommentCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_localCommentCount',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 24),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Comments list
                Expanded(
                  child: _isLoading && _comments.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _comments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.comment_outlined,
                                      size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No comments yet',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Be the first to comment!',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _comments.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _comments.length) {
                                  if (!_isLoading) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      _loadComments();
                                    });
                                  }
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                return CommentTile(
                                  comment: _comments[index],
                                  postId: widget.post.id,
                                  onDeleted: _onCommentDeleted,
                                  onEdited: _onCommentEdited,
                                );
                              },
                            ),
                ),

                // Input field
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TextField(
                                controller: _commentController,
                                decoration: InputDecoration(
                                  hintText: 'Add a comment...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .surface
                                      .withOpacity(0.5),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  counterText: '', // Hide default counter
                                ),
                                maxLines: null,
                                maxLength: _maxCommentLength,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onSubmitted: (_) => _addComment(),
                              ),
                              // Custom character counter
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0),
                                child: Text(
                                  '${_commentController.text.length}/$_maxCommentLength',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: _commentController.text.length >
                                                _maxCommentLength * 0.9
                                            ? Colors.orange
                                            : Colors.grey[600],
                                        fontSize: 11,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send),
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: _commentController.text.trim().isEmpty ||
                                  _commentController.text.length >
                                      _maxCommentLength
                              ? null
                              : _addComment,
                          tooltip: 'Post comment',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
