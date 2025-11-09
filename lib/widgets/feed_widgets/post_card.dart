// lib/widgets/feed_widgets/post_card.dart

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/widgets/feed_widgets/like_button.dart';
import 'package:freegram/widgets/feed_widgets/comments_sheet.dart';
import 'package:freegram/widgets/feed_widgets/liked_by_list.dart';
import 'package:freegram/widgets/feed_widgets/ad_card.dart';
import 'package:freegram/widgets/feed_widgets/suggestion_carousel.dart';
import 'package:freegram/widgets/common/media_header.dart';
import 'package:freegram/utils/location_utils.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/services/mention_service.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/screens/page_profile_screen.dart';
import 'package:freegram/screens/hashtag_explore_screen.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/screens/image_gallery_screen.dart';
import 'package:freegram/screens/report_screen.dart';
import 'package:freegram/screens/boost_post_screen.dart';
import 'package:freegram/screens/boost_analytics_screen.dart';
import 'package:freegram/models/report_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:freegram/services/analytics_service.dart';
import 'package:freegram/services/boost_analytics_service.dart';
import 'package:freegram/widgets/lqip_image.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class PostCard extends StatefulWidget {
  final FeedItem item;
  final bool loadMedia; // Phase 3.3: Lazy loading flag
  final GeoPoint? userLocation; // CRITICAL FIX: Accept cached location from parent

  const PostCard({
    Key? key,
    required this.item,
    this.loadMedia = true, // Default to true for backward compatibility
    this.userLocation, // Optional, fallback to fetching if not provided
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  GeoPoint? _userLocation;
  double? _distance;
  bool _hasTrackedBoostImpression = false;
  static final Set<String> _trackedAdImpressions =
      {}; // Track ad impressions globally
  final PostRepository _postRepository = locator<PostRepository>();
  final BoostAnalyticsService _boostAnalytics = BoostAnalyticsService();
  late PageController _pageController;
  int _currentPage = 0;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Track boost impression and load location only for post items
    if (widget.item is PostFeedItem) {
      final postItem = widget.item as PostFeedItem;
      
      // CRITICAL FIX: Use cached location if provided, otherwise fetch
      if (widget.userLocation != null) {
        _userLocation = widget.userLocation;
      } else {
        _loadUserLocation();
      }
      
      if (postItem.post.isBoosted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _trackBoostImpression(postItem.post);
        });
      }
    } else if (widget.item is AdFeedItem) {
      // Ad items will track impressions via VisibilityDetector
    }
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      // Cleanup: Dispose page controller
      _pageController.dispose();
      
      // Clear any cached data for this post
      // Note: Image cache is handled by CachedNetworkImage automatically
      
      debugPrint('🧹 PostCard: Disposed post ${widget.item is PostFeedItem ? (widget.item as PostFeedItem).post.id : "unknown"}');
    }
    super.dispose();
  }

  Future<void> _trackBoostImpression(PostModel post) async {
    if (!_hasTrackedBoostImpression && post.isBoosted) {
      _hasTrackedBoostImpression = true;
      try {
        // Track via Cloud Function (preferred - server-side)
        await _boostAnalytics.trackBoostImpression(post.id);

        // Also track via repository (client-side fallback)
        await _postRepository.trackBoostImpression(post.id);
      } catch (e) {
        debugPrint('PostCard: Error tracking boost impression: $e');
      }
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      if (mounted) {
        setState(() {
          _userLocation = GeoPoint(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      debugPrint('PostCard: Error loading user location: $e');
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
    // Calculate distance if needed
    if (_userLocation != null && post.location != null && _distance == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _distance = LocationUtils.calculateDistanceToPost(
              _userLocation,
              post.location,
            );
          });
        }
      });
    }

    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceSM,
        vertical: DesignTokens.spaceXS,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER SECTION
          _buildHeader(context, post, displayType),

          // CONTENT SECTION
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              child: _buildRichContent(context, post),
            ),

          // MEDIA SECTION - Use reasonable max height to prevent overflow
          if (post.mediaItems.isNotEmpty) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight:
                    500, // Fixed reasonable max height instead of 85% screen
              ),
              child: _buildMediaCarousel(context, post),
            ),
            // Page indicator dots
            if (post.mediaItems.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSM),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    post.mediaItems.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spaceXS,
                      ),
                      width: DesignTokens.spaceSM,
                      height: DesignTokens.spaceSM,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(
                                DesignTokens.opacityMedium,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
          ] else if (post.mediaUrls.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 500, // Fixed reasonable max height
              ),
              child: _buildMediaGrid(context, post),
            ),

          // Hashtags (as clickable chips)
          if (post.hashtags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceMD,
                vertical: DesignTokens.spaceSM,
              ),
              child: Wrap(
                spacing: DesignTokens.spaceSM,
                children: post.hashtags.map((tag) {
                  final normalizedTag =
                      tag.startsWith('#') ? tag.substring(1) : tag;
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HashtagExploreScreen(
                            hashtag: normalizedTag,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
                    child: Chip(
                      label: Text(
                        '#$normalizedTag',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      backgroundColor: theme.colorScheme.primary.withOpacity(
                        0.1,
                      ),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                }).toList(),
              ),
            ),

          // ACTIONS SECTION (Like, Comment, Share)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceXS,
              vertical: DesignTokens.spaceSM,
            ),
            child: Row(
              children: [
                Expanded(
                  child: LikeButton(post: post),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => CommentsSheet(post: post),
                      );
                    },
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spaceSM,
                        vertical: DesignTokens.spaceXS,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: DesignTokens.iconLG,
                            color: theme.iconTheme.color,
                          ),
                          const SizedBox(width: DesignTokens.spaceXS),
                          if (post.commentCount > 0)
                            Text(
                              post.commentCount.toString(),
                              style: theme.textTheme.labelLarge,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: IconButton(
                    icon: Icon(
                      Icons.share_outlined,
                      color: theme.iconTheme.color,
                    ),
                    onPressed: () => _sharePost(context, post),
                  ),
                ),
              ],
            ),
          ),

          // ENGAGEMENT SECTION (Likes count, comments)
          if (post.reactionCount > 0 || post.commentCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceMD,
                vertical: DesignTokens.spaceXS,
              ),
              child: Row(
                children: [
                  if (post.reactionCount > 0)
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => LikedByList(
                            postId: post.id,
                            totalLikes: post.reactionCount,
                          ),
                        );
                      },
                      child: Text(
                        '${post.reactionCount} ${post.reactionCount == 1 ? 'like' : 'likes'}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(
                            DesignTokens.opacityMedium,
                          ),
                        ),
                      ),
                    ),
                  if (post.reactionCount > 0 && post.commentCount > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spaceSM,
                      ),
                      child: Text(
                        '•',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(
                            DesignTokens.opacityMedium,
                          ),
                        ),
                      ),
                    ),
                  if (post.commentCount > 0)
                    Text(
                      '${post.commentCount} ${post.commentCount == 1 ? 'comment' : 'comments'}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(
                          DesignTokens.opacityMedium,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    PostModel post,
    PostDisplayType displayType,
  ) {
    final theme = Theme.of(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUserId == post.authorId;

    // Build action button (Boost/Insights) for post owner
    Widget? actionButton;
    if (isOwner) {
      final isBoosted = post.isBoosted &&
          post.boostEndTime != null &&
          post.boostEndTime!.toDate().isAfter(DateTime.now());

      if (isBoosted) {
        // Show "View Insights" for active boosts
        actionButton = TextButton.icon(
          onPressed: () => _navigateToBoostInsights(context, post),
          icon: Icon(
            Icons.insights,
            size: DesignTokens.iconSM,
            color: theme.colorScheme.primary,
          ),
          label: Text(
            'View Insights',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceSM,
              vertical: DesignTokens.spaceXS,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      } else {
        // Show "Boost" for non-boosted posts
        actionButton = TextButton.icon(
          onPressed: () => _navigateToBoostPost(context, post),
          icon: Icon(
            Icons.trending_up,
            size: DesignTokens.iconSM,
            color: theme.colorScheme.primary,
          ),
          label: Text(
            'Boost',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceSM,
              vertical: DesignTokens.spaceXS,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      }
    }

    // Build menu items
    final menuItems = <PopupMenuEntry<String>>[
      if (isOwner)
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(
                Icons.edit,
                size: DesignTokens.iconMD,
                color: theme.iconTheme.color,
              ),
              const SizedBox(width: DesignTokens.spaceSM),
              Text('Edit', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      if (isOwner)
        PopupMenuItem(
          value: post.isPinned ? 'unpin' : 'pin',
          child: Row(
            children: [
              Icon(
                post.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: DesignTokens.iconMD,
                color: theme.iconTheme.color,
              ),
              const SizedBox(width: DesignTokens.spaceSM),
              Text(
                post.isPinned ? 'Unpin' : 'Pin',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      PopupMenuItem(
        value: 'share',
        child: Row(
          children: [
            Icon(
              Icons.share,
              size: DesignTokens.iconMD,
              color: theme.iconTheme.color,
            ),
            const SizedBox(width: DesignTokens.spaceSM),
            Text('Share', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
      if (isOwner)
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(
                Icons.delete,
                size: DesignTokens.iconMD,
                color: DesignTokens.errorColor,
              ),
              const SizedBox(width: DesignTokens.spaceSM),
              Text(
                'Delete',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: DesignTokens.errorColor,
                ),
              ),
            ],
          ),
        ),
      if (!isOwner)
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              const Icon(
                Icons.flag,
                size: DesignTokens.iconMD,
                color: DesignTokens.warningColor,
              ),
              const SizedBox(width: DesignTokens.spaceSM),
              Text(
                'Report',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: DesignTokens.warningColor,
                ),
              ),
            ],
          ),
        ),
    ];

    // Build display type badge
    Widget? displayTypeBadge;
    if (displayType != PostDisplayType.organic) {
      displayTypeBadge = _buildDisplayTypeBadge(displayType);
    }

    return MediaHeader(
      avatarUrl: post.pagePhotoUrl ?? post.authorPhotoUrl,
      username: post.pageName ?? post.authorUsername,
      timestamp: post.timestamp,
      location: post.locationInfo?['placeName'],
      isVerified: post.pageIsVerified == true,
      isEdited: post.edited,
      onAvatarTap: () => _navigateToProfile(context, post),
      onUsernameTap: () => _navigateToProfile(context, post),
      badge: displayTypeBadge,
      actionButton: actionButton,
      menuItems: menuItems,
      onMenuSelected: (value) {
        if (value == 'edit') {
          _navigateToEditPost(context, post);
        } else if (value == 'pin') {
          _pinPost(context, post);
        } else if (value == 'unpin') {
          _unpinPost(context, post);
        } else if (value == 'delete') {
          _deletePost(context, post);
        } else if (value == 'share') {
          _sharePost(context, post);
        } else if (value == 'report') {
          _reportPost(context, post);
        }
      },
    );
  }

  Widget _buildDisplayTypeBadge(PostDisplayType type) {
    final theme = Theme.of(context);

    // Special styling for trending badge to match horizontal trail
    if (type == PostDisplayType.trending) {
      return Semantics(
        label: 'Trending post',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.whatshot,
                size: 12,
                color: Colors.white,
              ),
              SizedBox(width: 2),
              Text(
                'Trending',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final (label, color, icon, semanticLabel) = switch (type) {
      PostDisplayType.boosted => (
          'Promoted',
          DesignTokens.warningColor,
          Icons.trending_up,
          'Promoted post'
        ),
      PostDisplayType.nearby => (
          'Near You',
          DesignTokens.successColor,
          Icons.location_on,
          'Post near your location'
        ),
      PostDisplayType.page => ('', Colors.transparent, null, ''),
      PostDisplayType.organic => ('', Colors.transparent, null, ''),
      PostDisplayType.trending => (
          '',
          Colors.transparent,
          null,
          ''
        ), // Handled above
    };

    // Return empty widget if no label
    if (label.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceXS + 2,
          vertical: DesignTokens.spaceXS / 2,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: DesignTokens.iconSM,
                color: color,
              ),
              const SizedBox(width: DesignTokens.spaceXS),
            ],
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: DesignTokens.fontSizeXS,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdCard(BuildContext context, AdFeedItem adItem) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Sponsored advertisement',
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceSM,
          vertical: DesignTokens.spaceXS,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AD LABEL (Top-left, mandatory)
            Semantics(
              label: 'Sponsored content',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMD - DesignTokens.spaceXS,
                  vertical: DesignTokens.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: DesignTokens.infoColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(DesignTokens.radiusMD),
                    topRight: Radius.circular(DesignTokens.radiusMD),
                  ),
                ),
                width: double.infinity,
                child: Row(
                  children: [
                    const Icon(
                      Icons.campaign,
                      size: DesignTokens.iconSM,
                      color: DesignTokens.infoColor,
                    ),
                    const SizedBox(width: DesignTokens.spaceXS),
                    Flexible(
                      child: Text(
                        'Sponsored',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DesignTokens.infoColor,
                          fontSize: DesignTokens.fontSizeXS,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    Semantics(
                      label: 'Learn why you are seeing this advertisement',
                      button: true,
                      child: TextButton(
                        onPressed: () => _showAdDisclosure(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceSM,
                            vertical: DesignTokens.spaceXS,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Why this ad?',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: DesignTokens.fontSizeXS,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // AD CONTENT (use existing AdCard widget)
            // Wrap with VisibilityDetector for analytics
            _buildAdContentWithTracking(context, adItem),
          ],
        ),
      ),
    );
  }

  Widget _buildAdContentWithTracking(BuildContext context, AdFeedItem adItem) {
    return VisibilityDetector(
      key: Key('ad_${adItem.cacheKey}'),
      onVisibilityChanged: (info) {
        // Track ad impression when 50% visible (only once per ad cacheKey)
        if (info.visibleFraction > 0.5 &&
            !_trackedAdImpressions.contains(adItem.cacheKey)) {
          _trackedAdImpressions.add(adItem.cacheKey);
          AnalyticsService().trackAdImpression(adItem.cacheKey, 'banner');
          debugPrint('📊 Ad impression tracked: ${adItem.cacheKey}');
        }
      },
      child: AdCard(adCacheKey: adItem.cacheKey),
    );
  }

  void _showAdDisclosure(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Why this ad?'),
        content: const Text(
          'This ad is shown to you based on your activity and interests to help support free services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaCarousel(BuildContext context, PostModel post) {
    // Show full image without cropping, maintaining natural aspect ratio
    // Use simple Image widget wrapped in GestureDetector for single images to avoid scroll blocking
    if (post.mediaItems.length == 1) {
      // Single image - use simple approach that won't block scroll
      final mediaItem = post.mediaItems.first;
      return LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.of(context).size.width;
          // Use constraints.maxHeight from parent ConstrainedBox (500px max)
          final maxHeight =
              constraints.maxHeight.isFinite ? constraints.maxHeight : 500.0;

          return GestureDetector(
            onTap: () {
              final imageUrls = [mediaItem.url];
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageGalleryScreen(
                    imageUrls: imageUrls,
                    initialIndex: 0,
                  ),
                ),
              );
            },
            child: SizedBox(
              height: maxHeight,
              width: screenWidth,
              child: VisibilityDetector(
                key: Key('media_${post.id}_${mediaItem.url}'),
                onVisibilityChanged: (info) {
                  // Track visibility for analytics/optimization
                  if (info.visibleFraction > 0.5 && kDebugMode) {
                    debugPrint('Post ${post.id} media is ${(info.visibleFraction * 100).toStringAsFixed(0)}% visible');
                  }
                },
                child: Stack(
                  children: [
                    Center(
                      child: Hero(
                        tag: mediaItem.url,
                        child: widget.loadMedia
                            ? CachedNetworkImage(
                                imageUrl: mediaItem.url,
                                fit: BoxFit.contain,
                                width: screenWidth,
                                placeholder: (context, url) => Container(
                                  width: screenWidth,
                                  height: 300,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: AppProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: screenWidth,
                                  height: 300,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                ),
                              )
                            : Container(
                                width: screenWidth,
                                height: 300,
                                color: Colors.grey[100], // Lighter placeholder color
                                child: const Center(
                                  child: AppProgressIndicator(), // Show loading indicator instead of icon
                                ),
                              ),
                      ),
                    ),
                  if (mediaItem.caption != null &&
                      mediaItem.caption!.isNotEmpty)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Text(
                          mediaItem.caption!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // Multiple images - use PageView but with proper physics to allow vertical scroll
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        // Use constraints.maxHeight from parent ConstrainedBox (500px max)
        final maxHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 500.0;

        return SizedBox(
          height: maxHeight,
          child: PageView.builder(
            controller: _pageController,
            physics:
                const ClampingScrollPhysics(), // Prevent bounce, allow vertical scroll through
            scrollDirection: Axis.horizontal,
            allowImplicitScrolling:
                false, // Prevent interference with vertical scroll
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: post.mediaItems.length,
            itemBuilder: (context, index) {
              final mediaItem = post.mediaItems[index];
              return GestureDetector(
                onTap: () {
                  final imageUrls =
                      post.mediaItems.map((item) => item.url).toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageGalleryScreen(
                        imageUrls: imageUrls,
                        initialIndex: index,
                      ),
                    ),
                  );
                },
                child: SizedBox(
                  height: maxHeight,
                  width: screenWidth,
                  child: Stack(
                    children: [
                      Center(
                        child: Hero(
                          tag: mediaItem.url,
                          child: CachedNetworkImage(
                            imageUrl: mediaItem.url,
                            fit: BoxFit.contain,
                            width: screenWidth,
                            height: maxHeight, // Add height constraint
                            placeholder: (context, url) => SizedBox(
                              width: screenWidth,
                              height: 300,
                              child: Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: AppProgressIndicator(),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => SizedBox(
                              width: screenWidth,
                              height: 300,
                              child: Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (mediaItem.caption != null &&
                          mediaItem.caption!.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.7),
                                  Colors.black.withOpacity(0.3),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Text(
                              mediaItem.caption!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMediaGrid(BuildContext context, PostModel post) {
    if (post.mediaUrls.isEmpty) return const SizedBox.shrink();

    if (post.mediaUrls.length == 1) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageGalleryScreen(
                  imageUrls: post.mediaUrls,
                  initialIndex: 0,
                ),
              ),
            );
          },
          child: Hero(
            tag: post.mediaUrls.first,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: SizedBox(
                width: double.infinity,
                height: 300,
                child: widget.loadMedia
                    ? LQIPImage(
                        imageUrl: post.mediaUrls.first,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey[100], // Lighter placeholder color
                        child: const Center(
                          child: AppProgressIndicator(), // Show loading indicator instead of icon
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    }

    // Multiple images - show grid
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: post.mediaUrls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageGalleryScreen(
                    imageUrls: post.mediaUrls,
                    initialIndex: index,
                  ),
                ),
              );
            },
            child: VisibilityDetector(
              key: Key('media_grid_${post.id}_$index'),
              onVisibilityChanged: (info) {
                // Track visibility for analytics/optimization
                if (info.visibleFraction > 0.5 && kDebugMode) {
                  debugPrint('Post ${post.id} media grid item $index is ${(info.visibleFraction * 100).toStringAsFixed(0)}% visible');
                }
              },
              child: Hero(
                tag: post.mediaUrls[index],
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: widget.loadMedia
                      ? LQIPImage(
                          imageUrl: post.mediaUrls[index],
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey[100], // Lighter placeholder color
                          child: const Center(
                            child: AppProgressIndicator(), // Show loading indicator instead of icon
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRichContent(BuildContext context, PostModel post) {
    final text = post.content;
    final mentionService = locator<MentionService>();

    final spans = mentionService.formatTextWithMentionsAndHashtags(
      text,
      defaultStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.4,
          ),
      mentionStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.4,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
      hashtagStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.4,
            color: Theme.of(context).colorScheme.primary,
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

    return RichText(
      text: TextSpan(children: spans),
    );
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

  void _navigateToEditPost(BuildContext context, PostModel post) {
    // TODO: Implement post editing in CreatePostWidget
    // For now, show a message that editing is not yet available
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post editing will be available soon')),
    );
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pin post: $e')),
        );
      }
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unpin post: $e')),
        );
      }
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete post: $e')),
          );
        }
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

  Future<void> _sharePost(BuildContext context, PostModel post) async {
    try {
      final authorName = post.pageName ?? post.authorUsername;
      final deepLink = 'https://freegram.app/post/${post.id}';

      String shareText;
      if (post.content.isNotEmpty) {
        final contentPreview = post.content.length > 100
            ? '${post.content.substring(0, 100)}...'
            : post.content;
        shareText =
            '$authorName: $contentPreview\n\nCheck out this post on Freegram: $deepLink';
      } else {
        shareText =
            '$authorName shared a post via Freegram\n\nCheck it out: $deepLink';
      }

      await Share.share(
        shareText,
        subject: 'Post by $authorName',
      );
    } catch (e) {
      debugPrint('PostCard: Error sharing post: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share post')),
        );
      }
    }
  }

  void _navigateToBoostPost(BuildContext context, PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BoostPostScreen(post: post),
      ),
    ).then((boosted) {
      if (boosted == true && context.mounted) {
        // Refresh feed or show success message
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
