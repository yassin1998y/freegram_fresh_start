// lib/models/story_media_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/text_overlay_model.dart';
import 'package:freegram/models/drawing_path_model.dart';
import 'package:freegram/models/sticker_overlay_model.dart';
import 'package:freegram/services/network_quality_service.dart';

class StoryMedia extends Equatable {
  final String storyId;
  final String authorId;
  final String mediaUrl;
  final String mediaType; // 'image' | 'video'
  final String? thumbnailUrl;
  final double? duration; // Video duration in seconds
  final String? audioUrl; // Audio track URL (optional, for stories with audio)
  // Multi-quality video URLs for ABR (Adaptive Bitrate Streaming) - Phase 2.1
  final String? videoUrl360p; // Low quality (360p)
  final String? videoUrl720p; // Medium quality (720p)
  final String? videoUrl1080p; // High quality (1080p)
  final String? caption;
  final List<TextOverlay>? textOverlays;
  final List<DrawingPath>? drawings;
  final List<String>? stickerIds; // Legacy - kept for backward compatibility
  final List<StickerOverlay>?
      stickerOverlays; // New - with position/scale/rotation
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewerCount;
  final int replyCount;
  final int reactionCount; // Heart reaction count
  final bool isActive;

  const StoryMedia({
    required this.storyId,
    required this.authorId,
    required this.mediaUrl,
    required this.mediaType,
    this.thumbnailUrl,
    this.duration,
    this.audioUrl,
    this.caption,
    this.textOverlays,
    this.drawings,
    this.stickerIds,
    this.stickerOverlays,
    required this.createdAt,
    required this.expiresAt,
    this.viewerCount = 0,
    this.replyCount = 0,
    this.reactionCount = 0,
    this.isActive = true,
    this.videoUrl360p, // Multi-quality URLs (Phase 2.1)
    this.videoUrl720p,
    this.videoUrl1080p,
  });

