// lib/widgets/skeletons/profile_skeleton.dart
// Shimmer skeleton for profile screen loading state

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

/// Shimmer skeleton that mimics the profile header and grid layout
/// Used while profile data is loading
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Glassmorphic Colors
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);

    final glassDecoration = BoxDecoration(
      color: theme.colorScheme.surface.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
      border: Border.all(
        color: theme.dividerColor.withValues(alpha: 0.1),
        width: 1.0,
      ),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 320.0,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient Background Skeleton
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            SonarPulseTheme.primaryAccent
                                .withValues(alpha: 0.05),
                            theme.scaffoldBackgroundColor,
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 40),
                          // Avatar Circle
                          Container(
                            width: 100, // AvatarSize.extraLarge approx
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: SonarPulseTheme.primaryAccent
                                    .withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Name
                          Container(
                            width: 150,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusSM),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Level Bar
                          Container(
                            width: 200,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusXS),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Location
                          Container(
                            width: 100,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusSM),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Stats Row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceLG),
                child: Container(
                  height: 80,
                  decoration: glassDecoration,
                ),
              ),
            ),

            const SliverPadding(
                padding: EdgeInsets.only(top: DesignTokens.spaceXL)),

            // Tabs
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceLG),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                          height: 40,
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    Expanded(
                      child: Container(
                          height: 40,
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                  ],
                ),
              ),
            ),

            // Grid
            SliverPadding(
              padding: const EdgeInsets.all(DesignTokens.spaceSM),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                    );
                  },
                  childCount: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
