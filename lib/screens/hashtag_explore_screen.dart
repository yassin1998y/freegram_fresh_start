// lib/screens/hashtag_explore_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/hashtag_service.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/widgets/feed_widgets/post_card.dart';
import 'package:freegram/models/feed_item_model.dart';

class HashtagExploreScreen extends StatefulWidget {
  final String hashtag;

  const HashtagExploreScreen({
    Key? key,
    required this.hashtag,
  }) : super(key: key);

  @override
  State<HashtagExploreScreen> createState() => _HashtagExploreScreenState();
}

class _HashtagExploreScreenState extends State<HashtagExploreScreen> {
  final HashtagService _hashtagService = locator<HashtagService>();
  final PostRepository _postRepository = locator<PostRepository>();
  List<PostModel> _posts = [];
  bool _isLoading = true;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  Map<String, dynamic>? _hashtagStats;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _hashtagService.getHashtagStats(widget.hashtag);
    if (mounted) {
      setState(() {
        _hashtagStats = stats;
      });
    }
  }

  Future<void> _loadPosts({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _posts = [];
        _lastDocument = null;
      });
    }

    try {
      final postIds = await _hashtagService.getPostsByHashtag(
        widget.hashtag,
        limit: 20,
        startAfter: _lastDocument,
      );

      if (postIds.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasMore = false;
          });
        }
        return;
      }

      // Fetch full post documents
      final posts = <PostModel>[];
      for (final postId in postIds) {
        final post = await _postRepository.getPostById(postId);
        if (post != null) {
          posts.add(post);
        }
      }

      if (mounted) {
        setState(() {
          _posts.addAll(posts);
          _isLoading = false;
          _hasMore = posts.length == 20; // Assume more if we got full limit
          if (posts.isNotEmpty) {
            // Get last document for pagination (simplified - would need actual snapshot)
            // For now, we'll use the last post's timestamp
          }
        });
      }
    } catch (e) {
      debugPrint('HashtagExploreScreen: Error loading posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedHashtag = widget.hashtag.startsWith('#')
        ? widget.hashtag.substring(1)
        : widget.hashtag;

    return Scaffold(
      appBar: AppBar(
        title: Text('#$normalizedHashtag'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Show search for hashtags
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadPosts(),
        child: CustomScrollView(
          slivers: [
            // Hashtag stats header
            if (_hashtagStats != null)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#$normalizedHashtag',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _StatChip(
                            label: 'Posts',
                            value: '${_hashtagStats!['postCount'] ?? 0}',
                          ),
                          const SizedBox(width: 16),
                          _StatChip(
                            label: 'Reactions',
                            value: '${_hashtagStats!['totalReactions'] ?? 0}',
                          ),
                          const SizedBox(width: 16),
                          _StatChip(
                            label: 'Comments',
                            value: '${_hashtagStats!['totalComments'] ?? 0}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Posts list
            if (_isLoading && _posts.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_posts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.tag_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No posts found',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to post with #$normalizedHashtag',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _posts.length) {
                      if (_hasMore) {
                        _loadPosts(loadMore: true);
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }
                    return PostCard(
                      item: PostFeedItem(
                        post: _posts[index],
                        displayType: PostDisplayType.organic,
                      ),
                    );
                  },
                  childCount: _hasMore ? _posts.length + 1 : _posts.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
