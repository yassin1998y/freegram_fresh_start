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
