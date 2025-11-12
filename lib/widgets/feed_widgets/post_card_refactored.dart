// lib/widgets/feed_widgets/post_card.dart
// Refactored: Compositional widget that assembles optimized components

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/feed_item_model.dart'
    show
        PostDisplayType,
        FeedItem,
        PostFeedItem,
        AdFeedItem,
        SuggestionCarouselFeedItem;
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/feed/post/post_header.dart';
import 'package:freegram/widgets/feed/post/post_media.dart';
import 'package:freegram/widgets/feed/post/post_actions.dart';
import 'package:freegram/widgets/feed/post/post_footer.dart';
import 'package:freegram/widgets/feed_widgets/ad_card.dart';
import 'package:freegram/widgets/feed_widgets/suggestion_carousel.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/screens/page_profile_screen.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/screens/report_screen.dart';
import 'package:freegram/models/report_model.dart';
import 'package:freegram/screens/boost_post_screen.dart';
import 'package:freegram/screens/boost_analytics_screen.dart';
import 'package:freegram/services/boost_analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostCard extends StatefulWidget {
  final FeedItem item;
  final bool loadMedia;
  final GeoPoint? userLocation;

  const PostCard({
    super.key,
    required this.item,
    this.loadMedia = true,
    this.userLocation,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final PostRepository _postRepository = locator<PostRepository>();
  final BoostAnalyticsService _boostAnalytics = BoostAnalyticsService();
  bool _hasTrackedBoostImpression = false;
  int _localReactionCount = 0;

  @override
  void initState() {
    super.initState();

    if (widget.item is PostFeedItem) {
      final postItem = widget.item as PostFeedItem;
      _localReactionCount = postItem.post.reactionCount;

      if (postItem.post.isBoosted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _trackBoostImpression(postItem.post);
        });
      }
    }
  }

  void _onReactionCountChanged(int newCount) {
    if (mounted) {
      setState(() {
        _localReactionCount = newCount;
      });
    }
  }

  Future<void> _trackBoostImpression(PostModel post) async {
    if (!_hasTrackedBoostImpression && post.isBoosted) {
      _hasTrackedBoostImpression = true;
      try {
        await _boostAnalytics.trackBoostImpression(post.id);
        await _postRepository.trackBoostImpression(post.id);
      } catch (e) {
        debugPrint('PostCard: Error tracking boost impression: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle different FeedItem types
    if (widget.item is PostFeedItem) {
      final postItem = widget.item as PostFeedItem;
      return _buildPostCard(context, postItem.post, postItem.displayType);
    } else if (widget.item is AdFeedItem) {
      final adItem = widget.item as AdFeedItem;
      return _buildAdCard(context, adItem);
    } else if (widget.item is SuggestionCarouselFeedItem) {
      final suggestionItem = widget.item as SuggestionCarouselFeedItem;
      return SuggestionCarouselWidget(
        type: suggestionItem.type,
        suggestions: suggestionItem.suggestions,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPostCard(
    BuildContext context,
    PostModel post,
    PostDisplayType displayType,
  ) {
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceSM,
        vertical: DesignTokens.spaceXS,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          PostHeader(
            post: post,
            displayType: displayType,
            onProfileTap: () => _navigateToProfile(context, post),
            onMenuSelected: (value) => _handleMenuAction(context, post, value),
            onBoostTap: () => _navigateToBoostPost(context, post),
            onInsightsTap: () => _navigateToBoostInsights(context, post),
          ),

          // MEDIA (wrapped in RepaintBoundary to isolate repaints)
          if (post.mediaItems.isNotEmpty || post.mediaUrls.isNotEmpty)
            RepaintBoundary(
              child: PostMedia(
                post: post,
                loadMedia: widget.loadMedia,
              ),
            ),

          // ACTIONS
          PostActions(
            post: post,
            onReactionCountChanged: _onReactionCountChanged,
            onCommentTap: () {
              // Comment tap handled in PostActions
            },
            onShareTap: () {
              // Share tap handled in PostActions
            },
          ),

          // FOOTER (engagement stats and caption)
          PostFooter(
            post: post,
            reactionCount: _localReactionCount,
          ),
        ],
      ),
    );
  }

  Widget _buildAdCard(BuildContext context, AdFeedItem adItem) {
    return AdCard(adCacheKey: adItem.cacheKey);
  }

  void _navigateToProfile(BuildContext context, PostModel post) {
    if (post.pageId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PageProfileScreen(pageId: post.pageId!),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: post.authorId),
        ),
      );
    }
  }

  void _handleMenuAction(
    BuildContext context,
    PostModel post,
    String value,
  ) {
    switch (value) {
      case 'edit':
        // TODO: Implement post editing
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post editing will be available soon')),
        );
        break;
      case 'pin':
        _pinPost(context, post);
        break;
      case 'unpin':
        _unpinPost(context, post);
        break;
      case 'delete':
        _deletePost(context, post);
        break;
      case 'share':
        // Share handled in PostActions
        break;
      case 'report':
        _reportPost(context, post);
        break;
    }
  }

  Future<void> _pinPost(BuildContext context, PostModel post) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      await _postRepository.pinPost(post.id, currentUserId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post pinned')),
        );
      }
    } catch (e) {
      debugPrint('PostCard: Error pinning post: $e');
    }
  }

  Future<void> _unpinPost(BuildContext context, PostModel post) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      await _postRepository.unpinPost(post.id, currentUserId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post unpinned')),
        );
      }
    } catch (e) {
      debugPrint('PostCard: Error unpinning post: $e');
    }
  }

  Future<void> _deletePost(BuildContext context, PostModel post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
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
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId == null) return;

        await _postRepository.deletePost(post.id, currentUserId);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted')),
          );
        }
      } catch (e) {
        debugPrint('PostCard: Error deleting post: $e');
      }
    }
  }

  void _reportPost(BuildContext context, PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportScreen(
          contentType: ReportContentType.post,
          contentId: post.id,
        ),
      ),
    );
  }

  void _navigateToBoostPost(BuildContext context, PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BoostPostScreen(post: post),
      ),
    ).then((boosted) {
      if (boosted == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post boosted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _navigateToBoostInsights(BuildContext context, PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BoostAnalyticsScreen(post: post),
      ),
    );
  }
}
