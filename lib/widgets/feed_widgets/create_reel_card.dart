// lib/widgets/feed_widgets/create_reel_card.dart
// Create Reel Card - Similar to Create Story Card for reels

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/reel_upload/reel_upload_bloc.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/utils/image_url_validator.dart';
import 'package:freegram/navigation/app_routes.dart';

/// Create Reel Card - Always first in the trending reels carousel
class CreateReelCard extends StatelessWidget {
  final String? photoUrl;
  final VoidCallback? onTap;

  const CreateReelCard({
    Key? key,
    this.photoUrl,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profilePicUrl = photoUrl ?? '';

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
              child: Container(
                width: double.infinity,
                color: theme.colorScheme.surfaceContainerHighest,
                child: ImageUrlValidator.isValidUrl(profilePicUrl)
                    ? CachedNetworkImage(
                        imageUrl: profilePicUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            _buildPlaceholder(theme),
                        placeholder: (context, url) => _buildPlaceholder(theme),
                      )
                    : _buildPlaceholder(theme),
              ),
            ),
            // State-aware Circular Button with percentage and text
            Positioned(
              bottom: DesignTokens.spaceMD,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BlocBuilder<ReelUploadBloc, ReelUploadState>(
                    builder: (context, uploadState) {
                      return _buildStateAwareButton(
                        context,
                        uploadState,
                        onTap ??
                            () {
                              Navigator.pushNamed(
                                  context, AppRoutes.createReel);
                            },
                      );
                    },
                  ),
                  const SizedBox(height: DesignTokens.spaceXS),
                  BlocBuilder<ReelUploadBloc, ReelUploadState>(
                    builder: (context, uploadState) {
                      return _buildStatusText(context, uploadState);
                    },
                  ),
                ],
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

  /// Build state-aware circular button
  Widget _buildStateAwareButton(
    BuildContext context,
    ReelUploadState state,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    const buttonRadius = DesignTokens.iconLG;

    if (state is ReelUploadInProgress) {
      // Uploading: Show percentage in center with progress ring
      final progress = state.progress.clamp(0.0, 1.0);
      final percentage = (progress * 100).toInt();

      return RepaintBoundary(
        child: GestureDetector(
          onTap: null, // Disabled during upload
          child: SizedBox(
            width: buttonRadius * 2,
            height: buttonRadius * 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Progress ring
                SizedBox(
                  width: buttonRadius * 2,
                  height: buttonRadius * 2,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      SonarPulseTheme.primaryAccent,
                    ),
                  ),
                ),
                // Percentage text in center
                Container(
                  width: buttonRadius * 2,
                  height: buttonRadius * 2,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: SonarPulseTheme.primaryAccent,
                  ),
                  child: Center(
                    child: Text(
                      '$percentage%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: DesignTokens.fontSizeSM,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (state is ReelUploadSuccess) {
      // Success: Show checkmark
      return RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: AnimationTokens.normal,
          curve: AnimationTokens.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                width: buttonRadius * 2,
                height: buttonRadius * 2,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: SemanticColors.success,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: DesignTokens.iconMD,
                ),
              ),
            );
          },
        ),
      );
    } else if (state is ReelUploadFailed) {
      // Failed: Show retry icon
      return RepaintBoundary(
        child: GestureDetector(
          onTap: () {
            context.read<ReelUploadBloc>().add(
                  RetryUpload(uploadId: state.uploadId),
                );
          },
          child: Container(
            width: buttonRadius * 2,
            height: buttonRadius * 2,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: SemanticColors.warning,
            ),
            child: const Icon(
              Icons.refresh,
              color: Colors.white,
              size: DesignTokens.iconMD,
            ),
          ),
        ),
      );
    } else {
      // Idle: Show plus icon
      return RepaintBoundary(
        child: GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: buttonRadius,
            backgroundColor: theme.colorScheme.primary,
            child: Icon(
              Icons.add,
              color: theme.colorScheme.onPrimary,
              size: DesignTokens.iconMD,
            ),
          ),
        ),
      );
    }
  }

  /// Build status text under the button
  Widget _buildStatusText(BuildContext context, ReelUploadState state) {
    final theme = Theme.of(context);

    if (state is ReelUploadInProgress) {
      final statusText = state.statusText ?? 'Uploading...';
      return Text(
        statusText,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontSize: DesignTokens.fontSizeXS,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else if (state is ReelUploadSuccess) {
      return Text(
        'Uploaded',
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontSize: DesignTokens.fontSizeXS,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      );
    } else if (state is ReelUploadFailed) {
      return Text(
        'Tap to retry',
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontSize: DesignTokens.fontSizeXS,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
