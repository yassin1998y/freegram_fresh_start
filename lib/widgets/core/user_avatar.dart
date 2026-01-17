// lib/widgets/core/user_avatar.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/utils/image_url_validator.dart';
import 'package:freegram/services/cloudinary_service.dart';

/// Standardized user avatar widget with memory optimization
///
/// Features:
/// - Memory-optimized image loading (prevents decoding large images for small avatars)
/// - Consistent fallback UI (grey circle with person icon)
/// - Theme-aware styling
/// - Support for different sizes (small, medium, large)
///
/// Usage:
/// ```dart
/// UserAvatar(
///   url: user.photoUrl,
///   size: AvatarSize.medium,
/// )
/// ```
class UserAvatar extends StatelessWidget {
  /// Image URL (can be null for fallback)
  final String? url;

  /// Avatar size (small: 32px, medium: 40px, large: 64px)
  final AvatarSize size;

  /// Optional tap callback
  final VoidCallback? onTap;

  /// Optional border width
  final double? borderWidth;

  /// Optional border color
  final Color? borderColor;

  /// Background color for fallback (defaults to theme surface)
  final Color? backgroundColor;

  /// Icon color for fallback (defaults to theme onSurface with opacity)
  final Color? iconColor;

  const UserAvatar({
    super.key,
    this.url,
    this.size = AvatarSize.medium,
    this.onTap,
    this.borderWidth,
    this.borderColor,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBorderWidth = borderWidth ?? 0.0;
    final effectiveBorderColor = borderColor ?? Colors.transparent;
    final effectiveBackgroundColor =
        backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    final effectiveIconColor = iconColor ??
        theme.colorScheme.onSurface.withOpacity(DesignTokens.opacityMedium);

    // Validate URL
    final isValidUrl =
        url != null && url!.isNotEmpty && ImageUrlValidator.isValidUrl(url!);

    Widget avatarContent = Container(
      width: size.size,
      height: size.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: effectiveBackgroundColor,
      ),
      child: ClipOval(
        child: isValidUrl
            ? CachedNetworkImage(
                imageUrl: CloudinaryService.getOptimizedImageUrl(
                  url!,
                  width: size.size.toInt(), // Optimize to avatar size
                  height: size.size.toInt(),
                  quality:
                      ImageQuality.thumbnail, // Thumbnail quality for avatars
                ),
                // CRITICAL: Memory optimization - decode image at 2x size for retina
                // This prevents decoding a 4000px image for a 40px avatar
                memCacheWidth: size.memCacheWidth,
                memCacheHeight: size.memCacheHeight,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: effectiveBackgroundColor,
                  child: Center(
                    child: SizedBox(
                      width: size.size * 0.3,
                      height: size.size * 0.3,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          effectiveIconColor,
                        ),
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade200,
                  child: Icon(
                    Icons.person,
                    size: size.size * 0.5, // Icon is 50% of avatar size
                    color: Colors.grey.shade400,
                  ),
                ),
              )
            : Icon(
                Icons.person,
                size: size.size * 0.5, // Icon is 50% of avatar size
                color: effectiveIconColor,
              ),
      ),
    );

    // Add border if specified
    if (effectiveBorderWidth > 0) {
      avatarContent = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: effectiveBorderColor,
            width: effectiveBorderWidth,
          ),
        ),
        child: avatarContent,
      );
    }

    // Add tap handler if provided
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarContent,
      );
    }

    return avatarContent;
  }
}

/// Convenience widget for small avatars (32px)
class UserAvatarSmall extends StatelessWidget {
  final String? url;
  final VoidCallback? onTap;
  final double? borderWidth;
  final Color? borderColor;
  final Color? backgroundColor;
  final Color? iconColor;

  const UserAvatarSmall({
    super.key,
    this.url,
    this.onTap,
    this.borderWidth,
    this.borderColor,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      url: url,
      size: AvatarSize.small,
      onTap: onTap,
      borderWidth: borderWidth,
      borderColor: borderColor,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
    );
  }
}

/// Convenience widget for medium avatars (40px)
class UserAvatarMedium extends StatelessWidget {
  final String? url;
  final VoidCallback? onTap;
  final double? borderWidth;
  final Color? borderColor;
  final Color? backgroundColor;
  final Color? iconColor;

  const UserAvatarMedium({
    super.key,
    this.url,
    this.onTap,
    this.borderWidth,
    this.borderColor,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      url: url,
      size: AvatarSize.medium,
      onTap: onTap,
      borderWidth: borderWidth,
      borderColor: borderColor,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
    );
  }
}

/// Convenience widget for large avatars (64px)
class UserAvatarLarge extends StatelessWidget {
  final String? url;
  final VoidCallback? onTap;
  final double? borderWidth;
  final Color? borderColor;
  final Color? backgroundColor;
  final Color? iconColor;

  const UserAvatarLarge({
    super.key,
    this.url,
    this.onTap,
    this.borderWidth,
    this.borderColor,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      url: url,
      size: AvatarSize.large,
      onTap: onTap,
      borderWidth: borderWidth,
      borderColor: borderColor,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
    );
  }
}
