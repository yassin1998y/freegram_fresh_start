import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Phase 3.2: Enhanced Skeleton Loader for Feed Posts
///
/// This widget displays a skeleton placeholder that matches the structure
/// of a feed post card, providing visual feedback while content loads.
class FeedPostSkeleton extends StatelessWidget {
  const FeedPostSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.grey[300]!;
    final highlightColor = Colors.grey[100]!;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          ListTile(
            leading: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
              ),
            ),
            title: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Container(
                height: 16,
                width: 100,
                color: Colors.white,
              ),
            ),
            subtitle: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Container(
                height: 12,
                width: 60,
                color: Colors.white,
              ),
            ),
          ),
          // Image skeleton
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: 300, // Or use aspect ratio
              color: Colors.white,
            ),
          ),
          // Caption/Actions skeleton
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Container(
                height: 14,
                width: 200,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

