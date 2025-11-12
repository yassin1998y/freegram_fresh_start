// lib/widgets/skeletons/trending_posts_skeleton.dart
// Loading skeleton for Trending Posts Section

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Skeleton loader for Trending Posts Section
/// Matches the structure of _buildTrendingSection
class TrendingPostsSkeleton extends StatelessWidget {
  const TrendingPostsSkeleton({super.key});

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
                  width: 120,
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
        // Trending post cards skeleton
        SizedBox(
          height: 160,
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            period: const Duration(milliseconds: 1200),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: DesignTokens.spaceMD,
                  ),
                  child: Container(
                    width: 220,
                    height: 160,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMD),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
