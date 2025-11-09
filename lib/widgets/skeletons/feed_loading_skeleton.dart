// lib/widgets/skeletons/feed_loading_skeleton.dart
// Comprehensive feed skeleton that matches the actual feed structure

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Enhanced feed loading skeleton that accurately reflects the feed structure:
/// - Stories tray (horizontal)
/// - Create Post widget
/// - Trending Posts (horizontal)
/// - Trending Reels (horizontal)
/// - Friend/Page Suggestions (horizontal)
/// - Regular posts
class FeedLoadingSkeleton extends StatelessWidget {
  const FeedLoadingSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.dark
        ? Colors.grey[800]!
        : Colors.grey[300]!;
    final highlightColor = theme.brightness == Brightness.dark
        ? Colors.grey[700]!
        : Colors.grey[100]!;

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // 1. Stories Tray Skeleton (horizontal, height 160)
        _buildStoriesTraySkeleton(context, baseColor, highlightColor),
        
        // 2. Create Post Widget Skeleton
        _buildCreatePostSkeleton(context, baseColor, highlightColor),
        
        // 3. Trending Posts Section Skeleton (horizontal)
        _buildTrendingPostsSkeleton(context, baseColor, highlightColor),
        
        // 4. Trending Reels Section Skeleton (horizontal)
        _buildTrendingReelsSkeleton(context, baseColor, highlightColor),
        
        // 5. Friend Suggestions Skeleton (horizontal)
        _buildSuggestionsSkeleton(context, baseColor, highlightColor, 'People You May Know'),
        
        // 6. Regular Posts Skeleton (3-4 posts)
        ...List.generate(4, (index) => _buildPostSkeleton(context, baseColor, highlightColor)),
      ],
    );
  }

  /// Stories tray skeleton - horizontal scrollable circles
  Widget _buildStoriesTraySkeleton(BuildContext context, Color baseColor, Color highlightColor) {
    return Container(
      height: 160,
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSM),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
          itemCount: 6,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(
                right: DesignTokens.spaceSM,
              ),
              child: Column(
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceXS),
                  Container(
                    width: 70,
                    height: 10,
                    color: Colors.white,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Create Post widget skeleton
  Widget _buildCreatePostSkeleton(BuildContext context, Color baseColor, Color highlightColor) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceSM,
        vertical: DesignTokens.spaceXS,
      ),
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        border: Border.all(
          color: theme.dividerColor,
          width: 1,
        ),
      ),
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
            const SizedBox(width: DesignTokens.spaceMD),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
                ),
              ),
            ),
            const SizedBox(width: DesignTokens.spaceSM),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Trending Posts section skeleton - horizontal scrollable cards
  Widget _buildTrendingPostsSkeleton(BuildContext context, Color baseColor, Color highlightColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                Container(
                  width: 100,
                  height: 16,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 60,
                  height: 12,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            period: const Duration(milliseconds: 1200),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
              itemCount: 4,
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
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.spaceSM),
      ],
    );
  }

  /// Trending Reels section skeleton - horizontal scrollable cards
  Widget _buildTrendingReelsSkeleton(BuildContext context, Color baseColor, Color highlightColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            period: const Duration(milliseconds: 1200),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: DesignTokens.spaceMD,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 140,
                        height: 180,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.spaceSM),
      ],
    );
  }

  /// Suggestions skeleton - horizontal scrollable avatar cards
  Widget _buildSuggestionsSkeleton(
    BuildContext context,
    Color baseColor,
    Color highlightColor,
    String title,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: baseColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            period: const Duration(milliseconds: 1200),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: DesignTokens.spaceMD,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: baseColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceXS),
                      Container(
                        width: 70,
                        height: 10,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceXS),
                      Container(
                        width: 60,
                        height: 8,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.spaceMD),
      ],
    );
  }

  /// Regular post skeleton - full post card
  Widget _buildPostSkeleton(BuildContext context, Color baseColor, Color highlightColor) {
    final theme = Theme.of(context);
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
          // Header
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
                            borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spaceXS),
                        Container(
                          width: 80,
                          height: 12,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
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
                      borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Image
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            period: const Duration(milliseconds: 1200),
            child: Container(
              height: 400,
              width: double.infinity,
              color: baseColor,
            ),
          ),
          // Actions
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
          // Caption
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMD,
              vertical: DesignTokens.spaceXS,
            ),
            child: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              period: const Duration(milliseconds: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceXS),
                  Container(
                    width: 200,
                    height: 12,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceSM),
        ],
      ),
    );
  }
}

