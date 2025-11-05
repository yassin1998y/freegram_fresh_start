// lib/models/post_template_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

class PostTemplateModel extends Equatable {
  final String templateId;
  final String userId;
  final String name;
  final String content;
  final List<String> mediaUrls;
  final List<String> mediaTypes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PostTemplateModel({
    required this.templateId,
    required this.userId,
    required this.name,
    required this.content,
    this.mediaUrls = const [],
    this.mediaTypes = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostTemplateModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PostTemplateModel.fromMap(doc.id, data);
  }

  factory PostTemplateModel.fromMap(String id, Map<String, dynamic> data) {
    final createdAt = _toDateTime(data['createdAt']);
    final updatedAt = _toDateTime(data['updatedAt'] ?? data['createdAt']);

    return PostTemplateModel(
      templateId: id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? 'Untitled Template',
      content: data['content'] ?? '',
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      mediaTypes: List<String>.from(data['mediaTypes'] ?? []),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'templateId': templateId,
      'userId': userId,
      'name': name,
      'content': content,
      'mediaUrls': mediaUrls,
      'mediaTypes': mediaTypes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PostTemplateModel copyWith({
    String? templateId,
    String? userId,
    String? name,
    String? content,
    List<String>? mediaUrls,
    List<String>? mediaTypes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PostTemplateModel(
      templateId: templateId ?? this.templateId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaTypes: mediaTypes ?? this.mediaTypes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime _toDateTime(dynamic timestamp) {
    if (timestamp == null) {
      debugPrint('PostTemplateModel: Null timestamp, using now');
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
        'PostTemplateModel WARNING: Unhandled timestamp type: ${timestamp.runtimeType}');
    return DateTime.now();
  }

  @override
  List<Object?> get props => [
        templateId,
        userId,
        name,
        content,
        mediaUrls,
        mediaTypes,
        createdAt,
        updatedAt,
      ];
}
