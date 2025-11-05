// lib/models/report_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

enum ReportContentType {
  post,
  comment,
  page,
  user,
}

enum ReportCategory {
  spam,
  harassment,
  falseInfo,
  inappropriate,
  violence,
  intellectualProperty,
  other,
}

enum ReportStatus {
  pending,
  reviewed,
  resolved,
  dismissed,
}

class ReportModel extends Equatable {
  final String reportId;
  final ReportContentType reportedContentType;
  final String reportedContentId;
  final String reportedBy; // userId
  final ReportCategory reportCategory;
  final String reportReason;
  final ReportStatus status;
  final String? reviewedBy; // Admin userId
  final DateTime? reviewedAt;
  final String?
      actionTaken; // 'deleted', 'warned', 'banned_temporary', 'banned_permanent', 'no_action'
  final DateTime createdAt;
  final DateTime updatedAt;

  ReportModel({
    required this.reportId,
    required this.reportedContentType,
    required this.reportedContentId,
    required this.reportedBy,
    required this.reportCategory,
    required this.reportReason,
    this.status = ReportStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    this.actionTaken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReportModel.fromMap(doc.id, data);
  }

  factory ReportModel.fromMap(String id, Map<String, dynamic> data) {
    final createdAt = _toDateTime(data['createdAt']);
    final updatedAt = _toDateTime(data['updatedAt'] ?? data['createdAt']);
    final reviewedAt =
        data['reviewedAt'] != null ? _toDateTime(data['reviewedAt']) : null;

    return ReportModel(
      reportId: id,
      reportedContentType: _stringToContentType(data['reportedContentType']),
      reportedContentId: data['reportedContentId'] ?? '',
      reportedBy: data['reportedBy'] ?? '',
      reportCategory: _stringToCategory(data['reportCategory']),
      reportReason: data['reportReason'] ?? '',
      status: _stringToStatus(data['status'] ?? 'pending'),
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: reviewedAt,
      actionTaken: data['actionTaken'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'reportedContentType': _contentTypeToString(reportedContentType),
      'reportedContentId': reportedContentId,
      'reportedBy': reportedBy,
      'reportCategory': _categoryToString(reportCategory),
      'reportReason': reportReason,
      'status': _statusToString(status),
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'actionTaken': actionTaken,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ReportModel copyWith({
    String? reportId,
    ReportContentType? reportedContentType,
    String? reportedContentId,
    String? reportedBy,
    ReportCategory? reportCategory,
    String? reportReason,
    ReportStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? actionTaken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      reportId: reportId ?? this.reportId,
      reportedContentType: reportedContentType ?? this.reportedContentType,
      reportedContentId: reportedContentId ?? this.reportedContentId,
      reportedBy: reportedBy ?? this.reportedBy,
      reportCategory: reportCategory ?? this.reportCategory,
      reportReason: reportReason ?? this.reportReason,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      actionTaken: actionTaken ?? this.actionTaken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime _toDateTime(dynamic timestamp) {
    if (timestamp == null) {
      debugPrint('ReportModel: Null timestamp, using now');
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
        'ReportModel WARNING: Unhandled timestamp type: ${timestamp.runtimeType}');
    return DateTime.now();
  }

  static ReportContentType _stringToContentType(String str) {
    switch (str.toLowerCase()) {
      case 'post':
        return ReportContentType.post;
      case 'comment':
        return ReportContentType.comment;
      case 'page':
        return ReportContentType.page;
      case 'user':
        return ReportContentType.user;
      default:
        return ReportContentType.post;
    }
  }

  static String _contentTypeToString(ReportContentType type) {
    switch (type) {
      case ReportContentType.post:
        return 'post';
      case ReportContentType.comment:
        return 'comment';
      case ReportContentType.page:
        return 'page';
      case ReportContentType.user:
        return 'user';
    }
  }

  static ReportCategory _stringToCategory(String str) {
    switch (str.toLowerCase()) {
      case 'spam':
        return ReportCategory.spam;
      case 'harassment':
        return ReportCategory.harassment;
      case 'falseinfo':
      case 'false_info':
        return ReportCategory.falseInfo;
      case 'inappropriate':
        return ReportCategory.inappropriate;
      case 'violence':
        return ReportCategory.violence;
      case 'intellectualproperty':
      case 'intellectual_property':
        return ReportCategory.intellectualProperty;
      case 'other':
        return ReportCategory.other;
      default:
        return ReportCategory.other;
    }
  }

  static String _categoryToString(ReportCategory category) {
    switch (category) {
      case ReportCategory.spam:
        return 'spam';
      case ReportCategory.harassment:
        return 'harassment';
      case ReportCategory.falseInfo:
        return 'false_info';
      case ReportCategory.inappropriate:
        return 'inappropriate';
      case ReportCategory.violence:
        return 'violence';
      case ReportCategory.intellectualProperty:
        return 'intellectual_property';
      case ReportCategory.other:
        return 'other';
    }
  }

  static ReportStatus _stringToStatus(String str) {
    switch (str.toLowerCase()) {
      case 'pending':
        return ReportStatus.pending;
      case 'reviewed':
        return ReportStatus.reviewed;
      case 'resolved':
        return ReportStatus.resolved;
      case 'dismissed':
        return ReportStatus.dismissed;
      default:
        return ReportStatus.pending;
    }
  }

  static String _statusToString(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return 'pending';
      case ReportStatus.reviewed:
        return 'reviewed';
      case ReportStatus.resolved:
        return 'resolved';
      case ReportStatus.dismissed:
        return 'dismissed';
    }
  }

  @override
  List<Object?> get props => [
        reportId,
        reportedContentType,
        reportedContentId,
        reportedBy,
        reportCategory,
        reportReason,
        status,
        reviewedBy,
        reviewedAt,
        actionTaken,
        createdAt,
        updatedAt,
      ];
}
