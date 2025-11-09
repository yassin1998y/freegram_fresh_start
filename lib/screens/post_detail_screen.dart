// lib/screens/post_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/widgets/feed_widgets/post_card.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/widgets/feed_widgets/comments_sheet.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final String? commentId; // Optional: scroll to specific comment

  const PostDetailScreen({
    Key? key,
    required this.postId,
    this.commentId,
  }) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final PostRepository _postRepository = locator<PostRepository>();
  PostModel? _post;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: post_detail_screen.dart');
    _loadPost();
  }

  Future<void> _loadPost() async {
    try {
      final post = await _postRepository.getPostById(widget.postId);
      if (mounted) {
        setState(() {
          _post = post;
          _isLoading = false;
        });

        // If commentId is provided, open comments sheet after a delay
        if (widget.commentId != null && post != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showCommentsSheet(context, post,
                  scrollToCommentId: widget.commentId);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('PostDetailScreen: Error loading post: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showCommentsSheet(BuildContext context, PostModel post,
      {String? scrollToCommentId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(
        post: post,
        scrollToCommentId: scrollToCommentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
      ),
      body: _isLoading
          ? const Center(child: AppProgressIndicator())
          : _post == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Post not found',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go back'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      PostCard(
                        item: PostFeedItem(
                          post: _post!,
                          displayType: PostDisplayType.organic,
                        ),
                      ),
                      // Action to view comments
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: OutlinedButton.icon(
                          onPressed: () => _showCommentsSheet(context, _post!),
                          icon: const Icon(Icons.comment_outlined),
                          label: Text(
                              'View ${_post!.commentCount} ${_post!.commentCount == 1 ? 'comment' : 'comments'}'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
