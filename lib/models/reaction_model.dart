// lib/models/reaction_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

class ReactionModel extends Equatable {
  final String userId;
  final String reactionType; // For now, only 'heart' (like)
  final DateTime timestamp;

  const ReactionModel({
    required this.userId,
    this.reactionType = 'heart', // Default to heart/like
    required this.timestamp,
  });

  factory ReactionModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReactionModel.fromMap(doc.id, data);
  }

  factory ReactionModel.fromMap(String userId, Map<String, dynamic> data) {
    // Parse timestamp
    final timestamp = _toDateTime(data['timestamp']);

    return ReactionModel(
      userId: userId,
      reactionType: data['reactionType'] ?? 'heart',
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'reactionType': reactionType,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  ReactionModel copyWith({
    String? userId,
    String? reactionType,
    DateTime? timestamp,
  }) {
    return ReactionModel(
      userId: userId ?? this.userId,
      reactionType: reactionType ?? this.reactionType,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  static DateTime _toDateTime(dynamic timestamp) {
    if (timestamp == null) {
      debugPrint(
          "ReactionModel: Null timestamp encountered, using now as fallback");
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
        "ReactionModel WARNING: Unhandled timestamp type: ${timestamp.runtimeType}");
    return DateTime.now();
  }

  @override
  List<Object?> get props => [
        userId,
        reactionType,
        timestamp,
      ];
}
