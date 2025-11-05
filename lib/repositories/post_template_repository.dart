// lib/repositories/post_template_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/post_template_model.dart';

class PostTemplateRepository {
  final FirebaseFirestore _db;

  PostTemplateRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Create a new post template
  Future<String> createTemplate({
    required String userId,
    required String name,
    required String content,
    List<String>? mediaUrls,
    List<String>? mediaTypes,
  }) async {
    try {
      final templateRef = _db.collection('postTemplates').doc();
      final now = FieldValue.serverTimestamp();

      await templateRef.set({
        'templateId': templateRef.id,
        'userId': userId,
        'name': name,
        'content': content,
        'mediaUrls': mediaUrls ?? [],
        'mediaTypes': mediaTypes ?? [],
        'createdAt': now,
        'updatedAt': now,
      });

      return templateRef.id;
    } catch (e) {
      debugPrint('PostTemplateRepository: Error creating template: $e');
      rethrow;
    }
  }

  /// Get all templates for a user
  Future<List<PostTemplateModel>> getTemplates(String userId) async {
    try {
      final snapshot = await _db
          .collection('postTemplates')
          .where('userId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PostTemplateModel.fromDoc(doc))
          .toList();
    } catch (e) {
      debugPrint('PostTemplateRepository: Error getting templates: $e');
      return [];
    }
  }

  /// Get a single template by ID
  Future<PostTemplateModel?> getTemplate(String templateId) async {
    try {
      final doc = await _db.collection('postTemplates').doc(templateId).get();
      if (!doc.exists) {
        return null;
      }
      return PostTemplateModel.fromDoc(doc);
    } catch (e) {
      debugPrint('PostTemplateRepository: Error getting template: $e');
      rethrow;
    }
  }

  /// Update an existing template
  Future<void> updateTemplate({
    required String templateId,
    required String userId,
    String? name,
    String? content,
    List<String>? mediaUrls,
    List<String>? mediaTypes,
  }) async {
    try {
      // Verify ownership
      final templateDoc =
          await _db.collection('postTemplates').doc(templateId).get();
      if (!templateDoc.exists) {
        throw Exception('Template not found: $templateId');
      }

      final templateData = templateDoc.data()!;
      if (templateData['userId'] != userId) {
        throw Exception('User is not the owner of this template');
      }

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) {
        updateData['name'] = name;
      }
      if (content != null) {
        updateData['content'] = content;
      }
      if (mediaUrls != null) {
        updateData['mediaUrls'] = mediaUrls;
      }
      if (mediaTypes != null) {
        updateData['mediaTypes'] = mediaTypes;
      }

      await _db.collection('postTemplates').doc(templateId).update(updateData);
    } catch (e) {
      debugPrint('PostTemplateRepository: Error updating template: $e');
      rethrow;
    }
  }

  /// Delete a template
  Future<void> deleteTemplate(String templateId, String userId) async {
    try {
      // Verify ownership
      final templateDoc =
          await _db.collection('postTemplates').doc(templateId).get();
      if (!templateDoc.exists) {
        throw Exception('Template not found: $templateId');
      }

      final templateData = templateDoc.data()!;
      if (templateData['userId'] != userId) {
        throw Exception('User is not the owner of this template');
      }

      await _db.collection('postTemplates').doc(templateId).delete();
    } catch (e) {
      debugPrint('PostTemplateRepository: Error deleting template: $e');
      rethrow;
    }
  }
}
