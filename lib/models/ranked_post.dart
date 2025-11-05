// lib/models/ranked_post.dart

import 'package:freegram/models/post_model.dart';

/// Wrapper class for posts with calculated ranking scores
/// Used in client-side ranking algorithm
/// Score = Affinity × Content Weight × Time Decay
class RankedPost {
  final PostModel post;
  final double score;

  RankedPost({
    required this.post,
    required this.score,
  });
}
