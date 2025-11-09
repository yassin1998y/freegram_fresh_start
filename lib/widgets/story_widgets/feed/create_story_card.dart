// lib/widgets/story_widgets/feed/create_story_card.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/story_widgets/shared/story_upload_border.dart';
import 'package:freegram/services/upload_progress_service.dart';
import 'package:freegram/models/upload_progress_model.dart';
import 'package:freegram/utils/image_url_validator.dart';

/// Create Story Card with integrated upload progress border
/// Shows user's profile picture with "Create a story" button
/// Displays animated upload border when story is being uploaded
class CreateStoryCard extends StatelessWidget {
  final User? user;
  final VoidCallback onTap;

  const CreateStoryCard({
    Key? key,
    required this.user,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profilePicUrl = user?.photoURL ?? '';
    final uploadProgressService = UploadProgressService();

    return Padding(
      padding: const EdgeInsets.only(left: DesignTokens.spaceMD),
      child: SizedBox(
        width: 110,
        height: 160,
        child: ListenableBuilder(
          listenable: uploadProgressService,
          builder: (context, _) {
            // Check for active story uploads
            final activeUploads = uploadProgressService.uploads.values
                .where((u) =>
                    u.state != UploadState.completed &&
                    u.state != UploadState.failed)
                .toList();

            final hasActiveUpload = activeUploads.isNotEmpty;
            final uploadProgress = hasActiveUpload ? activeUploads.first : null;

            // Wrap card with upload border if uploading
            Widget card = _buildCard(context, theme, profilePicUrl);

            if (hasActiveUpload && uploadProgress != null) {
              card = StoryUploadBorder(
                progress: uploadProgress.progress,
                isUploading: true,
                borderWidth: 4.0,
                showPulse: true,
                child: card,
              );
            }

            return card;
          },
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, ThemeData theme, String profilePicUrl) {
    return RepaintBoundary(
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        ),
        elevation: 0,
        color: theme.cardTheme.color,
        child: Column(
          children: [
            // Top 70% - Profile Picture
            Expanded(
              flex: 7,
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
            // Bottom 30% - Text Area
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: theme.colorScheme.surface,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Text
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spaceXS,
                        vertical: DesignTokens.spaceSM,
                      ),
                      child: Text(
                        'Create a story',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: DesignTokens.fontSizeSM,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Add Button (Positioned at seam)
                    Positioned(
                      bottom: -DesignTokens.iconLG,
                      child: GestureDetector(
                        onTap: onTap,
                        child: Container(
                          width: DesignTokens.iconXXL,
                          height: DesignTokens.iconXXL,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: SonarPulseTheme.primaryAccent,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: DesignTokens.elevation2,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.add,
                            color: theme.colorScheme.onPrimary,
                            size: DesignTokens.iconLG,
                          ),
                        ),
                      ),
                    ),
                  ],
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
          color: theme.colorScheme.onSurface
              .withValues(alpha: DesignTokens.opacityMedium),
        ),
      ),
    );
  }
}
