// lib/models/post_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/media_item_model.dart';
import 'package:freegram/models/enums/post_content_type.dart';

enum PostType {
  text,
  image,
  video,
  mixed,
}

class PostModel extends Equatable {
  final String id;
  final String authorId;
  final String authorUsername;
  final String authorPhotoUrl;
  final String? authorBadgeUrl; // Denormalized equipped badge URL
  // Page fields (if post is created by a page)
  final String? pageId;
  final String? pageName;
  final String? pagePhotoUrl;
  final String? pageBadgeUrl; // Denormalized equipped badge URL for page
  final bool pageIsVerified; // Denormalized verification status
  final String content;
  final List<MediaItem> mediaItems;
  // Legacy fields for backward compatibility (deprecated)
  @Deprecated('Use mediaItems instead')
  final List<String> mediaUrls;
  @Deprecated('Use mediaItems instead')
  final List<String> mediaTypes;
  final PostType postType;
  final DateTime timestamp;
  // Enhanced location with place information
  final GeoPoint? location;
  final String? locationAddress; // Legacy, kept for backward compatibility
  final Map<String, dynamic>?
      locationInfo; // {geopoint: GeoPoint, placeName: String, placeId: String}
  final List<String> hashtags;
  final List<String> mentions;
  final String visibility; // 'public' | 'friends' | 'nearby'
  final int reactionCount;
  final int commentCount;
  final int viewCount;
  final double trendingScore;
  final DateTime lastEngagementTimestamp;
  final bool deleted;
  final DateTime? deletedAt;
  final bool edited;
  final DateTime? editedAt;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Boost fields
  final bool isBoosted;
  final Timestamp? boostEndTime;
  final Map<String, dynamic>? boostTargeting;
  final Map<String, dynamic>? boostStats;
  // Ranking Algorithm fields (Phase 1)
  /// Base content weight based on post type (calculated once on creation)
  /// Video = 1.5, Image = 1.2, Text = 1.0, Link = 1.3, Poll = 1.1, Mixed = 1.4
  final double contentWeight;

  /// Shared post support - if this post is a share, reference original
  final String? sharedFromPostId;

  /// Link preview data for link posts
  final Map<String, dynamic>? linkPreview;

  /// Post type classification (for content weight calculation)
  final PostContentType contentType;

  const PostModel({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    required this.authorPhotoUrl,
    this.authorBadgeUrl,
    this.pageId,
    this.pageName,
    this.pagePhotoUrl,
    this.pageBadgeUrl,
    this.pageIsVerified = false,
    required this.content,
    this.mediaItems = const [],
    @Deprecated('Use mediaItems instead') this.mediaUrls = const [],
    @Deprecated('Use mediaItems instead') this.mediaTypes = const [],
    required this.postType,
    required this.timestamp,
    this.location,
    this.locationAddress,
    this.locationInfo,
    this.hashtags = const [],
    this.mentions = const [],
    this.visibility = 'public',
    this.reactionCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.trendingScore = 0.0,
    required this.lastEngagementTimestamp,
    this.deleted = false,
    this.deletedAt,
    this.edited = false,
    this.editedAt,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.isBoosted = false,
    this.boostEndTime,
    this.boostTargeting,
    this.boostStats,
    this.contentWeight = 1.0,
    this.sharedFromPostId,
    this.linkPreview,
    this.contentType = PostContentType.text,
  });

