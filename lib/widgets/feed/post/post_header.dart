// lib/widgets/feed/post/post_header.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/feed_item_model.dart' show PostDisplayType;
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/common/media_header.dart';

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
              SizedBox(width: DesignTokens.spaceSM),
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
              SizedBox(width: DesignTokens.spaceSM),
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
            SizedBox(width: DesignTokens.spaceSM),
            Text('Share', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
      if (isOwner)
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete,
                size: DesignTokens.iconMD,
                color: Colors.red,
              ),
              SizedBox(width: DesignTokens.spaceSM),
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
              SizedBox(width: DesignTokens.spaceSM),
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
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceXS,
          vertical: DesignTokens.spaceXS / 2,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
        ),
        child: Text(
          'New',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (displayType == PostDisplayType.trending) {
      displayTypeBadge = Container(
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceXS,
          vertical: DesignTokens.spaceXS / 2,
        ),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
        ),
        child: Text(
          'Trending',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (displayType == PostDisplayType.nearby) {
      displayTypeBadge = Container(
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceXS,
          vertical: DesignTokens.spaceXS / 2,
        ),
        decoration: BoxDecoration(
          color: SonarPulseTheme.primaryAccent,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
        ),
        child: Text(
          'Near You',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (displayType == PostDisplayType.boosted) {
      displayTypeBadge = Container(
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceXS,
          vertical: DesignTokens.spaceXS / 2,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
        ),
        child: Text(
          'Promoted',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return MediaHeader(
      avatarUrl: post.pagePhotoUrl ?? post.authorPhotoUrl,
      username: post.pageName ?? post.authorUsername,
      timestamp: post.timestamp,
      location: post.locationInfo?['placeName'],
      isVerified: post.pageIsVerified == true,
      isEdited: post.edited,
      onAvatarTap: onProfileTap,
      onUsernameTap: onProfileTap,
      badge: displayTypeBadge,
      actionButton: null, // Moved to footer (opposite to likes/comments)
      menuItems: menuItems,
      onMenuSelected: onMenuSelected,
      padding: EdgeInsets.all(DesignTokens.spaceMD),
    );
  }
}
