// lib/widgets/common/media_header.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/common/sonar_verified_badge.dart';
import 'package:intl/intl.dart';

/// Reusable media header widget for posts, reels, stories, etc.
///
/// This widget standardizes the header pattern across the app:
/// - Avatar (tappable)
/// - Username/Name with optional verified badge
/// - Timestamp with optional location and "Edited" indicator
/// - Optional display type badges
/// - Optional action buttons (e.g., Boost/Insights)
/// - Optional menu button (e.g., Edit, Delete, Share, Report)
class MediaHeader extends StatelessWidget {
  /// Avatar image URL
  final String? avatarUrl;

  /// Username or display name
  final String username;

  /// Timestamp to display
  final DateTime? timestamp;

  /// Location name to display (optional)
  final String? location;

  /// Whether the user/page is verified
  final bool isVerified;

  /// Whether the content was edited
  final bool isEdited;

  /// Callback when avatar is tapped
  final VoidCallback? onAvatarTap;

  /// Callback when username is tapped
  final VoidCallback? onUsernameTap;

  /// Optional badge widget (e.g., Trending, Promoted, Near You)
  final Widget? badge;

  /// Optional action button (e.g., Boost, View Insights)
  final Widget? actionButton;

  /// Optional menu items for PopupMenuButton
  final List<PopupMenuEntry<String>>? menuItems;

  /// Callback when menu item is selected
  final Function(String)? onMenuSelected;

  /// Padding around the header
  final EdgeInsets? padding;

  /// Avatar radius (defaults to DesignTokens.avatarSize / 2)
  final double? avatarRadius;

  /// Avatar background color (for fallback when no image)
  final Color? avatarBackgroundColor;

  /// Username text style
  final TextStyle? usernameStyle;

  /// Timestamp text style
  final TextStyle? timestampStyle;

  /// Whether to show the menu button
  final bool showMenu;

  /// Custom menu button icon
  final IconData? menuIcon;

  /// Custom menu button color
  final Color? menuIconColor;

  /// Optional close button (for screens like story viewer)
  final Widget? closeButton;

  const MediaHeader({
    super.key,
    required this.username,
    this.avatarUrl,
    this.timestamp,
    this.location,
    this.isVerified = false,
    this.isEdited = false,
    this.onAvatarTap,
    this.onUsernameTap,
    this.badge,
    this.actionButton,
    this.menuItems,
    this.onMenuSelected,
    this.padding,
    this.avatarRadius,
    this.avatarBackgroundColor,
    this.usernameStyle,
    this.timestampStyle,
    this.showMenu = true,
    this.menuIcon,
    this.menuIconColor,
    this.closeButton,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePadding = padding ??
        const EdgeInsets.all(DesignTokens.spaceMD - DesignTokens.spaceXS);
    final effectiveAvatarRadius = avatarRadius ?? DesignTokens.avatarSize / 2;

    return Padding(
      padding: effectivePadding,
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: onAvatarTap,
            child: CircleAvatar(
              radius: effectiveAvatarRadius,
              backgroundColor: avatarBackgroundColor ??
                  theme.colorScheme.surfaceContainerHighest,
              backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                  ? CachedNetworkImageProvider(avatarUrl!)
                  : null,
              child: (avatarUrl == null || avatarUrl!.isEmpty)
                  ? Icon(
                      Icons.person,
                      size: DesignTokens.iconMD,
                      color: theme.colorScheme.onSurface.withOpacity(
                        DesignTokens.opacityMedium,
                      ),
                    )
                  : null,
            ),
          ),
          SizedBox(width: DesignTokens.spaceMD - DesignTokens.spaceXS),

          // Author info + badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username row with verified badge and display type badge
                Row(
                  children: [
                    // Name with verified badge - flexible to respect text length
                    Flexible(
                      child: GestureDetector(
                        onTap: onUsernameTap ?? onAvatarTap,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                username,
                                style: usernameStyle ??
                                    theme.textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            // Verified badge right after the name
                            if (isVerified) ...[
                              const SizedBox(width: DesignTokens.spaceXS),
                              const SonarVerifiedBadge(),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Display type badge - flexible but can shrink
                    if (badge != null) ...[
                      const SizedBox(width: DesignTokens.spaceXS),
                      Flexible(child: badge!),
                    ],
                  ],
                ),
                // Location or timestamp
                if (timestamp != null || location != null)
                  Row(
                    children: [
                      if (location != null) ...[
                        Icon(
                          Icons.location_on,
                          size: DesignTokens.iconSM,
                          color: theme.colorScheme.onSurface.withOpacity(
                            DesignTokens.opacityMedium,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceXS),
                        Expanded(
                          child: Text(
                            location!,
                            style: timestampStyle ??
                                theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(DesignTokens.opacityMedium),
                                ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceSM),
                        Text(
                          '•',
                          style: timestampStyle ??
                              theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  DesignTokens.opacityMedium,
                                ),
                              ),
                        ),
                        const SizedBox(width: DesignTokens.spaceSM),
                      ],
                      if (timestamp != null)
                        Expanded(
                          child: Text(
                            _formatTimestamp(timestamp!),
                            style: timestampStyle ??
                                theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(DesignTokens.opacityMedium),
                                ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      if (isEdited)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: DesignTokens.spaceXS,
                          ),
                          child: Text(
                            '(Edited)',
                            style: timestampStyle ??
                                theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(DesignTokens.opacityMedium),
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),

          // Action button (e.g., Boost/Insights)
          if (actionButton != null) ...[
            actionButton!,
            const SizedBox(width: DesignTokens.spaceXS),
          ],

          // More options menu
          if (showMenu && menuItems != null && menuItems!.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(
                menuIcon ?? Icons.more_vert,
                size: DesignTokens.iconMD,
                color: menuIconColor ?? theme.iconTheme.color,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onSelected: onMenuSelected,
              itemBuilder: (context) => menuItems!,
            ),
          
          // Close button (if provided)
          if (closeButton != null) closeButton!,
        ],
      ),
    );
  }

  /// Formats timestamp to a human-readable string
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      // More than a week ago - show date
      return DateFormat('MMM d, y').format(timestamp);
    } else if (difference.inDays > 0) {
      // Days ago
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      // Hours ago
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      // Minutes ago
      return '${difference.inMinutes}m';
    } else {
      // Just now
      return 'Just now';
    }
  }
}

