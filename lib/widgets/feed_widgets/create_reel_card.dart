// lib/widgets/feed_widgets/create_reel_card.dart
// Create Reel Card - Similar to Create Story Card for reels

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/utils/image_url_validator.dart';
import 'package:freegram/navigation/app_routes.dart';

/// Create Reel Card - Always first in the trending reels carousel
class CreateReelCard extends StatelessWidget {
  final User? user;
  final VoidCallback? onTap;

  const CreateReelCard({
    Key? key,
    this.user,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = user ?? FirebaseAuth.instance.currentUser;
    final profilePicUrl = currentUser?.photoURL ?? '';

    return Padding(
      padding: const EdgeInsets.only(left: DesignTokens.spaceMD),
      child: SizedBox(
        width: 110,
        child: Stack(
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
              child: Column(
                children: [
                  // Top Half (Image)
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: ImageUrlValidator.isValidUrl(profilePicUrl)
                          ? CachedNetworkImage(
                              imageUrl: profilePicUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  _buildPlaceholder(theme),
                              placeholder: (context, url) =>
                                  _buildPlaceholder(theme),
                            )
                          : _buildPlaceholder(theme),
                    ),
                  ),
                  // Bottom Half (Button)
                  Container(
                    height: 50,
                    color: theme.colorScheme.surface,
                    child: Center(
                      child: Text(
                        'Create a reel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Overlay Button (Positioned at the seam)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: onTap ??
                      () {
                        Navigator.pushNamed(context, AppRoutes.createReel);
                      },
                  child: CircleAvatar(
                    radius: DesignTokens.iconLG,
                    backgroundColor: theme.colorScheme.primary,
                    child: Icon(
                      Icons.add,
                      color: theme.colorScheme.onPrimary,
                      size: DesignTokens.iconMD,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.person,
          size: DesignTokens.iconXL,
          color: theme.colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
    );
  }
}

