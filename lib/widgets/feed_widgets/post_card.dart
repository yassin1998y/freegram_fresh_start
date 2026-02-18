// lib/widgets/feed_widgets/post_card.dart
// Refactored: Compositional widget that assembles optimized components

import 'dart:io';
import 'package:flutter/material.dart';
// Added for HapticFeedback
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/feed_item_model.dart'
    show
        PostDisplayType,
        FeedItem,
        PostFeedItem,
        GhostPostFeedItem,
        AdFeedItem,
        SuggestionCarouselFeedItem,
        MilestoneFeedItem;
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/feed/post/post_header.dart';
import 'package:freegram/widgets/feed/post/post_media.dart';
import 'package:freegram/widgets/feed/post/post_actions.dart';
import 'package:freegram/widgets/feed/post/post_footer.dart';
import 'package:freegram/widgets/feed_widgets/ad_card.dart';
import 'package:freegram/widgets/feed_widgets/suggestion_carousel.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/repositories/analytics_repository.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/screens/page_profile_screen.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/screens/report_screen.dart';
import 'package:freegram/models/report_model.dart';
import 'package:freegram/screens/boost_post_screen.dart';
import 'package:freegram/screens/boost_analytics_screen.dart';
import 'package:freegram/services/boost_analytics_service.dart';
import 'package:freegram/services/mention_service.dart';
import 'package:freegram/screens/hashtag_explore_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/screens/gift_send_selection_screen.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/core/user_avatar.dart';
import 'package:freegram/widgets/achievements/achievement_progress_bar.dart';

