// lib/models/story_media_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/text_overlay_model.dart';
import 'package:freegram/models/drawing_path_model.dart';
import 'package:freegram/models/sticker_overlay_model.dart';

class StoryMedia extends Equatable {
  final String storyId;
  final String authorId;
  final String mediaUrl;
  final String mediaType; // 'image' | 'video'
  final String? thumbnailUrl;
  final double? duration; // Video duration in seconds
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
  final bool isActive;

  StoryMedia({
    required this.storyId,
    required this.authorId,
    required this.mediaUrl,
    required this.mediaType,
    this.thumbnailUrl,
    this.duration,
    this.caption,
    this.textOverlays,
    this.drawings,
    this.stickerIds,
    this.stickerOverlays,
    required this.createdAt,
    required this.expiresAt,
    this.viewerCount = 0,
    this.replyCount = 0,
    this.isActive = true,
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
      isActive: data['isActive'] ?? true,
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
      'caption': caption,
      'textOverlays': textOverlays?.map((t) => t.toMap()).toList(),
      'drawings': drawings?.map((d) => d.toMap()).toList(),
      'stickerIds': stickerIds,
      'stickerOverlays': stickerOverlays?.map((s) => s.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewerCount': viewerCount,
      'replyCount': replyCount,
      'isActive': isActive,
    };
  }

  StoryMedia copyWith({
    String? storyId,
    String? authorId,
    String? mediaUrl,
    String? mediaType,
    String? thumbnailUrl,
    double? duration,
    String? caption,
    List<TextOverlay>? textOverlays,
    List<DrawingPath>? drawings,
    List<String>? stickerIds,
    List<StickerOverlay>? stickerOverlays,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? viewerCount,
    int? replyCount,
    bool? isActive,
  }) {
    return StoryMedia(
      storyId: storyId ?? this.storyId,
      authorId: authorId ?? this.authorId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      caption: caption ?? this.caption,
      textOverlays: textOverlays ?? this.textOverlays,
      drawings: drawings ?? this.drawings,
      stickerIds: stickerIds ?? this.stickerIds,
      stickerOverlays: stickerOverlays ?? this.stickerOverlays,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewerCount: viewerCount ?? this.viewerCount,
      replyCount: replyCount ?? this.replyCount,
      isActive: isActive ?? this.isActive,
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

  @override
  List<Object?> get props => [
        storyId,
        authorId,
        mediaUrl,
        mediaType,
        thumbnailUrl,
        duration,
        caption,
        textOverlays,
        drawings,
        stickerIds,
        stickerOverlays,
        createdAt,
        expiresAt,
        viewerCount,
        replyCount,
        isActive,
      ];
}
