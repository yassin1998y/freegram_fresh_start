// lib/models/feed_item_model.dart

import 'package:equatable/equatable.dart';
import 'package:freegram/models/post_model.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Sealed class to represent different types of items in the feed
sealed class FeedItem extends Equatable {
  const FeedItem();

  @override
  List<Object?> get props => [];
}

/// Represents a post in the feed with its display type
class PostFeedItem extends FeedItem {
  final PostModel post;
  final PostDisplayType displayType;

  const PostFeedItem({
    required this.post,
    this.displayType = PostDisplayType.organic,
  });

  @override
  List<Object?> get props => [post, displayType];
}

/// Represents an optimistic "ghost" post that is currently uploading
class GhostPostFeedItem extends FeedItem {
  final String uploadId;
  final String? filePath; // Local path to media
  final String? caption;
  final String mediaType; // 'image' or 'video'
  final DateTime createdAt;
  final double progress;
  final String? statusText;

  const GhostPostFeedItem({
    required this.uploadId,
    this.filePath,
    this.caption,
    required this.mediaType,
    required this.createdAt,
    this.progress = 0.0,
    this.statusText,
  });

  @override
  List<Object?> get props =>
      [uploadId, filePath, caption, mediaType, createdAt, progress, statusText];

  GhostPostFeedItem copyWith({
    String? uploadId,
    String? filePath,
    String? caption,
    String? mediaType,
    DateTime? createdAt,
    double? progress,
    String? statusText,
  }) {
    return GhostPostFeedItem(
      uploadId: uploadId ?? this.uploadId,
      filePath: filePath ?? this.filePath,
      caption: caption ?? this.caption,
      mediaType: mediaType ?? this.mediaType,
      createdAt: createdAt ?? this.createdAt,
      progress: progress ?? this.progress,
      statusText: statusText ?? this.statusText,
    );
  }
}

/// Represents an ad in the feed
/// Note: Using BannerAd from google_mobile_ads instead of AdModel
class AdFeedItem extends FeedItem {
  final BannerAd ad;
  final String cacheKey;

  const AdFeedItem({
    required this.ad,
    required this.cacheKey,
  });

  @override
  List<Object?> get props => [cacheKey];
}

/// Represents a suggestion carousel in the feed (friends or pages)
class SuggestionCarouselFeedItem extends FeedItem {
  final SuggestionType type;
  final List<dynamic> suggestions; // List<UserModel> or List<PageModel>

  const SuggestionCarouselFeedItem({
    required this.type,
    required this.suggestions,
  });

  @override
  List<Object?> get props => [type, suggestions];
}

/// Represents a milestone achievement event in the feed
class MilestoneFeedItem extends FeedItem {
  final String userId;
  final String username;
  final String userPhotoUrl;
  final String achievementName;
  final String? badgeUrl;
  final DateTime timestamp;
  final String
      tier; // Using String to avoid circular dependency or keep it simple

  const MilestoneFeedItem({
    required this.userId,
    required this.username,
    required this.userPhotoUrl,
    required this.achievementName,
    this.badgeUrl,
    required this.timestamp,
    required this.tier,
  });

  @override
  List<Object?> get props => [userId, achievementName, timestamp];
}

/// Enum for post display types
enum PostDisplayType {
  organic,
  boosted,
  trending,
  nearby,
  page,
}

/// Enum for suggestion types
enum SuggestionType {
  friends,
  pages,
}