import 'package:freegram/utils/haptic_helper.dart';

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
  final BoostAnalyticsService _boostAnalytics =
      locator<BoostAnalyticsService>();
  final AnalyticsRepository _analyticsRepository =
      locator<AnalyticsRepository>();
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
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await _analyticsRepository.trackBoostReach(post.id, currentUser.uid);
        }
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
    } else if (widget.item is MilestoneFeedItem) {
      final milestoneItem = widget.item as MilestoneFeedItem;
      return _buildMilestoneCard(context, milestoneItem);
    } else if (widget.item is GhostPostFeedItem) {
      final ghostItem = widget.item as GhostPostFeedItem;
      return _buildGhostPostCard(context, ghostItem);
    }
    return const SizedBox.shrink();
  }

  Widget _buildMilestoneCard(
      BuildContext context, MilestoneFeedItem milestone) {
    final theme = Theme.of(context);
    final isGold = milestone.tier.toLowerCase() == 'gold';
    final isPlatinum = milestone.tier.toLowerCase() == 'platinum';

    // Aesthetic: Brand Green Identity (Primary)
    final accentColor = isPlatinum
        ? const Color(0xFFE5E4E2)
        : (isGold ? const Color(0xFFFFD700) : theme.colorScheme.primary);
    const brandGreen = Color(0xFF00E676); // High-intensity Brand Green

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        border: Border.all(
          color: brandGreen.withValues(alpha: 0.3),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: brandGreen.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: milestone.userPhotoUrl.isNotEmpty
                    ? NetworkImage(milestone.userPhotoUrl)
                    : null,
                radius: 20,
              ),
              const SizedBox(width: DesignTokens.spaceSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestone.username,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Just reached a new milestone!',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: SemanticColors.textSecondary(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          Container(
            padding: const EdgeInsets.all(DesignTokens.spaceLG),
            decoration: BoxDecoration(
              color: brandGreen.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            ),
            child: Column(
              children: [
                if (milestone.badgeUrl != null &&
                    milestone.badgeUrl!.isNotEmpty)
                  Image.network(milestone.badgeUrl!, height: 80, width: 80),
                const SizedBox(height: DesignTokens.spaceSM),
                Text(
                  milestone.achievementName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: brandGreen,
                  ),
                ),
                Text(
                  '${milestone.tier.toUpperCase()} BADGE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: Icons.favorite_border,
                label: 'React',
                color: brandGreen,
                onTap: () {
                  HapticHelper.lightImpact();
                  locator<UserRepository>().sendRemoteCommand(
                    targetUserId: milestone.userId,
                    command: 'haptic_reciprocity',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reaction sent!')),
                  );
                },
              ),
              _ActionButton(
                icon: Icons.celebration,
                label: 'Congratulate',
                color: brandGreen,
                onTap: () {
                  HapticHelper.mediumImpact();
                  locator<UserRepository>().sendRemoteCommand(
                    targetUserId: milestone.userId,
                    command: 'success_animation',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Congratulated!')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(
    BuildContext context,
    PostModel post,
    PostDisplayType displayType,
  ) {
    final theme = Theme.of(context);
    final isTextOnly = post.mediaItems.isEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.all(DesignTokens.postHeaderPadding),
              child: PostHeader(
                post: post,
                displayType: displayType,
                isNew: widget.isNew,
                onProfileTap: () => _navigateToProfile(context, post),
                onMenuSelected: (value) =>
                    _handleMenuAction(context, post, value),
              ),
            ),

            // CAPTION
            if (post.content.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  left: DesignTokens.postCaptionPadding,
                  right: DesignTokens.postCaptionPadding,
                  top: DesignTokens.spaceXS,
                  bottom:
                      isTextOnly ? DesignTokens.spaceMD : DesignTokens.spaceSM,
                ),
                child: _buildCaption(context),
              ),

            // MEDIA
            if (!isTextOnly)
              RepaintBoundary(
                child: PostMedia(
                  post: post,
                  loadMedia: widget.loadMedia,
                  isVisible: widget.isVisible,
                ),
              ),

            // UNIFIED ACTIONS (Single call as per objective)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.postCaptionPadding - 8,
                vertical: DesignTokens.spaceXS,
              ),
              child: PostActions(
                post: post,
                onReactionCountChanged: _onReactionCountChanged,
                onGiftTap: () => _navigateToGiftSelection(context, post),
                isFloating: false,
              ),
            ),

            // FOOTER (metadata and boost only)
            Padding(
              padding: const EdgeInsets.only(
                left: DesignTokens.postCaptionPadding,
                right: DesignTokens.postCaptionPadding,
                bottom: DesignTokens.spaceSM,
              ),
              child: PostFooter(
                post: post,
                reactionCount: _localReactionCount,
                showCaption: false,
                isTextOnly: isTextOnly,
                onBoostTap: () => _navigateToBoostPost(context, post),
                onInsightsTap: () => _navigateToBoostInsights(context, post),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdCard(BuildContext context, AdFeedItem adItem) {
    return AdCard(adCacheKey: adItem.cacheKey);
  }

  void _navigateToProfile(BuildContext context, PostModel post) {
    final navigationService = locator<NavigationService>();
    if (post.pageId != null) {
      navigationService.navigateTo(PageProfileScreen(pageId: post.pageId!));
    } else {
      navigationService.navigateTo(ProfileScreen(userId: post.authorId));
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
    locator<NavigationService>().navigateTo(
      ReportScreen(
        contentType: ReportContentType.post,
        contentId: post.id,
      ),
    );
  }

  void _navigateToBoostPost(BuildContext context, PostModel post) {
    locator<NavigationService>()
        .navigateTo(BoostPostScreen(post: post))
        .then((boosted) {
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
    locator<NavigationService>().navigateTo(BoostAnalyticsScreen(post: post));
  }

  void _navigateToGiftSelection(BuildContext context, PostModel post) async {
    final currentUserRef = locator<UserRepository>();
    final author = await currentUserRef.getUser(post.authorId);

    if (context.mounted) {
      locator<NavigationService>().navigateTo(
        GiftSendSelectionScreen(recipient: author),
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
        locator<NavigationService>()
            .navigateTo(HashtagExploreScreen(hashtag: hashtag));
      },
      onMentionTap: (username) async {
        final userRepository = locator<UserRepository>();
        final user = await userRepository.getUserByUsername(username);
        if (user != null && context.mounted) {
          locator<NavigationService>()
              .navigateTo(ProfileScreen(userId: user.id));
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
              padding: const EdgeInsets.only(top: DesignTokens.spaceXS),
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

  Widget _buildGhostPostCard(BuildContext context, GhostPostFeedItem ghost) {
    final theme = Theme.of(context);
    const brandGreen = SonarPulseTheme.primaryAccent;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Opacity(
      opacity: 0.85,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: brandGreen.withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ghost Header
            Padding(
              padding: const EdgeInsets.all(DesignTokens.postHeaderPadding),
              child: Row(
                children: [
                  UserAvatar(
                    url: currentUser?.photoURL,
                    size: AvatarSize.small,
                  ),
                  const SizedBox(width: DesignTokens.spaceSM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser?.displayName ?? 'You',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ghost.statusText ?? 'Posting...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: SemanticColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Ghost Media Placeholder
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                image: ghost.filePath != null
                    ? DecorationImage(
                        image: FileImage(File(ghost.filePath!)),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.4),
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.cloud_upload_outlined,
                      color: Colors.white, size: 48),
                  Positioned(
                    bottom: DesignTokens.spaceMD,
                    left: DesignTokens.spaceMD,
                    right: DesignTokens.spaceMD,
                    child: AchievementProgressBar(
                      progress: ghost.progress,
                    ),
                  ),
                ],
              ),
            ),

            if (ghost.caption != null && ghost.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
                child: Text(
                  ghost.caption!,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMD, vertical: DesignTokens.spaceXS),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: DesignTokens.spaceXS),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
