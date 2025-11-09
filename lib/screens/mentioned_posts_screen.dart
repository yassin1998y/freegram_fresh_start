// lib/screens/mentioned_posts_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/mention_service.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/widgets/feed_widgets/post_card.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class MentionedPostsScreen extends StatefulWidget {
  const MentionedPostsScreen({Key? key}) : super(key: key);

  @override
  State<MentionedPostsScreen> createState() => _MentionedPostsScreenState();
}

class _MentionedPostsScreenState extends State<MentionedPostsScreen> {
  final MentionService _mentionService = locator<MentionService>();
  final PostRepository _postRepository = locator<PostRepository>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<PostModel> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: mentioned_posts_screen.dart');
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final postIds = await _mentionService.getMentionedPosts(user.uid);
      final posts = <PostModel>[];

      for (final postId in postIds) {
        final post = await _postRepository.getPostById(postId);
        if (post != null) {
          posts.add(post);
        }
      }

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('MentionedPostsScreen: Error loading posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts You\'re Mentioned In'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: _isLoading
            ? const Center(child: AppProgressIndicator())
            : _posts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.alternate_email,
                          size: 64,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No mentions yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When someone tags you in a post, it will appear here',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      return PostCard(
                        item: PostFeedItem(
                          post: _posts[index],
                          displayType: PostDisplayType.organic,
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
