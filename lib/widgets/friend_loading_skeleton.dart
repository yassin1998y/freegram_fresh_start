// lib/widgets/friend_loading_skeleton.dart
// ⭐ UI POLISH: Loading skeleton for better perceived performance

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

class FriendLoadingSkeleton extends StatefulWidget {
  final int itemCount;

  const FriendLoadingSkeleton({
    super.key,
    this.itemCount = 5,
  });

  @override
  State<FriendLoadingSkeleton> createState() => _FriendLoadingSkeletonState();
}

class _FriendLoadingSkeletonState extends State<FriendLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    // Bug #33 fix: Stop animation before disposing
    _controller.stop();
    _controller.dispose();
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

    return ListView.separated(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      itemCount: widget.itemCount,
      separatorBuilder: (context, index) =>
          const SizedBox(height: DesignTokens.spaceSM),
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              child: Row(
                children: [
                  // Avatar skeleton
                  _buildShimmer(
                    context,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    child: CircleAvatar(
                      radius: AvatarSize.medium.radius,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceMD),
                  // Text skeletons
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildShimmer(
                          context,
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                          child: Container(
                            height: 16,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spaceXS),
                        _buildShimmer(
                          context,
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                          child: Container(
                            height: 12,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmer(BuildContext context,
      {required Widget child,
      required Color baseColor,
      required Color highlightColor}) {
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0.0, 0.5, 1.0],
          colors: [
            baseColor,
            highlightColor,
            baseColor,
          ],
          transform: _SlidingGradientTransform(_animation.value),
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}
