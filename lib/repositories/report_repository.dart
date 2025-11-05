// lib/repositories/report_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/report_model.dart';

class ReportRepository {
  final FirebaseFirestore _db;

  ReportRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Submit a report
  Future<String> reportContent({
    required ReportContentType contentType,
    required String contentId,
    required String userId,
    required ReportCategory category,
    required String reason,
  }) async {
    try {
      // Check if user has already reported this content
      final existingReports = await _db
          .collection('reports')
          .where('reportedContentId', isEqualTo: contentId)
          .where('reportedBy', isEqualTo: userId)
          .where('reportedContentType',
              isEqualTo: _contentTypeToString(contentType))
          .get();

      if (existingReports.docs.isNotEmpty) {
        throw Exception('You have already reported this content');
      }

      final reportRef = _db.collection('reports').doc();
      final now = FieldValue.serverTimestamp();

      await reportRef.set({
        'reportId': reportRef.id,
        'reportedContentType': _contentTypeToString(contentType),
        'reportedContentId': contentId,
        'reportedBy': userId,
        'reportCategory': _categoryToString(category),
        'reportReason': reason,
        'status': 'pending',
        'createdAt': now,
        'updatedAt': now,
      });

      return reportRef.id;
    } catch (e) {
      debugPrint('ReportRepository: Error submitting report: $e');
      rethrow;
    }
  }

  /// Get all reports (admin only)
  Future<List<ReportModel>> getReports({
    ReportStatus? status,
    ReportCategory? category,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _db.collection('reports');

      if (status != null) {
        query = query.where('status', isEqualTo: _statusToString(status));
      }

      if (category != null) {
        query = query.where('reportCategory',
            isEqualTo: _categoryToString(category));
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => ReportModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('ReportRepository: Error getting reports: $e');
      return [];
    }
  }

  /// Get reports by a specific user
  Future<List<ReportModel>> getUserReports(String userId,
      {int limit = 20}) async {
    try {
      final snapshot = await _db
          .collection('reports')
          .where('reportedBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => ReportModel.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('ReportRepository: Error getting user reports: $e');
      return [];
    }
  }

  /// Update report status (admin only)
  Future<void> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    required String reviewedBy,
    String? actionTaken,
  }) async {
    try {
      await _db.collection('reports').doc(reportId).update({
        'status': _statusToString(status),
        'reviewedBy': reviewedBy,
        'reviewedAt': FieldValue.serverTimestamp(),
        'actionTaken': actionTaken,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ReportRepository: Error updating report status: $e');
      rethrow;
    }
  }

  /// Get report by ID
  Future<ReportModel?> getReport(String reportId) async {
    try {
      final doc = await _db.collection('reports').doc(reportId).get();
      if (!doc.exists) {
        return null;
      }
      return ReportModel.fromDoc(doc);
    } catch (e) {
      debugPrint('ReportRepository: Error getting report: $e');
      rethrow;
    }
  }

  /// Get report count by status (for moderation dashboard stats)
  Future<Map<ReportStatus, int>> getReportCounts() async {
    try {
      final pendingSnapshot = await _db
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      final reviewedSnapshot = await _db
          .collection('reports')
          .where('status', isEqualTo: 'reviewed')
          .count()
          .get();

      final resolvedSnapshot = await _db
          .collection('reports')
          .where('status', isEqualTo: 'resolved')
          .count()
          .get();

      return {
        ReportStatus.pending: pendingSnapshot.count ?? 0,
        ReportStatus.reviewed: reviewedSnapshot.count ?? 0,
        ReportStatus.resolved: resolvedSnapshot.count ?? 0,
        ReportStatus.dismissed: 0, // Can be calculated if needed
      };
    } catch (e) {
      debugPrint('ReportRepository: Error getting report counts: $e');
      return {
        ReportStatus.pending: 0,
        ReportStatus.reviewed: 0,
        ReportStatus.resolved: 0,
        ReportStatus.dismissed: 0,
      };
    }
  }

  String _contentTypeToString(ReportContentType type) {
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

  String _categoryToString(ReportCategory category) {
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

  String _statusToString(ReportStatus status) {
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
}
