// lib/services/draft_persistence_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:freegram/models/text_overlay_model.dart';
import 'package:freegram/models/sticker_overlay_model.dart';
import 'package:freegram/models/drawing_path_model.dart';

/// Draft data model
class ReelDraft {
  final String uploadId;
  final String videoPath;
  final String? caption;
  final List<String> hashtags;
  final List<String> mentions;
  final String error;
  final DateTime createdAt;
  final int retryCount;

  ReelDraft({
    required this.uploadId,
    required this.videoPath,
    this.caption,
    this.hashtags = const [],
    this.mentions = const [],
    required this.error,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'uploadId': uploadId,
        'videoPath': videoPath,
        'caption': caption,
        'hashtags': hashtags,
        'mentions': mentions,
        'error': error,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory ReelDraft.fromJson(Map<String, dynamic> json) => ReelDraft(
        uploadId: json['uploadId'] as String,
        videoPath: json['videoPath'] as String,
        caption: json['caption'] as String?,
        hashtags: List<String>.from(json['hashtags'] as List? ?? []),
        mentions: List<String>.from(json['mentions'] as List? ?? []),
        error: json['error'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
      );
}

/// Service for persisting failed uploads as drafts
/// Uses SharedPreferences for simple key-value storage
class DraftPersistenceService {
  static const String _draftsKey = 'reel_upload_drafts';
  static const String _storyDraftsBox = 'story_drafts';
  static const int _maxRetryCount = 3;

  /// Save a draft
  Future<void> saveDraft({
    required String uploadId,
    required String videoPath,
    String? caption,
    List<String>? hashtags,
    List<String>? mentions,
    required String error,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final drafts = await getAllDrafts();

      final draft = ReelDraft(
        uploadId: uploadId,
        videoPath: videoPath,
        caption: caption,
        hashtags: hashtags ?? [],
        mentions: mentions ?? [],
        error: error,
        createdAt: DateTime.now(),
      );

      // Remove existing draft with same uploadId if any
      drafts.removeWhere((d) => d.uploadId == uploadId);
      drafts.add(draft);

      // Save to SharedPreferences
      final jsonList = drafts.map((d) => d.toJson()).toList();
      await prefs.setString(_draftsKey, jsonEncode(jsonList));

      debugPrint('[DraftPersistenceService] Saved draft: $uploadId');
    } catch (e) {
      debugPrint('[DraftPersistenceService] Error saving draft: $e');
    }
  }

  /// Get a specific draft
  Future<ReelDraft?> getDraft(String uploadId) async {
    final drafts = await getAllDrafts();
    try {
      return drafts.firstWhere((d) => d.uploadId == uploadId);
    } catch (e) {
      return null;
    }
  }

  /// Get all drafts
  Future<List<ReelDraft>> getAllDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_draftsKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((json) => ReelDraft.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DraftPersistenceService] Error loading drafts: $e');
      return [];
    }
  }

  /// Delete a draft
  Future<void> deleteDraft(String uploadId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final drafts = await getAllDrafts();
      drafts.removeWhere((d) => d.uploadId == uploadId);

      final jsonList = drafts.map((d) => d.toJson()).toList();
      await prefs.setString(_draftsKey, jsonEncode(jsonList));

      debugPrint('[DraftPersistenceService] Deleted draft: $uploadId');
    } catch (e) {
      debugPrint('[DraftPersistenceService] Error deleting draft: $e');
    }
  }

  /// Clear all drafts
  Future<void> clearAllDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftsKey);
      debugPrint('[DraftPersistenceService] Cleared all drafts');
    } catch (e) {
      debugPrint('[DraftPersistenceService] Error clearing drafts: $e');
    }
  }

  /// Increment retry count for a draft
  Future<void> incrementRetryCount(String uploadId) async {
    final draft = await getDraft(uploadId);
    if (draft == null) return;

    if (draft.retryCount >= _maxRetryCount) {
      // Max retries reached, delete draft
      await deleteDraft(uploadId);
      return;
    }

    final updatedDraft = ReelDraft(
      uploadId: draft.uploadId,
      videoPath: draft.videoPath,
      caption: draft.caption,
      hashtags: draft.hashtags,
      mentions: draft.mentions,
      error: draft.error,
      createdAt: draft.createdAt,
      retryCount: draft.retryCount + 1,
    );

    // Save updated draft
    final prefs = await SharedPreferences.getInstance();
    final drafts = await getAllDrafts();
    drafts.removeWhere((d) => d.uploadId == uploadId);
    drafts.add(updatedDraft);

    final jsonList = drafts.map((d) => d.toJson()).toList();
    await prefs.setString(_draftsKey, jsonEncode(jsonList));
  }

  // === STORY DRAFTS (Hive-based) ===

  /// Save a story draft
  Future<void> saveStoryDraft({
    required String mediaPath,
    required String mediaType,
    required List<TextOverlay> textOverlays,
    required List<StickerOverlay> stickerOverlays,
    required List<DrawingPath> drawings,
  }) async {
    try {
      final box = Hive.box(_storyDraftsBox);

      final draftData = {
        'mediaPath': mediaPath,
        'mediaType': mediaType,
        'textOverlays': textOverlays.map((t) => t.toMap()).toList(),
        'stickerOverlays': stickerOverlays.map((s) => s.toMap()).toList(),
        // Optimized serialization for drawings
        'drawings': drawings
            .map((d) => {
                  'color': d.color,
                  'strokeWidth': d.strokeWidth,
                  'points': d.toCompressedList(),
                })
            .toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await box.put(mediaPath, jsonEncode(draftData));
      debugPrint('[DraftPersistenceService] Story draft saved for: $mediaPath');
    } catch (e) {
      debugPrint('[DraftPersistenceService] Error saving story draft: $e');
    }
  }

  /// Get a story draft
  Future<Map<String, dynamic>?> getStoryDraft(String mediaPath) async {
    try {
      final box = Hive.box(_storyDraftsBox);
      final jsonString = box.get(mediaPath) as String?;

      if (jsonString == null) return null;

      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[DraftPersistenceService] Error loading story draft: $e');
      return null;
    }
  }

  /// Delete a story draft
  Future<void> deleteStoryDraft(String mediaPath) async {
    try {
      final box = Hive.box(_storyDraftsBox);
      await box.delete(mediaPath);
      debugPrint('[DraftPersistenceService] Story draft deleted: $mediaPath');
    } catch (e) {
      debugPrint('[DraftPersistenceService] Error deleting story draft: $e');
    }
  }
}
