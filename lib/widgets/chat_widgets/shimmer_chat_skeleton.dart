// lib/widgets/chat_widgets/shimmer_chat_skeleton.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Shimmer skeleton loading for chat list
/// Improvement #15 - Create shimmer skeleton loading for chat list
class ShimmerChatSkeleton extends StatefulWidget {
  const ShimmerChatSkeleton({super.key});

  @override
  State<ShimmerChatSkeleton> createState() => _ShimmerChatSkeletonState();
}

class _ShimmerChatSkeletonState extends State<ShimmerChatSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.dark
        ? SemanticColors.gray800(context)
        : SemanticColors.gray300(context);
    final highlightColor = theme.brightness == Brightness.dark
        ? SemanticColors.gray600(context)
        : SemanticColors.gray200(context);
    final random = Random();

    return ListView.builder(
      itemCount: 10,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: _buildSkeletonItem(random, baseColor, highlightColor),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSkeletonItem(
      Random random, Color baseColor, Color highlightColor) {
    final messageWidth = 100.0 + random.nextDouble() * 150;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMD,
        vertical: DesignTokens.spaceSM,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return _buildShimmerContainer(
                width: 56,
                height: 56,
                radius: 28,
                baseColor: baseColor,
                highlightColor: highlightColor,
              );
            },
          ),

          const SizedBox(width: DesignTokens.spaceMD),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username
                AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return _buildShimmerContainer(
                      width: 120,
                      height: 16,
                      radius: 4,
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                    );
                  },
                ),

                const SizedBox(height: DesignTokens.spaceSM),

                // Message preview
                AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return _buildShimmerContainer(
                      width: messageWidth,
                      height: 14,
                      radius: 4,
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(width: DesignTokens.spaceSM),

          // Time
          AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return _buildShimmerContainer(
                width: 40,
                height: 12,
                radius: 4,
                baseColor: baseColor,
                highlightColor: highlightColor,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerContainer({
    required double width,
    required double height,
    required double radius,
    required Color baseColor,
    required Color highlightColor,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            baseColor,
            highlightColor,
            baseColor,
          ],
          stops: [
            0.0,
            _shimmerAnimation.value.clamp(0.0, 1.0),
            1.0,
          ],
        ),
      ),
    );
  }
}
