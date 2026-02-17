// lib/widgets/reels/optimistic_upload_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/reel_upload/reel_upload_bloc.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Optimistic upload button widget
///
/// Shows different states:
/// - Idle: Standard "Create Reel" button
/// - Uploading: Progress bar with status text
/// - Success: Checkmark animation
/// - Failed: Retry button with warning color
class OptimisticUploadButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const OptimisticUploadButton({
    Key? key,
    this.onTap,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReelUploadBloc, ReelUploadState>(
      builder: (context, state) {
        if (state is ReelUploadInProgress) {
          return _buildUploadingState(context, state);
        } else if (state is ReelUploadSuccess) {
          return _buildSuccessState(context, state);
        } else if (state is ReelUploadFailed) {
          return _buildFailedState(context, state);
        } else {
          return _buildIdleState(context);
        }
      },
    );
  }

  /// Idle state: Standard button
  Widget _buildIdleState(BuildContext context) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: SizedBox(
        width: width ?? double.infinity,
        height: height ?? DesignTokens.buttonHeight,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: SonarPulseTheme.primaryAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMD,
              vertical: DesignTokens.spaceSM,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_circle_outline,
                size: DesignTokens.iconMD,
              ),
              const SizedBox(width: DesignTokens.spaceXS),
              Text(
                'Create Reel',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Uploading state: Progress bar with status
  Widget _buildUploadingState(
    BuildContext context,
    ReelUploadInProgress state,
  ) {
    final theme = Theme.of(context);
    final progress = state.progress.clamp(0.0, 1.0);
    final statusText = state.statusText ?? 'Uploading...';
    final percentage = (progress * 100).toInt();

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: AnimationTokens.normal,
        curve: AnimationTokens.easeOutCubic,
        width: width ?? double.infinity,
        height: height ?? DesignTokens.buttonHeight,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 1.0, // 1px design system
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          child: Stack(
            children: [
              // Progress Fill (using same style as AchievementProgressBar)
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: AnimationTokens.normal,
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * progress,
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      color: SonarPulseTheme.primaryAccent,
                      gradient: LinearGradient(
                        colors: [
                          SonarPulseTheme.primaryAccent,
                          SonarPulseTheme.primaryAccent.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        if (progress > 0)
                          BoxShadow(
                            color: SonarPulseTheme.primaryAccent
                                .withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                  );
                },
              ),
              // Content overlay
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMD,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '$statusText $percentage%',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: progress > 0.5
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  /// Success state: Checkmark animation
  Widget _buildSuccessState(
    BuildContext context,
    ReelUploadSuccess state,
  ) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: AnimationTokens.normal,
        curve: AnimationTokens.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: AnimatedContainer(
              duration: AnimationTokens.normal,
              width: width ?? double.infinity,
              height: height ?? DesignTokens.buttonHeight,
              decoration: BoxDecoration(
                color: SemanticColors.success,
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: DesignTokens.iconMD,
                    ),
                    const SizedBox(width: DesignTokens.spaceXS),
                    Text(
                      'Uploaded',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Failed state: Retry button
  Widget _buildFailedState(
    BuildContext context,
    ReelUploadFailed state,
  ) {
    final theme = Theme.of(context);
    final bloc = context.read<ReelUploadBloc>();

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: AnimationTokens.normal,
        width: width ?? double.infinity,
        height: height ?? DesignTokens.buttonHeight,
        child: ElevatedButton(
          onPressed: state.canRetry
              ? () {
                  bloc.add(RetryUpload(uploadId: state.uploadId));
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: SemanticColors.warning,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMD,
              vertical: DesignTokens.spaceSM,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: DesignTokens.iconMD,
              ),
              const SizedBox(width: DesignTokens.spaceXS),
              Text(
                'Retry Upload',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
