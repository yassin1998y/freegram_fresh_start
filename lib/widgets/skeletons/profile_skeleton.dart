// lib/widgets/skeletons/profile_skeleton.dart
// Shimmer skeleton for profile screen loading state

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Shimmer skeleton that mimics the profile header and grid layout
/// Used while profile data is loading
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.dark
        ? SemanticColors.gray800(context)
        : SemanticColors.gray300(context);
    final highlightColor = theme.brightness == Brightness.dark
        ? SemanticColors.gray600(context)
        : SemanticColors.gray200(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return CustomScrollView(
      slivers: [
        // Profile Header Skeleton
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(DesignTokens.spaceMD),
            child: Column(
              children: [
                // Profile Photo and Stats Row
                Row(
                  children: [
                    // Profile Photo
                    Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceXL),
                    // Stats
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatSkeleton(baseColor, highlightColor),
                          _buildStatSkeleton(baseColor, highlightColor),
                          _buildStatSkeleton(baseColor, highlightColor),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.spaceMD),
                // Username and Bio
                Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 150,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceSM),
                      Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceXS),
                      Container(
                        width: screenWidth * 0.7,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceLG),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: Shimmer.fromColors(
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusMD),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceSM),
                    Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusMD),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Posts Grid Skeleton
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: DesignTokens.spaceSM,
              mainAxisSpacing: DesignTokens.spaceSM,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusSM),
                    ),
                  ),
                );
              },
              childCount: 9, // Show 9 grid items
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatSkeleton(Color baseColor, Color highlightColor) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: [
          Container(
            width: 30,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXS),
          Container(
            width: 40,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
