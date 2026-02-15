// lib/widgets/feed_widgets/trending_post_card.dart

import 'package:flutter/material.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/media_item_model.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/screens/post_detail_screen.dart';

/// Compact card widget for horizontal trending sections
/// Shows only the media with minimal overlay info
class TrendingPostCard extends StatelessWidget {
  final PostFeedItem item;
  final VoidCallback? onTap;

  const TrendingPostCard({
    Key? key,
    required this.item,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final post = item.post;
    final hasMedia = post.mediaItems.isNotEmpty || post.mediaUrls.isNotEmpty;

    return GestureDetector(
      onTap: onTap ??
          () {
            // Navigate to post detail screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(
                  postId: post.id,
                ),
              ),
            );
          },
      child: SizedBox(
        width: 220,
        height: 160,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Media/Image
                if (hasMedia)
                  _buildMedia(context, post)
                else
                  _buildPlaceholder(context, post),

                // Gradient overlay at bottom for text (only for posts with media)
                if (hasMedia)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Content overlay (author name, etc.) - only for posts with media
                // Text-only posts show content in the background instead
                if (hasMedia)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: SizedBox(
                      height: 52, // Fixed height to prevent overflow
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            post.pageName ?? post.authorUsername,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (post.content.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              post.content,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // Badge overlay (top right)
                if (item.displayType == PostDisplayType.trending)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.9),
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
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedia(BuildContext context, PostModel post) {
    final mediaItem = post.mediaItems.isNotEmpty
        ? post.mediaItems.first
        : (post.mediaUrls.isNotEmpty
            ? MediaItem(
                url: post.mediaUrls.first,
                type: post.mediaTypes.isNotEmpty
                    ? post.mediaTypes.first
                    : 'image',
              )
            : null);

    if (mediaItem == null) {
      return _buildPlaceholder(context, post);
    }

    final mediaUrl = mediaItem.url;
    final mediaType = mediaItem.type.toLowerCase();

    // Check if it's a video or reel
    final isVideo = mediaType == 'video' || mediaType == 'reel';

    if (isVideo) {
      return _buildVideoWithPlayButton(context, mediaItem, mediaUrl);
    }

    // Image
    return CachedNetworkImage(
      imageUrl: mediaUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[300],
        child: const Center(
          child: AppProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => _buildPlaceholder(context, post),
    );
  }

  Widget _buildVideoWithPlayButton(
    BuildContext context,
    MediaItem mediaItem,
    String mediaUrl,
  ) {
    // Use video URL as thumbnail (may show first frame if supported)
    final thumbnailUrl = mediaUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video thumbnail/background
        CachedNetworkImage(
          imageUrl: thumbnailUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[800],
            child: const Center(
              child: AppProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[800],
            child: const Center(
              child: Icon(
                Icons.videocam,
                size: 40,
                color: Colors.white54,
              ),
            ),
          ),
        ),
        // Play button overlay
        Center(
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.5),
            ),
            padding: const EdgeInsets.all(12),
            child: const Icon(
              Icons.play_circle_filled,
              size: 48,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context, PostModel post) {
    // If it's a text-only post, show styled background
    if (post.content.isNotEmpty &&
        post.mediaItems.isEmpty &&
        post.mediaUrls.isEmpty) {
      return _buildTextPostBackground(context, post);
    }

    // Default placeholder for empty posts
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          post.content.isNotEmpty ? Icons.text_fields : Icons.image,
          size: 40,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildTextPostBackground(BuildContext context, PostModel post) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author name
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.3),
                  ),
                  child: Icon(
                    Icons.person,
                    size: 16,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    post.pageName ?? post.authorUsername,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Post content preview
            Expanded(
              child: Text(
                post.content,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
