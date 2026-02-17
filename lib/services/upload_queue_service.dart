// lib/services/upload_queue_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing upload queue (for resuming uploads after app restart)
class UploadQueueService {
  static final UploadQueueService _instance = UploadQueueService._internal();
  factory UploadQueueService() => _instance;
  UploadQueueService._internal();

  static const String _queueKey = 'story_upload_queue';

  /// Add upload to queue
  Future<void> addToQueue({
    required String uploadId,
    required Map<String, dynamic> uploadData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);

      Map<String, dynamic> queue = {};
      if (queueJson != null) {
        queue = jsonDecode(queueJson) as Map<String, dynamic>;
      }

      queue[uploadId] = uploadData;

      await prefs.setString(_queueKey, jsonEncode(queue));
      debugPrint('UploadQueueService: Added upload $uploadId to queue');
    } catch (e) {
      debugPrint('UploadQueueService: Error adding to queue: $e');
    }
  }

  /// Remove upload from queue
  Future<void> removeFromQueue(String uploadId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);

      if (queueJson == null) return;

      final queue = jsonDecode(queueJson) as Map<String, dynamic>;
      queue.remove(uploadId);

      await prefs.setString(_queueKey, jsonEncode(queue));
      debugPrint('UploadQueueService: Removed upload $uploadId from queue');
    } catch (e) {
      debugPrint('UploadQueueService: Error removing from queue: $e');
    }
  }

  /// Get all queued uploads
  Future<Map<String, dynamic>> getQueuedUploads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);

      if (queueJson == null) return {};

      return jsonDecode(queueJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('UploadQueueService: Error getting queue: $e');
      return {};
    }
  }

  /// Get all queued uploads as a list
  Future<List<Map<String, dynamic>>> getQueueList() async {
    final queue = await getQueuedUploads();
    return queue.entries.map((e) {
      final data = Map<String, dynamic>.from(e.value);
      data['uploadId'] = e.key;
      return data;
    }).toList();
  }

  /// Check if an upload is in the queue
  Future<bool> isInQueue(String uploadId) async {
    final queue = await getQueuedUploads();
    return queue.containsKey(uploadId);
  }

  /// Clear upload queue
  Future<void> clearQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
      debugPrint('UploadQueueService: Cleared upload queue');
    } catch (e) {
      debugPrint('UploadQueueService: Error clearing queue: $e');
    }
  }
}
