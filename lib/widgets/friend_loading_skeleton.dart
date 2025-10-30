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
    return ListView.separated(
      padding: EdgeInsets.all(DesignTokens.spaceMD),
      itemCount: widget.itemCount,
      separatorBuilder: (context, index) =>
          SizedBox(height: DesignTokens.spaceSM),
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.all(DesignTokens.spaceMD),
              child: Row(
                children: [
                  // Avatar skeleton
                  _buildShimmer(
                    context,
                    child: const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey,
                    ),
                  ),
                  SizedBox(width: DesignTokens.spaceMD),
                  // Text skeletons
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildShimmer(
                          context,
                          child: Container(
                            height: 16,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        SizedBox(height: DesignTokens.spaceXS),
                        _buildShimmer(
                          context,
                          child: Container(
                            height: 12,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
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

  Widget _buildShimmer(BuildContext context, {required Widget child}) {
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0.0, 0.5, 1.0],
          colors: [
            Colors.grey.shade300,
            Colors.grey.shade100,
            Colors.grey.shade300,
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
