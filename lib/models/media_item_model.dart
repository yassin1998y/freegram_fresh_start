// lib/models/media_item_model.dart

import 'package:freegram/services/network_quality_service.dart';

class MediaItem {
  final String url;
  final String? caption;
  final String type; // 'image' or 'video'

  // Video-specific fields (multi-quality support, like ReelModel)
  final String? thumbnailUrl; // Thumbnail URL for video
  final String? videoUrl360p; // Low quality (360p)
  final String? videoUrl720p; // Medium quality (720p)
  final String? videoUrl1080p; // High quality (1080p)

  MediaItem({
    required this.url,
    this.caption,
    required this.type,
    this.thumbnailUrl,
    this.videoUrl360p,
    this.videoUrl720p,
    this.videoUrl1080p,
  });

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    // Handle both string and dynamic types for URL fields
    String? parseUrl(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        return value.isEmpty ? null : value;
      }
      return value.toString().isEmpty ? null : value.toString();
    }

    final url = parseUrl(map['url']) ?? '';
    final thumbnailUrl = parseUrl(map['thumbnailUrl']);
    final videoUrl360p = parseUrl(map['videoUrl360p']);
    final videoUrl720p = parseUrl(map['videoUrl720p']);
    final videoUrl1080p = parseUrl(map['videoUrl1080p']);

    return MediaItem(
      url: url,
      caption: map['caption'] as String?,
      type: map['type']?.toString() ?? 'image',
      thumbnailUrl: thumbnailUrl,
      videoUrl360p: videoUrl360p,
      videoUrl720p: videoUrl720p,
      videoUrl1080p: videoUrl1080p,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'caption': caption,
      'type': type,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (videoUrl360p != null) 'videoUrl360p': videoUrl360p,
      if (videoUrl720p != null) 'videoUrl720p': videoUrl720p,
      if (videoUrl1080p != null) 'videoUrl1080p': videoUrl1080p,
    };
  }

  MediaItem copyWith({
    String? url,
    String? caption,
    String? type,
    String? thumbnailUrl,
    String? videoUrl360p,
    String? videoUrl720p,
    String? videoUrl1080p,
  }) {
    return MediaItem(
      url: url ?? this.url,
      caption: caption ?? this.caption,
      type: type ?? this.type,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoUrl360p: videoUrl360p ?? this.videoUrl360p,
      videoUrl720p: videoUrl720p ?? this.videoUrl720p,
      videoUrl1080p: videoUrl1080p ?? this.videoUrl1080p,
    );
  }

  /// Gets the best video URL based on the current network quality.
  /// Similar to ReelModel.getVideoUrlForQuality()
  /// Returns the highest quality URL available for the given network quality.
  String getVideoUrlForQuality(NetworkQuality quality) {
    if (type != 'video') {
      return url; // For images, just return the URL
    }

    switch (quality) {
      case NetworkQuality.excellent:
        // Excellent network (WiFi): Prefer 1080p, fallback to 720p, then original
        return videoUrl1080p ?? videoUrl720p ?? url;

      case NetworkQuality.good:
        // Good network (4G): Prefer 720p, fallback to 1080p or original
        return videoUrl720p ?? videoUrl1080p ?? url;

      case NetworkQuality.fair:
        // Fair network (3G): Prefer 360p, fallback to 720p or original
        return videoUrl360p ?? videoUrl720p ?? url;

      case NetworkQuality.poor:
        // Poor network (2G): Prefer 360p, fallback to 720p or original
        return videoUrl360p ?? videoUrl720p ?? url;

      case NetworkQuality.offline:
        // Offline: Try to use cached version
        return videoUrl1080p ?? videoUrl720p ?? videoUrl360p ?? url;
    }
  }
}
