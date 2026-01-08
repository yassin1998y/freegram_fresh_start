// lib/widgets/skeletons/list_skeleton.dart
// Shimmer skeleton for list loading states (users, chats, friends)

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Shimmer skeleton that mimics a list of items (users/chats/friends)
/// Used while list data is loading
class ListSkeleton extends StatelessWidget {
  final int itemCount;
  final bool showSubtitle;
  final bool showTrailing;

  const ListSkeleton({
    super.key,
    this.itemCount = 5,
    this.showSubtitle = true,
    this.showTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      itemCount: itemCount,
      separatorBuilder: (context, index) =>
          const SizedBox(height: DesignTokens.spaceSM),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
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
            padding: const EdgeInsets.all(DesignTokens.spaceMD),
            child: Row(
              children: [
                // Avatar skeleton
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceMD),
                // Content skeleton
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      if (showSubtitle) ...[
                        const SizedBox(height: DesignTokens.spaceXS),
                        // Subtitle
                        Container(
                          height: 12,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showTrailing) ...[
                  const SizedBox(width: DesignTokens.spaceSM),
                  // Trailing skeleton
                  Container(
                    width: 40,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
