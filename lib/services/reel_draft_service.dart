// lib/services/reel_draft_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Model for reel draft
class ReelDraft {
  final String id;
  final String videoPath;
  final String? caption;
  final List<String>? hashtags;
  final List<String>? mentions;
  final DateTime createdAt;

  ReelDraft({
    required this.id,
    required this.videoPath,
    this.caption,
    this.hashtags,
    this.mentions,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoPath': videoPath,
        'caption': caption,
        'hashtags': hashtags,
        'mentions': mentions,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReelDraft.fromJson(Map<String, dynamic> json) => ReelDraft(
        id: json['id'] as String,
        videoPath: json['videoPath'] as String,
        caption: json['caption'] as String?,
        hashtags: (json['hashtags'] as List<dynamic>?)?.cast<String>(),
        mentions: (json['mentions'] as List<dynamic>?)?.cast<String>(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  /// Check if video file still exists
  Future<bool> videoExists() async {
    try {
      final file = File(videoPath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}

/// Service for managing reel drafts
/// Saves drafts locally and manages auto-deletion
class ReelDraftService {
  static const String _draftsKey = 'reel_drafts';
  static const int _maxDrafts = 10;
  static const int _draftExpirationDays = 7;

  /// Save a new draft
  Future<String> saveDraft({
    required String videoPath,
    String? caption,
    List<String>? hashtags,
    List<String>? mentions,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final drafts = await getDrafts();

      // Generate unique ID
      final draftId = DateTime.now().millisecondsSinceEpoch.toString();

      // Create new draft
      final draft = ReelDraft(
        id: draftId,
        videoPath: videoPath,
        caption: caption,
        hashtags: hashtags,
        mentions: mentions,
        createdAt: DateTime.now(),
      );

      // Add to list
      drafts.add(draft);

      // Keep only the most recent drafts
      if (drafts.length > _maxDrafts) {
        // Remove oldest drafts
        drafts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final removed = drafts.sublist(_maxDrafts);
        drafts.removeRange(_maxDrafts, drafts.length);

        // Delete video files of removed drafts
        for (final removedDraft in removed) {
          try {
            final file = File(removedDraft.videoPath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            debugPrint('Error deleting old draft video: $e');
          }
        }
      }

      // Save to preferences
      final draftsJson = drafts.map((d) => d.toJson()).toList();
      await prefs.setString(_draftsKey, jsonEncode(draftsJson));

      debugPrint('Draft saved: $draftId');
      return draftId;
    } catch (e) {
      debugPrint('Error saving draft: $e');
      rethrow;
    }
  }

  /// Get all drafts
  Future<List<ReelDraft>> getDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftsString = prefs.getString(_draftsKey);

      if (draftsString == null) return [];

      final draftsJson = jsonDecode(draftsString) as List<dynamic>;
      final drafts = draftsJson
          .map((json) => ReelDraft.fromJson(json as Map<String, dynamic>))
          .toList();

      // Filter out expired drafts and drafts with missing videos
      final validDrafts = <ReelDraft>[];
      final expiredDrafts = <ReelDraft>[];

      for (final draft in drafts) {
        final age = DateTime.now().difference(draft.createdAt).inDays;
        final videoExists = await draft.videoExists();

        if (age > _draftExpirationDays || !videoExists) {
          expiredDrafts.add(draft);
        } else {
          validDrafts.add(draft);
        }
      }

      // Clean up expired drafts
      if (expiredDrafts.isNotEmpty) {
        await _deleteExpiredDrafts(expiredDrafts);
      }

      return validDrafts;
    } catch (e) {
      debugPrint('Error getting drafts: $e');
      return [];
    }
  }

  /// Get a specific draft by ID
  Future<ReelDraft?> getDraft(String id) async {
    final drafts = await getDrafts();
    try {
      return drafts.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Delete a draft
  Future<void> deleteDraft(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final drafts = await getDrafts();

      // Find and remove draft
      final draftToDelete = drafts.firstWhere((d) => d.id == id);
      drafts.removeWhere((d) => d.id == id);

      // Delete video file
      try {
        final file = File(draftToDelete.videoPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting draft video: $e');
      }

      // Save updated list
      final draftsJson = drafts.map((d) => d.toJson()).toList();
      await prefs.setString(_draftsKey, jsonEncode(draftsJson));

      debugPrint('Draft deleted: $id');
    } catch (e) {
      debugPrint('Error deleting draft: $e');
      rethrow;
    }
  }

  /// Delete all drafts
  Future<void> deleteAllDrafts() async {
    try {
      final drafts = await getDrafts();

      // Delete all video files
      for (final draft in drafts) {
        try {
          final file = File(draft.videoPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting draft video: $e');
        }
      }

      // Clear preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftsKey);

      debugPrint('All drafts deleted');
    } catch (e) {
      debugPrint('Error deleting all drafts: $e');
      rethrow;
    }
  }

  /// Update an existing draft
  Future<void> updateDraft({
    required String id,
    String? caption,
    List<String>? hashtags,
    List<String>? mentions,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final drafts = await getDrafts();

      // Find and update draft
      final index = drafts.indexWhere((d) => d.id == id);
      if (index == -1) {
        throw Exception('Draft not found: $id');
      }

      final oldDraft = drafts[index];
      final updatedDraft = ReelDraft(
        id: oldDraft.id,
        videoPath: oldDraft.videoPath,
        caption: caption ?? oldDraft.caption,
        hashtags: hashtags ?? oldDraft.hashtags,
        mentions: mentions ?? oldDraft.mentions,
        createdAt: oldDraft.createdAt,
      );

      drafts[index] = updatedDraft;

      // Save updated list
      final draftsJson = drafts.map((d) => d.toJson()).toList();
      await prefs.setString(_draftsKey, jsonEncode(draftsJson));

      debugPrint('Draft updated: $id');
    } catch (e) {
      debugPrint('Error updating draft: $e');
      rethrow;
    }
  }

  /// Clean up expired drafts
  Future<void> _deleteExpiredDrafts(List<ReelDraft> expiredDrafts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allDrafts = await getDrafts();

      // Remove expired drafts from list
      allDrafts.removeWhere(
          (draft) => expiredDrafts.any((expired) => expired.id == draft.id));

      // Delete video files
      for (final draft in expiredDrafts) {
        try {
          final file = File(draft.videoPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting expired draft video: $e');
        }
      }

      // Save updated list
      final draftsJson = allDrafts.map((d) => d.toJson()).toList();
      await prefs.setString(_draftsKey, jsonEncode(draftsJson));

      debugPrint('Cleaned up ${expiredDrafts.length} expired drafts');
    } catch (e) {
      debugPrint('Error cleaning up expired drafts: $e');
    }
  }

  /// Get draft count
  Future<int> getDraftCount() async {
    final drafts = await getDrafts();
    return drafts.length;
  }

  /// Check if there are any drafts
  Future<bool> hasDrafts() async {
    final count = await getDraftCount();
    return count > 0;
  }
}
