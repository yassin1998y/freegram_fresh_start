// lib/services/draft_persistence_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
