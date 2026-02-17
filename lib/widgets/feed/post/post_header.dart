// lib/widgets/feed/post/post_header.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/feed_item_model.dart' show PostDisplayType;
import 'package:freegram/theme/design_tokens.dart';
// Removed unused app_theme.dart import
import 'package:freegram/widgets/common/media_header.dart';
import 'package:freegram/widgets/achievements/badge_insight_dialog.dart';

/// Post header component
///
/// Features:
/// - Uses UserAvatar for consistent avatar display
/// - Handles "More Options" menu
/// - Shows display type badges
/// - Owner actions (Boost/Insights)
class PostHeader extends StatelessWidget {
  final PostModel post;
  final PostDisplayType displayType;
  final VoidCallback? onProfileTap;
  final Function(String)? onMenuSelected;
  final VoidCallback? onBoostTap;
  final VoidCallback? onInsightsTap;
  final bool isNew; // Whether this post is new (since last viewed)

  const PostHeader({
    super.key,
    required this.post,
    required this.displayType,
    this.onProfileTap,
    this.onMenuSelected,
    this.onBoostTap,
    this.onInsightsTap,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUserId == post.authorId;

    // Boost button moved to footer (opposite to likes/comments)

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
                color: Colors.red,
              ),
              const SizedBox(width: DesignTokens.spaceSM),
              Text(
                'Delete',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.red,
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
              Icon(
                Icons.flag_outlined,
                size: DesignTokens.iconMD,
                color: theme.iconTheme.color,
              ),
              const SizedBox(width: DesignTokens.spaceSM),
              Text('Report', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
    ];

    // Build display type badge
    Widget? displayTypeBadge;

    // New badge takes priority
    if (isNew) {
      displayTypeBadge = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceXS + 2,
          vertical: DesignTokens.spaceXS / 2,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
        ),
        child: Text(
          'NEW',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    } else if (displayType == PostDisplayType.trending) {
      displayTypeBadge = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceXS + 2,
          vertical: DesignTokens.spaceXS / 2,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.trending_up,
              size: 10,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'TRENDING',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    } else if (displayType == PostDisplayType.boosted) {
      displayTypeBadge = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceXS + 2,
          vertical: DesignTokens.spaceXS / 2,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
        ),
        child: Text(
          'PROMOTED',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return MediaHeader(
      avatarUrl: post.pagePhotoUrl ?? post.authorPhotoUrl,
      avatarBadgeUrl: post.pageBadgeUrl ?? post.authorBadgeUrl,
      username: post.pageName ?? post.authorUsername,
      timestamp: post.timestamp,
      location: post.locationInfo?['placeName'],
      isVerified: post.pageIsVerified == true,
      isEdited: post.edited,
      onAvatarTap: onProfileTap,
      onUsernameTap: onProfileTap,
      onBadgeTap: () {
        final badgeUrl = post.pageBadgeUrl ?? post.authorBadgeUrl;
        if (badgeUrl != null) {
          showBadgeInsight(context, badgeUrl: badgeUrl);
        }
      },
      badge: displayTypeBadge,
      actionButton: null, // Moved to footer (opposite to likes/comments)
      menuItems: menuItems,
      onMenuSelected: onMenuSelected,
      padding: EdgeInsets.zero, // No padding - handled by parent
      usernameStyle: theme.textTheme.titleMedium?.copyWith(
        color: SemanticColors.textPrimary(context),
        fontWeight: FontWeight.w600,
      ),
      timestampStyle: theme.textTheme.bodySmall?.copyWith(
        color: SemanticColors.textSecondary(context),
      ),
    );
  }
}
