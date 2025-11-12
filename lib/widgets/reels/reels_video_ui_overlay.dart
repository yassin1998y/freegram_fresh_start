// lib/widgets/reels/reels_video_ui_overlay.dart
// Facebook Reels-style UI overlay

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/common/app_reaction_button.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReelsVideoUIOverlay extends StatelessWidget {
  final ReelModel reel;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onProfileTap;

  const ReelsVideoUIOverlay({
    Key? key,
    required this.reel,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onProfileTap,
  }) : super(key: key);

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        // Bottom gradient for text readability - extends into safe area
        Positioned(
          bottom: -safeAreaBottom, // Extend into safe area
          left: 0,
          right: 0,
          child: Container(
            height: screenHeight * 0.4 +
                safeAreaBottom, // Include safe area in height
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(DesignTokens.opacityHigh),
                  Colors.black.withOpacity(
                    DesignTokens.opacityHigh,
                  ), // Keep solid at bottom for safe area
                  Colors.black.withOpacity(DesignTokens.opacityMedium),
                  Colors.transparent,
                ],
                stops: const [
                  0.0,
                  0.1,
                  0.5,
                  1.0
                ], // Adjust stops for smooth transition
              ),
            ),
          ),
        ),

        // User info and caption (bottom-left) - Facebook Reels style
        Positioned(
          bottom: DesignTokens.spaceXXXL + safeAreaBottom,
          left: DesignTokens.spaceMD,
          right:
              DesignTokens.spaceXXXL, // Leave space for action buttons on right
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // User info row (tappable)
              GestureDetector(
                onTap: onProfileTap,
                child: Row(
                  children: [
                    Container(
                      width: DesignTokens.iconXXL,
                      height: DesignTokens.iconXXL,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: DesignTokens.elevation1,
                        ),
                      ),
                      child: ClipOval(
                        child: reel.uploaderAvatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: reel.uploaderAvatarUrl,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: DesignTokens.iconMD,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: DesignTokens.iconMD,
                              ),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceSM),
                    Expanded(
                      child: Text(
                        reel.uploaderUsername,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: DesignTokens.fontSizeMD,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spaceSM),
              // Caption
              if (reel.caption != null && reel.caption!.isNotEmpty)
                Text(
                  reel.caption!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: DesignTokens.fontSizeSM,
                    height: DesignTokens.lineHeightNormal,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),

        // Action buttons (right side) - Facebook Reels style (vertical stack)
        Positioned(
          bottom: DesignTokens.spaceXXL * 1.25 + safeAreaBottom,
          right: DesignTokens.spaceMD,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Like button - using AppReactionButton in vertical layout
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppReactionButton(
                    isLiked: isLiked,
                    reactionCount: reel.likeCount,
                    isLoading: false,
                    onTap: onLike,
                    showCount: false,
                    size: DesignTokens.iconXXL,
                  ),
                  const SizedBox(height: DesignTokens.spaceXS),
                  Text(
                    _formatCount(reel.likeCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: DesignTokens.fontSizeSM,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceLG),
              // Comment button
              _FacebookStyleActionButton(
                icon: Icons.comment_outlined,
                iconColor: Colors.white,
                count: reel.commentCount,
                onTap: onComment,
              ),
              const SizedBox(height: DesignTokens.spaceLG),
              // Share button
              _FacebookStyleActionButton(
                icon: Icons.share_outlined,
                iconColor: Colors.white,
                count: reel.shareCount,
                onTap: onShare,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Facebook Reels-style action button (vertical layout)
class _FacebookStyleActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int count;
  final VoidCallback onTap;

  const _FacebookStyleActionButton({
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: DesignTokens.iconXXL,
            height: DesignTokens.iconXXL,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(DesignTokens.opacityMedium),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: DesignTokens.iconXL,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXS),
          Text(
            _formatCount(count),
            style: const TextStyle(
              color: Colors.white,
              fontSize: DesignTokens.fontSizeSM,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
