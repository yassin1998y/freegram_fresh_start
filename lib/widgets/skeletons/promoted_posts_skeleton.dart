// lib/widgets/skeletons/promoted_posts_skeleton.dart
// Loading skeleton for Promoted/Boosted Posts Section

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Skeleton loader for Promoted/Boosted Posts Section
/// Matches the structure of BoostedPostsSectionWidget
class PromotedPostsSkeleton extends StatelessWidget {
  const PromotedPostsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.dark
        ? SemanticColors.gray800(context)
        : SemanticColors.gray300(context);
    final highlightColor = theme.brightness == Brightness.dark
        ? SemanticColors.gray600(context)
        : SemanticColors.gray200(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header skeleton
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMD,
            vertical: DesignTokens.spaceSM,
          ),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            period: const Duration(milliseconds: 1200),
            child: Row(
              children: [
                Container(
                  width: DesignTokens.iconMD,
                  height: DesignTokens.iconMD,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                Container(
                  width: 100,
                  height: DesignTokens.fontSizeMD,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Promoted post skeletons (show 2-3)
        ...List.generate(2, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceSM,
              vertical: DesignTokens.spaceXS,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              border: Border.all(
                color: theme.dividerColor,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header skeleton
                Padding(
                  padding: const EdgeInsets.all(DesignTokens.spaceMD),
                  child: Shimmer.fromColors(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    period: const Duration(milliseconds: 1200),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: baseColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceSM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 120,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: baseColor,
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusXS),
                                ),
                              ),
                              const SizedBox(height: DesignTokens.spaceXS),
                              Container(
                                width: 80,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: baseColor,
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusXS),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusSM),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Image skeleton
                Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  period: const Duration(milliseconds: 1200),
                  child: Container(
                    height: 300,
                    width: double.infinity,
                    color: baseColor,
                  ),
                ),
                // Actions skeleton
                Padding(
                  padding: const EdgeInsets.all(DesignTokens.spaceSM),
                  child: Shimmer.fromColors(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    period: const Duration(milliseconds: 1200),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: baseColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceMD),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: baseColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceSM),
              ],
            ),
          );
        }),
        const SizedBox(height: DesignTokens.spaceMD),
      ],
    );
  }
}
