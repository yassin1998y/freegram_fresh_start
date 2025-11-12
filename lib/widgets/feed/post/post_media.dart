// lib/widgets/feed/post/post_media.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/media_item_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/feed_widgets/post_video_player.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/screens/image_gallery_screen.dart';
import 'package:freegram/widgets/lqip_image.dart';

/// Post media component with AutomaticKeepAliveClientMixin
///
/// Features:
/// - Prevents video reloading when scrolling slightly off-screen
/// - Handles single images, multiple images (carousel), and videos
/// - Uses RepaintBoundary to isolate repaints
class PostMedia extends StatefulWidget {
  final PostModel post;
  final bool loadMedia;

  const PostMedia({
    super.key,
    required this.post,
    this.loadMedia = true,
  });

  @override
  State<PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<PostMedia>
    with AutomaticKeepAliveClientMixin {
  late PageController _pageController;
  int _currentPage = 0;
  final Map<int, bool> _expandedCaptions =
      {}; // Track expanded state per media item

  @override
  bool get wantKeepAlive => true; // Keep video state stable

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (widget.post.mediaItems.isEmpty && widget.post.mediaUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    // Use mediaItems if available, otherwise fall back to mediaUrls
    if (widget.post.mediaItems.isNotEmpty) {
      return _buildMediaCarousel();
    } else {
      return _buildMediaGrid();
    }
  }

  Widget _buildMediaCarousel() {
    if (widget.post.mediaItems.length == 1) {
      return _buildSingleMedia(widget.post.mediaItems.first, 0);
    }

    // Multiple media items - use PageView
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 500),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const ClampingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: widget.post.mediaItems.length,
              itemBuilder: (context, index) {
                return _buildSingleMedia(widget.post.mediaItems[index], index);
              },
            ),
          ),
          // Page indicator dots
          if (widget.post.mediaItems.length > 1)
            Padding(
              padding: EdgeInsets.symmetric(vertical: DesignTokens.spaceSM),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.post.mediaItems.length,
                  (index) => Container(
                    margin:
                        EdgeInsets.symmetric(horizontal: DesignTokens.spaceXS),
                    width: DesignTokens.spaceSM,
                    height: DesignTokens.spaceSM,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(DesignTokens.opacityMedium),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSingleMedia(MediaItem mediaItem, int index) {
    if (mediaItem.type == 'video') {
      return RepaintBoundary(
        child: PostVideoPlayer(
          mediaItem: mediaItem,
          loadMedia: widget.loadMedia,
        ),
      );
    }

    // Single image
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final maxHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 500.0;

        return GestureDetector(
          onTap: () {
            final imageUrls = widget.post.mediaItems
                .where((item) => item.type == 'image')
                .map((item) => item.url)
                .toList();
            final imageIndex = widget.post.mediaItems
                .where((item) => item.type == 'image')
                .toList()
                .indexWhere((item) => item.url == mediaItem.url);
            if (imageIndex >= 0 && imageUrls.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageGalleryScreen(
                    imageUrls: imageUrls,
                    initialIndex: imageIndex,
                  ),
                ),
              );
            }
          },
          child: SizedBox(
            height: maxHeight,
            width: screenWidth,
            child: RepaintBoundary(
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
                              color: Colors.grey[100],
                              child: const Center(
                                child: AppProgressIndicator(),
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
                      child: _buildMediaCaption(mediaItem.caption!, index),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaCaption(String caption, int mediaIndex) {
    final isExpanded = _expandedCaptions[mediaIndex] ?? false;

    // Check if caption needs expansion
    final textPainter = TextPainter(
      text: TextSpan(
        text: caption,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      maxLines: 2,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(
      maxWidth: MediaQuery.of(context).size.width - DesignTokens.spaceMD * 2,
    );
    final needsExpansion = textPainter.didExceedMaxLines;

    return Container(
      padding: EdgeInsets.all(DesignTokens.spaceMD),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            caption,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: isExpanded ? null : 2,
            overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (needsExpansion && !isExpanded)
            GestureDetector(
              onTap: () {
                setState(() {
                  _expandedCaptions[mediaIndex] = true;
                });
              },
              child: Padding(
                padding: EdgeInsets.only(top: DesignTokens.spaceXS),
                child: const Text(
                  'show more',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          if (needsExpansion && isExpanded)
            GestureDetector(
              onTap: () {
                setState(() {
                  _expandedCaptions[mediaIndex] = false;
                });
              },
              child: Padding(
                padding: EdgeInsets.only(top: DesignTokens.spaceXS),
                child: const Text(
                  'show less',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid() {
    if (widget.post.mediaUrls.isEmpty) return const SizedBox.shrink();

    if (widget.post.mediaUrls.length == 1) {
      return Padding(
        padding: EdgeInsets.all(DesignTokens.spaceSM),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageGalleryScreen(
                  imageUrls: widget.post.mediaUrls,
                  initialIndex: 0,
                ),
              ),
            );
          },
          child: Hero(
            tag: widget.post.mediaUrls.first,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              child: SizedBox(
                width: double.infinity,
                height: 300,
                child: widget.loadMedia
                    ? LQIPImage(
                        imageUrl: widget.post.mediaUrls.first,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey[100],
                        child: const Center(
                          child: AppProgressIndicator(),
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    }

    // Multiple images in grid
    return Padding(
      padding: EdgeInsets.all(DesignTokens.spaceSM),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: widget.post.mediaUrls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageGalleryScreen(
                    imageUrls: widget.post.mediaUrls,
                    initialIndex: index,
                  ),
                ),
              );
            },
            child: Hero(
              tag: widget.post.mediaUrls[index],
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                child: widget.loadMedia
                    ? LQIPImage(
                        imageUrl: widget.post.mediaUrls[index],
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey[100],
                        child: const Center(
                          child: AppProgressIndicator(),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
