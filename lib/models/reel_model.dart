// lib/models/reel_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/services/network_quality_service.dart';

class ReelModel extends Equatable {
  final String reelId;
  final String uploaderId;
  final String uploaderUsername;
  final String uploaderAvatarUrl;
  final String videoUrl;
  final String thumbnailUrl;

  // Multi-quality video URLs (Phase 2.1 - Adaptive Bitrate Streaming)
  final String? videoUrl360p; // Low quality (360p)
  final String? videoUrl720p; // Medium quality (720p)
  final String? videoUrl1080p; // High quality (1080p)

  final double duration; // in seconds
  final String? caption;
  final List<String> hashtags;
  final List<String> mentions;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int viewCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? audioTrack;

  const ReelModel({
    required this.reelId,
    required this.uploaderId,
    required this.uploaderUsername,
    required this.uploaderAvatarUrl,
    required this.videoUrl,
    required this.thumbnailUrl,
    this.videoUrl360p, // Multi-quality URLs (Phase 2.1)
    this.videoUrl720p,
    this.videoUrl1080p,
    required this.duration,
    this.caption,
    this.hashtags = const [],
    this.mentions = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.viewCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.location,
    this.audioTrack,
  });

  factory ReelModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReelModel.fromMap(doc.id, data);
  }

  factory ReelModel.fromMap(String reelId, Map<String, dynamic> data) {
    return ReelModel(
      reelId: reelId,
      uploaderId: data['uploaderId'] ?? '',
      uploaderUsername: data['uploaderUsername'] ?? 'Unknown',
      uploaderAvatarUrl: data['uploaderAvatarUrl'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      videoUrl360p: data['videoUrl360p'], // Can be null (backward compatible)
      videoUrl720p: data['videoUrl720p'], // Can be null (backward compatible)
      videoUrl1080p: data['videoUrl1080p'], // Can be null (backward compatible)
      duration: (data['duration'] ?? 0).toDouble(),
      caption: data['caption'],
      hashtags: List<String>.from(data['hashtags'] ?? []),
      mentions: List<String>.from(data['mentions'] ?? []),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _toDateTime(data['updatedAt']) ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      location: data['location'] as Map<String, dynamic>?,
      audioTrack: data['audioTrack'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uploaderId': uploaderId,
      'uploaderUsername': uploaderUsername,
      'uploaderAvatarUrl': uploaderAvatarUrl,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      if (videoUrl360p != null) 'videoUrl360p': videoUrl360p,
      if (videoUrl720p != null) 'videoUrl720p': videoUrl720p,
      if (videoUrl1080p != null) 'videoUrl1080p': videoUrl1080p,
      'duration': duration,
      'caption': caption,
      'hashtags': hashtags,
      'mentions': mentions,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'viewCount': viewCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      if (location != null) 'location': location,
      if (audioTrack != null) 'audioTrack': audioTrack,
    };
  }

  /// Gets the best video URL based on the current network quality.
  ///
  /// This method implements Adaptive Bitrate Streaming (ABR) logic (Phase 2.1).
  /// It is used by the ABR video player and the MediaPrefetchService to select
  /// the appropriate video quality based on network conditions.
  ///
  /// Returns the highest quality URL available for the given network quality,
  /// with fallbacks to ensure a video URL is always returned.
  String getVideoUrlForQuality(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
        // Excellent network (WiFi): Prefer 1080p, fallback to 720p, then original
        return videoUrl1080p ?? videoUrl720p ?? videoUrl;

      case NetworkQuality.good:
        // Good network (4G): Prefer 720p, fallback to 1080p or original
        return videoUrl720p ?? videoUrl1080p ?? videoUrl;

      case NetworkQuality.fair:
        // Fair network (3G): Prefer 360p, fallback to 720p or original
        return videoUrl360p ?? videoUrl720p ?? videoUrl;

      case NetworkQuality.poor:
        // Poor network (2G): Prefer 360p, fallback to 720p or original
        // For poor networks, we'd rather have *something* than nothing
        return videoUrl360p ?? videoUrl720p ?? videoUrl;

      case NetworkQuality.offline:
        // Offline: Try to use cached version
        // Give the best-known URL, hoping one is cached
        return videoUrl1080p ?? videoUrl720p ?? videoUrl360p ?? videoUrl;
    }
  }

  static DateTime? _toDateTime(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is int) {
      return timestamp > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    }
    if (timestamp is Map && timestamp.containsKey('_seconds')) {
      try {
        return Timestamp(
          timestamp['_seconds'] as int,
          timestamp['_nanoseconds'] as int? ?? 0,
        ).toDate();
      } catch (e) {
        debugPrint('ReelModel: Error converting Map timestamp: $e');
        return null;
      }
    }
    debugPrint(
        'ReelModel WARNING: Unhandled timestamp type: ${timestamp.runtimeType}');
    return null;
  }

  @override
  List<Object?> get props => [
        reelId,
        uploaderId,
        uploaderUsername,
        uploaderAvatarUrl,
        videoUrl,
        thumbnailUrl,
        videoUrl360p, // Include in equality check
        videoUrl720p, // Include in equality check
        videoUrl1080p, // Include in equality check
        duration,
        caption,
        hashtags,
        mentions,
        likeCount,
        commentCount,
        shareCount,
        viewCount,
        createdAt,
        updatedAt,
        isActive,
        location,
        audioTrack,
      ];
}
