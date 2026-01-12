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
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/screens/page_profile_screen.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/screens/report_screen.dart';
import 'package:freegram/models/report_model.dart';
import 'package:freegram/screens/boost_post_screen.dart';
import 'package:freegram/screens/boost_analytics_screen.dart';
import 'package:freegram/services/boost_analytics_service.dart';
import 'package:freegram/services/mention_service.dart';
import 'package:freegram/screens/hashtag_explore_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/screens/gift_send_selection_screen.dart'; // Import GiftSendSelectionScreen

class PostCard extends StatefulWidget {
  final FeedItem item;
  final bool loadMedia;
  final GeoPoint? userLocation;
  final bool isNew; // Whether this post is new (since last viewed)
  final bool isVisible;

  const PostCard({
    super.key,
    required this.item,
    this.loadMedia = true,
    this.userLocation,
    this.isNew = false,
    this.isVisible = true,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final PostRepository _postRepository = locator<PostRepository>();
  final BoostAnalyticsService _boostAnalytics = BoostAnalyticsService();
  final MentionService _mentionService = locator<MentionService>();
  bool _hasTrackedBoostImpression = false;
  int _localReactionCount = 0;
  bool _isCaptionExpanded = false;

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
    final theme = Theme.of(context);

    return Container(
      color: theme.cardColor,
      margin: EdgeInsets.zero, // Full-width posts, no horizontal margins
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER - Using refined padding
          Padding(
            padding: EdgeInsets.all(DesignTokens.postHeaderPadding),
            child: PostHeader(
              post: post,
              displayType: displayType,
              isNew: widget.isNew,
              onProfileTap: () => _navigateToProfile(context, post),
              onMenuSelected: (value) =>
                  _handleMenuAction(context, post, value),
              onBoostTap: null, // Moved to footer
              onInsightsTap: null, // Moved to footer
            ),
          ),

          // CAPTION (moved to top, before media)
          if (post.content.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: DesignTokens.postCaptionPadding,
                vertical: DesignTokens.spaceSM,
              ),
              child: _buildCaption(context),
            ),

          // MEDIA (wrapped in RepaintBoundary to isolate repaints)
          // Full-width, no padding
          if (post.mediaItems.isNotEmpty || post.mediaUrls.isNotEmpty)
            RepaintBoundary(
              child: PostMedia(
                post: post,
                loadMedia: widget.loadMedia,
                isVisible: widget.isVisible,
              ),
            ),

          // ACTIONS - Using refined padding
          Padding(
            padding: EdgeInsets.all(DesignTokens.postActionsPadding),
            child: PostActions(
              post: post,
              onReactionCountChanged: _onReactionCountChanged,
              onGiftTap: () => _navigateToGiftSelection(context, post),
            ),
          ),

          // FOOTER (engagement stats only, caption moved to top)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: DesignTokens.postCaptionPadding,
            ),
            child: PostFooter(
              post: post,
              reactionCount: _localReactionCount,
              showCaption: false, // Caption is now at top
              onBoostTap: () => _navigateToBoostPost(context, post),
              onInsightsTap: () => _navigateToBoostInsights(context, post),
            ),
          ),

          // Hairline divider instead of card gap
          Divider(
            height: 1,
            thickness: DesignTokens.borderWidthHairline,
            color: theme.dividerColor,
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

  void _navigateToGiftSelection(BuildContext context, PostModel post) async {
    final currentUserRef = locator<UserRepository>();
    final author = await currentUserRef.getUser(post.authorId);

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GiftSendSelectionScreen(recipient: author),
        ),
      );
    }
  }

  Widget _buildCaption(BuildContext context) {
    if (widget.item is! PostFeedItem) return const SizedBox.shrink();

    final postItem = widget.item as PostFeedItem;
    final post = postItem.post;
    final theme = Theme.of(context);

    final spans = _mentionService.formatTextWithMentionsAndHashtags(
      post.content,
      defaultStyle: theme.textTheme.bodyMedium?.copyWith(
        height: 1.4,
        color: SemanticColors.textPrimary(context),
      ),
      mentionStyle: theme.textTheme.bodyMedium?.copyWith(
        height: 1.4,
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w500,
      ),
      hashtagStyle: theme.textTheme.bodyMedium?.copyWith(
        height: 1.4,
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w500,
      ),
      onHashtagTap: (hashtag) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HashtagExploreScreen(hashtag: hashtag),
          ),
        );
      },
      onMentionTap: (username) async {
        final userRepository = locator<UserRepository>();
        final user = await userRepository.getUserByUsername(username);
        if (user != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: user.id),
            ),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User @$username not found')),
          );
        }
      },
    );

    // Check if caption needs expansion
    final textPainter = TextPainter(
      text: TextSpan(
        text: post.content,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
      ),
      maxLines: 2,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(
      maxWidth: MediaQuery.of(context).size.width - DesignTokens.spaceMD * 2,
    );
    final needsExpansion = textPainter.didExceedMaxLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(children: spans),
          maxLines: _isCaptionExpanded ? null : 2,
          overflow:
              _isCaptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (needsExpansion)
          GestureDetector(
            onTap: () {
              setState(() => _isCaptionExpanded = !_isCaptionExpanded);
            },
            child: Padding(
              padding: EdgeInsets.only(top: DesignTokens.spaceXS),
              child: Text(
                _isCaptionExpanded ? 'Show less' : 'Show more',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _isCaptionExpanded
                      ? SemanticColors.textSecondary(context)
                      : theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