  factory StoryMedia.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return StoryMedia.fromMap(doc.id, data);
  }

  factory StoryMedia.fromMap(String storyId, Map<String, dynamic> data) {
    final createdAt = _toDateTime(data['createdAt']);
    final expiresAt = _toDateTime(
        data['expiresAt'] ?? DateTime.now().add(const Duration(hours: 24)));

    // Parse text overlays
    List<TextOverlay>? textOverlays;
    if (data['textOverlays'] != null) {
      textOverlays = (data['textOverlays'] as List)
          .map((item) => TextOverlay.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    // Parse drawings
    List<DrawingPath>? drawings;
    if (data['drawings'] != null && data['drawings'] is List) {
      drawings = (data['drawings'] as List)
          .map((item) => DrawingPath.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    // Parse sticker overlays
    List<StickerOverlay>? stickerOverlays;
    if (data['stickerOverlays'] != null && data['stickerOverlays'] is List) {
      stickerOverlays = (data['stickerOverlays'] as List)
          .map((item) => StickerOverlay.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return StoryMedia(
      storyId: storyId,
      authorId: data['authorId'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      mediaType: data['mediaType'] ?? 'image',
      thumbnailUrl: data['thumbnailUrl'],
      duration: data['duration']?.toDouble(),
      audioUrl: data['audioUrl'], // Optional, backward compatible
      caption: data['caption'],
      textOverlays: textOverlays,
      drawings: drawings,
      stickerIds: data['stickerIds'] != null
          ? List<String>.from(data['stickerIds'])
          : null,
      stickerOverlays: stickerOverlays,
      createdAt: createdAt,
      expiresAt: expiresAt,
      viewerCount: data['viewerCount'] ?? 0,
      replyCount: data['replyCount'] ?? 0,
      reactionCount: data['reactionCount'] ?? 0,
      isActive: data['isActive'] ?? true,
      videoUrl360p: data['videoUrl360p'], // Can be null (backward compatible)
      videoUrl720p: data['videoUrl720p'], // Can be null (backward compatible)
      videoUrl1080p: data['videoUrl1080p'], // Can be null (backward compatible)
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storyId': storyId,
      'authorId': authorId,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      if (audioUrl != null) 'audioUrl': audioUrl,
      'caption': caption,
      'textOverlays': textOverlays?.map((t) => t.toMap()).toList(),
      'drawings': drawings?.map((d) => d.toMap()).toList(),
      'stickerIds': stickerIds,
      'stickerOverlays': stickerOverlays?.map((s) => s.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewerCount': viewerCount,
      'replyCount': replyCount,
      'reactionCount': reactionCount,
      'isActive': isActive,
      if (videoUrl360p != null) 'videoUrl360p': videoUrl360p,
      if (videoUrl720p != null) 'videoUrl720p': videoUrl720p,
      if (videoUrl1080p != null) 'videoUrl1080p': videoUrl1080p,
    };
  }

  StoryMedia copyWith({
    String? storyId,
    String? authorId,
    String? mediaUrl,
    String? mediaType,
    String? thumbnailUrl,
    double? duration,
    String? audioUrl,
    String? caption,
    List<TextOverlay>? textOverlays,
    List<DrawingPath>? drawings,
    List<String>? stickerIds,
    List<StickerOverlay>? stickerOverlays,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? viewerCount,
    int? replyCount,
    int? reactionCount,
    bool? isActive,
    String? videoUrl360p,
    String? videoUrl720p,
    String? videoUrl1080p,
  }) {
    return StoryMedia(
      storyId: storyId ?? this.storyId,
      authorId: authorId ?? this.authorId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      audioUrl: audioUrl ?? this.audioUrl,
      caption: caption ?? this.caption,
      textOverlays: textOverlays ?? this.textOverlays,
      drawings: drawings ?? this.drawings,
      stickerIds: stickerIds ?? this.stickerIds,
      stickerOverlays: stickerOverlays ?? this.stickerOverlays,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewerCount: viewerCount ?? this.viewerCount,
      replyCount: replyCount ?? this.replyCount,
      reactionCount: reactionCount ?? this.reactionCount,
      isActive: isActive ?? this.isActive,
      videoUrl360p: videoUrl360p ?? this.videoUrl360p,
      videoUrl720p: videoUrl720p ?? this.videoUrl720p,
      videoUrl1080p: videoUrl1080p ?? this.videoUrl1080p,
    );
  }

  static DateTime _toDateTime(dynamic timestamp) {
    if (timestamp == null) {
      debugPrint(
          'StoryMedia: Null timestamp encountered, using now as fallback');
      return DateTime.now();
    }

    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;

    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    }

    if (timestamp is int) {
      if (timestamp > 1000000000000) {
        // Milliseconds
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        // Seconds
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
    }

    // Handle web-specific LegacyJavaScriptObject (Firestore Timestamp on web)
    // Firestore Timestamp on web is represented as a Map with _seconds and _nanoseconds
    if (timestamp is Map && timestamp.containsKey('_seconds')) {
      try {
        return Timestamp(
          timestamp['_seconds'] as int,
          timestamp['_nanoseconds'] as int? ?? 0,
        ).toDate();
      } catch (e) {
        debugPrint('StoryMedia: Error converting Map timestamp: $e');
        return DateTime.now();
      }
    }

    debugPrint(
        'StoryMedia WARNING: Unhandled timestamp type: ${timestamp.runtimeType}');
    return DateTime.now();
  }

  /// Get video URL based on network quality (ABR - Adaptive Bitrate Streaming).
  ///
  /// This method implements Adaptive Bitrate Streaming (ABR) logic (Phase 2.1).
  /// It is used by the ABR video player and the MediaPrefetchService to select
  /// the appropriate video quality based on network conditions.
  ///
  /// Returns the highest quality URL available for the given network quality,
  /// with fallbacks to ensure a video URL is always returned.
  /// For images, returns the original mediaUrl.
  String getVideoUrlForQuality(NetworkQuality quality) {
    // If not a video, return the original mediaUrl (for images)
    if (mediaType != 'video') {
      return mediaUrl;
    }

    switch (quality) {
      case NetworkQuality.excellent:
        // Excellent network (WiFi): Prefer 1080p, fallback to 720p, then original
        return videoUrl1080p ?? videoUrl720p ?? mediaUrl;

      case NetworkQuality.good:
        // Good network (4G): Prefer 720p, fallback to 1080p or original
        return videoUrl720p ?? videoUrl1080p ?? mediaUrl;

      case NetworkQuality.fair:
        // Fair network (3G): Prefer 360p, fallback to 720p or original
        return videoUrl360p ?? videoUrl720p ?? mediaUrl;

      case NetworkQuality.poor:
        // Poor network (2G): Prefer 360p, fallback to 720p or original
        // For poor networks, we'd rather have *something* than nothing
        return videoUrl360p ?? videoUrl720p ?? mediaUrl;

      case NetworkQuality.offline:
        // Offline: Try to use cached version
        // Give the best-known URL, hoping one is cached
        return videoUrl1080p ?? videoUrl720p ?? videoUrl360p ?? mediaUrl;
    }
  }

  @override
  List<Object?> get props => [
        storyId,
        authorId,
        mediaUrl,
        mediaType,
        thumbnailUrl,
        duration,
        audioUrl,
        caption,
        textOverlays,
        drawings,
        stickerIds,
        stickerOverlays,
        createdAt,
        expiresAt,
        viewerCount,
        replyCount,
        reactionCount,
        isActive,
        videoUrl360p, // Include in equality check
        videoUrl720p, // Include in equality check
        videoUrl1080p, // Include in equality check
      ];
}
