// lib/models/comment_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

class CommentModel extends Equatable {
  final String commentId;
  final String postId;
  final String userId;
  final String username;
  final String photoUrl;
  final String text;
  final DateTime timestamp;
  final bool edited;
  final DateTime? editedAt;
  final Map<String, String> reactions; // userId -> reactionType
  final bool deleted;

  CommentModel({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.username,
    required this.photoUrl,
    required this.text,
    required this.timestamp,
    this.edited = false,
    this.editedAt,
    this.reactions = const {},
    this.deleted = false,
  });

  factory CommentModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CommentModel.fromMap(doc.id, data);
  }

  factory CommentModel.fromMap(String commentId, Map<String, dynamic> data) {
    // Parse timestamps
    final timestamp = _toDateTime(data['timestamp']);
    final editedAt =
        data['editedAt'] != null ? _toDateTime(data['editedAt']) : null;

    // Parse reactions map
    final reactions = data['reactions'] != null
        ? Map<String, String>.from(data['reactions'])
        : <String, String>{};

    return CommentModel(
      commentId: commentId,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'Anonymous',
      photoUrl: data['photoUrl'] ?? '',
      text: data['text'] ?? '',
      timestamp: timestamp,
      edited: data['edited'] ?? false,
      editedAt: editedAt,
      reactions: reactions,
      deleted: data['deleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'postId': postId,
      'userId': userId,
      'username': username,
      'photoUrl': photoUrl,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'edited': edited,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'reactions': reactions,
      'deleted': deleted,
    };
  }

  CommentModel copyWith({
    String? commentId,
    String? postId,
    String? userId,
    String? username,
    String? photoUrl,
    String? text,
    DateTime? timestamp,
    bool? edited,
    DateTime? editedAt,
    Map<String, String>? reactions,
    bool? deleted,
  }) {
    return CommentModel(
      commentId: commentId ?? this.commentId,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      edited: edited ?? this.edited,
      editedAt: editedAt ?? this.editedAt,
      reactions: reactions ?? this.reactions,
      deleted: deleted ?? this.deleted,
    );
  }

  static DateTime _toDateTime(dynamic timestamp) {
    if (timestamp == null) {
      debugPrint(
          "CommentModel: Null timestamp encountered, using now as fallback");
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
        "CommentModel WARNING: Unhandled timestamp type: ${timestamp.runtimeType}");
    return DateTime.now();
  }

  @override
  List<Object?> get props => [
        commentId,
        postId,
        userId,
        username,
        photoUrl,
        text,
        timestamp,
        edited,
        editedAt,
        reactions,
        deleted,
      ];
}