  factory PostModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PostModel.fromMap(doc.id, data);
  }

  factory PostModel.fromMap(String id, Map<String, dynamic> data) {
    // Parse location (enhanced format or legacy format)
    GeoPoint? location;
    String? locationAddress;
    Map<String, dynamic>? locationInfo;

    if (data['locationInfo'] != null) {
      // Enhanced format with place information
      final locInfo = data['locationInfo'] as Map<String, dynamic>;
      final geopointData = locInfo['geopoint'] as Map<String, dynamic>?;
      if (geopointData != null) {
        location = GeoPoint(
          geopointData['latitude'] as double? ?? 0.0,
          geopointData['longitude'] as double? ?? 0.0,
        );
      }
      locationInfo = locInfo;
      locationAddress = locInfo['placeName'] as String?;
    } else if (data['location'] != null) {
      // Legacy format
      final locData = data['location'] as Map<String, dynamic>;
      location = GeoPoint(
        locData['latitude'] as double? ?? 0.0,
        locData['longitude'] as double? ?? 0.0,
      );
      locationAddress = locData['address'] as String?;
    }

    // Parse timestamps
    final timestamp = _toDateTime(data['timestamp']);
    final lastEngagementTimestamp =
        _toDateTime(data['lastEngagementTimestamp'] ?? data['timestamp']);
    final createdAt = _toDateTime(data['createdAt'] ?? data['timestamp']);
    final updatedAt = _toDateTime(data['updatedAt'] ?? data['timestamp']);
    final deletedAt =
        data['deletedAt'] != null ? _toDateTime(data['deletedAt']) : null;
    final editedAt =
        data['editedAt'] != null ? _toDateTime(data['editedAt']) : null;

    // Parse boost fields
    final isBoosted = data['isBoosted'] ?? false;
    final boostEndTime = data['boostEndTime'] as Timestamp?;
    final boostTargeting = data['boostTargeting'] as Map<String, dynamic>?;
    final boostStats = data['boostStats'] as Map<String, dynamic>?;

    // Parse media items (new format) or fall back to legacy format
    List<MediaItem> mediaItems = [];
    if (data['mediaItems'] != null) {
      final itemsList = data['mediaItems'] as List;
      debugPrint(
          'PostModel.fromMap: Parsing ${itemsList.length} mediaItems from Firestore');

      // Get legacy mediaUrls as fallback
      final legacyMediaUrls = List<String>.from(data['mediaUrls'] ?? []);
      final legacyMediaTypes = List<String>.from(data['mediaTypes'] ?? []);

      for (int i = 0; i < itemsList.length; i++) {
        final itemMap = itemsList[i] as Map<String, dynamic>;
        debugPrint('PostModel.fromMap: mediaItems[$i] raw data: $itemMap');
        var mediaItem = MediaItem.fromMap(itemMap);

        // CRITICAL FIX: If url is empty, fall back to legacy mediaUrls field
        // This handles cases where Firestore might not preserve the url field correctly
        if (mediaItem.url.isEmpty &&
            i < legacyMediaUrls.length &&
            legacyMediaUrls[i].isNotEmpty) {
          debugPrint(
              'PostModel.fromMap: mediaItems[$i] url is empty, using legacy mediaUrls[$i]: ${legacyMediaUrls[i]}');
          mediaItem = mediaItem.copyWith(
            url: legacyMediaUrls[i],
            type: i < legacyMediaTypes.length
                ? legacyMediaTypes[i]
                : mediaItem.type,
          );
        }

        debugPrint(
            'PostModel.fromMap: mediaItems[$i] parsed: ${mediaItem.toMap()}');
        mediaItems.add(mediaItem);
      }
    } else {
      // Legacy format: convert mediaUrls/mediaTypes to mediaItems
      final mediaUrls = List<String>.from(data['mediaUrls'] ?? []);
      final mediaTypes = List<String>.from(data['mediaTypes'] ?? []);
      for (int i = 0; i < mediaUrls.length; i++) {
        mediaItems.add(MediaItem(
          url: mediaUrls[i],
          type: i < mediaTypes.length ? mediaTypes[i] : 'image',
        ));
      }
    }

    // Legacy fields for backward compatibility
    final mediaUrls = mediaItems.map((item) => item.url).toList();
    final mediaTypes = mediaItems.map((item) => item.type).toList();

    // Parse ranking algorithm fields (Phase 1)
    final contentWeight = (data['contentWeight'] ?? 1.0).toDouble();
    final sharedFromPostId = data['sharedFromPostId'] as String?;
    final linkPreview = data['linkPreview'] as Map<String, dynamic>?;
    final contentType = _contentTypeFromString(
      data['contentType'] as String?,
      mediaTypes, // Use mediaTypes to infer if not present
    );

    final hashtags = List<String>.from(data['hashtags'] ?? []);
    final mentions = List<String>.from(data['mentions'] ?? []);

    // Determine post type
    final postTypeStr = data['postType'] ??
        PostModel.determinePostType(mediaTypes).toString().split('.').last;
    final postType = _stringToPostType(postTypeStr);

    return PostModel(
      id: id,
      authorId: data['authorId'] ?? '',
      authorUsername: data['authorUsername'] ?? 'Anonymous',
      authorPhotoUrl: data['authorPhotoUrl'] ?? '',
      authorBadgeUrl: data['authorBadgeUrl'],
      pageId: data['pageId'] as String?,
      pageName: data['pageName'] as String?,
      pagePhotoUrl: data['pagePhotoUrl'] as String?,
      pageBadgeUrl: data['pageBadgeUrl'],
      pageIsVerified: data['pageIsVerified'] ?? false,
      content: data['content'] ?? '',
      mediaItems: mediaItems,
      mediaUrls: mediaUrls,
      mediaTypes: mediaTypes,
      postType: postType,
      timestamp: timestamp,
      location: location,
      locationAddress: locationAddress,
      locationInfo: locationInfo,
      hashtags: hashtags,
      mentions: mentions,
      visibility: data['visibility'] ?? 'public',
      reactionCount: data['reactionCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      trendingScore: (data['trendingScore'] ?? 0.0).toDouble(),
      lastEngagementTimestamp: lastEngagementTimestamp,
      deleted: data['deleted'] ?? false,
      deletedAt: deletedAt,
      edited: data['edited'] ?? false,
      editedAt: editedAt,
      isPinned: data['isPinned'] ?? false,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isBoosted: isBoosted,
      boostEndTime: boostEndTime,
      boostTargeting: boostTargeting,
      boostStats: boostStats,
      contentWeight: contentWeight,
      sharedFromPostId: sharedFromPostId,
      linkPreview: linkPreview,
      contentType: contentType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': id,
      'authorId': authorId,
      'authorUsername': authorUsername,
      'authorPhotoUrl': authorPhotoUrl,
      'authorBadgeUrl': authorBadgeUrl,
      'pageId': pageId,
      'pageName': pageName,
      'pagePhotoUrl': pagePhotoUrl,
      'pageBadgeUrl': pageBadgeUrl,
      'pageIsVerified': pageIsVerified,
      'content': content,
      'mediaItems': mediaItems.map((item) => item.toMap()).toList(),
      // Legacy fields for backward compatibility
      'mediaUrls': mediaItems.map((item) => item.url).toList(),
      'mediaTypes': mediaItems.map((item) => item.type).toList(),
      'postType': postType.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
      'location': location != null
          ? {
              'latitude': location!.latitude,
              'longitude': location!.longitude,
              'address': locationAddress,
            }
          : null,
      'locationInfo': locationInfo,
      'hashtags': hashtags,
      'mentions': mentions,
      'visibility': visibility,
      'reactionCount': reactionCount,
      'commentCount': commentCount,
      'viewCount': viewCount,
      'trendingScore': trendingScore,
      'lastEngagementTimestamp': Timestamp.fromDate(lastEngagementTimestamp),
      'deleted': deleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'edited': edited,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'isPinned': isPinned,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isBoosted': isBoosted,
      'boostEndTime': boostEndTime,
      'boostTargeting': boostTargeting,
      'boostStats': boostStats,
      // Ranking Algorithm fields (Phase 1)
      'contentWeight': contentWeight,
      'sharedFromPostId': sharedFromPostId,
      'linkPreview': linkPreview,
      'contentType': contentType.toString().split('.').last,
    };
  }

  PostModel copyWith({
    String? id,
    String? authorId,
    String? authorUsername,
    String? authorPhotoUrl,
    String? authorBadgeUrl,
    String? pageId,
    String? pageName,
    String? pagePhotoUrl,
    String? pageBadgeUrl,
    bool? pageIsVerified,
    String? content,
    List<MediaItem>? mediaItems,
    @Deprecated('Use mediaItems instead') List<String>? mediaUrls,
    @Deprecated('Use mediaItems instead') List<String>? mediaTypes,
    PostType? postType,
    DateTime? timestamp,
    GeoPoint? location,
    String? locationAddress,
    Map<String, dynamic>? locationInfo,
    List<String>? hashtags,
    List<String>? mentions,
    String? visibility,
    int? reactionCount,
    int? commentCount,
    int? viewCount,
    double? trendingScore,
    DateTime? lastEngagementTimestamp,
    bool? deleted,
    DateTime? deletedAt,
    bool? edited,
    DateTime? editedAt,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isBoosted,
    Timestamp? boostEndTime,
    Map<String, dynamic>? boostTargeting,
    Map<String, dynamic>? boostStats,
    double? contentWeight,
    String? sharedFromPostId,
    Map<String, dynamic>? linkPreview,
    PostContentType? contentType,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorUsername: authorUsername ?? this.authorUsername,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      authorBadgeUrl: authorBadgeUrl ?? this.authorBadgeUrl,
      pageId: pageId ?? this.pageId,
      pageName: pageName ?? this.pageName,
      pagePhotoUrl: pagePhotoUrl ?? this.pagePhotoUrl,
      pageBadgeUrl: pageBadgeUrl ?? this.pageBadgeUrl,
      pageIsVerified: pageIsVerified ?? this.pageIsVerified,
      content: content ?? this.content,
      mediaItems: mediaItems ?? this.mediaItems,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaTypes: mediaTypes ?? this.mediaTypes,
      postType: postType ?? this.postType,
      timestamp: timestamp ?? this.timestamp,
      location: location ?? this.location,
      locationAddress: locationAddress ?? this.locationAddress,
      locationInfo: locationInfo ?? this.locationInfo,
      hashtags: hashtags ?? this.hashtags,
      mentions: mentions ?? this.mentions,
      visibility: visibility ?? this.visibility,
      reactionCount: reactionCount ?? this.reactionCount,
      commentCount: commentCount ?? this.commentCount,
      viewCount: viewCount ?? this.viewCount,
      trendingScore: trendingScore ?? this.trendingScore,
      lastEngagementTimestamp:
          lastEngagementTimestamp ?? this.lastEngagementTimestamp,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      edited: edited ?? this.edited,
      editedAt: editedAt ?? this.editedAt,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isBoosted: isBoosted ?? this.isBoosted,
      boostEndTime: boostEndTime ?? this.boostEndTime,
      boostTargeting: boostTargeting ?? this.boostTargeting,
      boostStats: boostStats ?? this.boostStats,
      contentWeight: contentWeight ?? this.contentWeight,
      sharedFromPostId: sharedFromPostId ?? this.sharedFromPostId,
      linkPreview: linkPreview ?? this.linkPreview,
      contentType: contentType ?? this.contentType,
    );
  }

  static DateTime _toDateTime(dynamic timestamp) {
    if (timestamp == null) {
      debugPrint(
          "PostModel: Null timestamp encountered, using now as fallback");
      return DateTime.now();
    }

    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    }
    if (timestamp is int) {
      if (timestamp > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
    }
    if (timestamp is Map && timestamp.containsKey('_seconds')) {
      return Timestamp(timestamp['_seconds'], timestamp['_nanoseconds'] ?? 0)
          .toDate();
    }
    debugPrint(
        "PostModel WARNING: Unhandled timestamp type: ${timestamp.runtimeType}");
    return DateTime.now();
  }

  static PostType _stringToPostType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'text':
        return PostType.text;
      case 'image':
        return PostType.image;
      case 'video':
        return PostType.video;
      case 'mixed':
        return PostType.mixed;
      default:
        return PostType.text;
    }
  }

  /// Parse PostContentType from string (for Firestore)
  /// Falls back to inferring from mediaTypes if string is null
  static PostContentType _contentTypeFromString(
    String? contentTypeStr,
    List<String> mediaTypes,
  ) {
    if (contentTypeStr != null) {
      switch (contentTypeStr.toLowerCase()) {
        case 'text':
          return PostContentType.text;
        case 'image':
          return PostContentType.image;
        case 'video':
          return PostContentType.video;
        case 'link':
          return PostContentType.link;
        case 'poll':
          return PostContentType.poll;
        case 'mixed':
          return PostContentType.mixed;
        default:
          break;
      }
    }

    // Infer from mediaTypes if not explicitly set
    if (mediaTypes.isEmpty) {
      return PostContentType.text;
    }

    final hasVideo = mediaTypes.any((type) => type == 'video');
    final hasImage = mediaTypes.any((type) => type == 'image');

    if (hasVideo && hasImage) {
      return PostContentType.mixed;
    } else if (hasVideo) {
      return PostContentType.video;
    } else if (hasImage) {
      return PostContentType.image;
    }

    return PostContentType.text;
  }

  // Helper methods for extracting hashtags and mentions (used in repository)
  static List<String> extractHashtags(String content) {
    final regex = RegExp(r'#\w+');
    final matches = regex.allMatches(content);
    return matches.map((match) => match.group(0)!).toList();
  }

  static List<String> extractMentions(String content) {
    final regex = RegExp(r'@(\w+)');
    final matches = regex.allMatches(content);
    return matches.map((match) => match.group(1)!).toList();
  }

  static PostType determinePostType(List<String> mediaTypes) {
    if (mediaTypes.isEmpty) return PostType.text;
    if (mediaTypes.length == 1) {
      if (mediaTypes.first == 'image') return PostType.image;
      if (mediaTypes.first == 'video') return PostType.video;
    }
    return PostType.mixed;
  }

  @override
  List<Object?> get props => [
        id,
        authorId,
        authorUsername,
        authorPhotoUrl,
        authorBadgeUrl,
        pageId,
        pageName,
        pagePhotoUrl,
        pageBadgeUrl,
        pageIsVerified,
        content,
        mediaItems,
        mediaUrls,
        mediaTypes,
        postType,
        timestamp,
        location,
        locationAddress,
        locationInfo,
        hashtags,
        mentions,
        visibility,
        reactionCount,
        commentCount,
        viewCount,
        trendingScore,
        lastEngagementTimestamp,
        deleted,
        deletedAt,
        edited,
        editedAt,
        isPinned,
        createdAt,
        updatedAt,
        isBoosted,
        boostEndTime,
        boostTargeting,
        boostStats,
        contentWeight,
        sharedFromPostId,
        linkPreview,
        contentType,
      ];
}
