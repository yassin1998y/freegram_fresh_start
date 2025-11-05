// lib/services/moderation_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/report_model.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/page_repository.dart';
import 'package:freegram/repositories/report_repository.dart';
import 'package:freegram/locator.dart';

class ModerationService {
  final FirebaseFirestore _db;
  final ReportRepository _reportRepository;
  final PostRepository? _postRepository;
  final PageRepository? _pageRepository;

  ModerationService({
    FirebaseFirestore? db,
    ReportRepository? reportRepository,
    PostRepository? postRepository,
    PageRepository? pageRepository,
  })  : _db = db ?? FirebaseFirestore.instance,
        _reportRepository = reportRepository ?? locator<ReportRepository>(),
        _postRepository = postRepository,
        _pageRepository = pageRepository;

  /// Review a report and take action
  Future<void> reviewReport({
    required String reportId,
    required String adminUserId,
    required String
        action, // 'delete', 'warn', 'ban_temporary', 'ban_permanent', 'dismiss'
    String? reason,
  }) async {
    try {
      final report = await _reportRepository.getReport(reportId);
      if (report == null) {
        throw Exception('Report not found');
      }

      // Take action based on content type
      switch (report.reportedContentType) {
        case ReportContentType.post:
          if (action == 'delete') {
            await _deletePost(report.reportedContentId, adminUserId);
          }
          break;
        case ReportContentType.comment:
          if (action == 'delete') {
            await _deleteComment(report.reportedContentId, adminUserId);
          }
          break;
        case ReportContentType.page:
          if (action == 'delete') {
            await _deletePage(report.reportedContentId, adminUserId);
          }
          break;
        case ReportContentType.user:
          if (action == 'warn') {
            await warnUser(report.reportedContentId, reason);
          } else if (action == 'ban_temporary' || action == 'ban_permanent') {
            await banUser(report.reportedContentId, action, reason);
          }
          break;
      }

      // Update report status
      final status = action == 'dismiss'
          ? ReportStatus.dismissed
          : action == 'delete' || action == 'warn' || action.startsWith('ban_')
              ? ReportStatus.resolved
              : ReportStatus.reviewed;

      await _reportRepository.updateReportStatus(
        reportId: reportId,
        status: status,
        reviewedBy: adminUserId,
        actionTaken: action,
      );

      // Notify user of action taken (optional)
      if (action != 'dismiss') {
        await _notifyUser(report, action, reason);
      }
    } catch (e) {
      debugPrint('ModerationService: Error reviewing report: $e');
      rethrow;
    }
  }

  /// Delete reported content
  Future<void> deleteContent({
    required ReportContentType contentType,
    required String contentId,
    required String adminUserId,
  }) async {
    switch (contentType) {
      case ReportContentType.post:
        await _deletePost(contentId, adminUserId);
        break;
      case ReportContentType.comment:
        await _deleteComment(contentId, adminUserId);
        break;
      case ReportContentType.page:
        await _deletePage(contentId, adminUserId);
        break;
      case ReportContentType.user:
        // User deletion requires special handling
        throw Exception('User deletion must be done through user management');
    }
  }

  /// Send warning to user
  Future<void> warnUser(String userId, String? reason) async {
    try {
      await _db.collection('users').doc(userId).update({
        'warnings': FieldValue.arrayUnion([
          {
            'reason': reason ?? 'Violation of community guidelines',
            'timestamp': FieldValue.serverTimestamp(),
          }
        ]),
        'warningCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('ModerationService: Error warning user: $e');
      rethrow;
    }
  }

  /// Ban user (temporary or permanent)
  Future<void> banUser(String userId, String banType, String? reason) async {
    try {
      final isPermanent = banType == 'ban_permanent';
      final banData = {
        'banned': true,
        'banType': isPermanent ? 'permanent' : 'temporary',
        'banReason': reason ?? 'Violation of community guidelines',
        'bannedAt': FieldValue.serverTimestamp(),
      };

      if (!isPermanent) {
        // Temporary ban for 7 days (can be made configurable)
        final unbanDate = DateTime.now().add(const Duration(days: 7));
        banData['unbannedAt'] = Timestamp.fromDate(unbanDate);
      }

      await _db.collection('users').doc(userId).update(banData);
    } catch (e) {
      debugPrint('ModerationService: Error banning user: $e');
      rethrow;
    }
  }

  /// Notify user of moderation action
  Future<void> _notifyUser(
      ReportModel report, String action, String? reason) async {
    try {
      String contentOwnerId;

      // Determine content owner based on type
      switch (report.reportedContentType) {
        case ReportContentType.post:
          final postRepo = _postRepository ?? locator<PostRepository>();
          final post = await postRepo.getPostById(report.reportedContentId);
          contentOwnerId = post?.authorId ?? '';
          if (contentOwnerId.isEmpty) return;
          break;
        case ReportContentType.comment:
          // Get comment's author ID (would need comment repository)
          contentOwnerId = ''; // Placeholder
          break;
        case ReportContentType.page:
          final pageRepo = _pageRepository ?? locator<PageRepository>();
          final page = await pageRepo.getPage(report.reportedContentId);
          contentOwnerId = page?.ownerId ?? '';
          break;
        case ReportContentType.user:
          contentOwnerId = report.reportedContentId;
          break;
      }

      if (contentOwnerId.isEmpty) return;

      // Create notification document
      await _db
          .collection('users')
          .doc(contentOwnerId)
          .collection('notifications')
          .add({
        'type': 'moderation_action',
        'title': _getActionTitle(action),
        'message': _getActionMessage(action, reason),
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('ModerationService: Error notifying user: $e');
      // Don't throw - notification failure shouldn't break moderation
    }
  }

  String _getActionTitle(String action) {
    switch (action) {
      case 'delete':
        return 'Content Removed';
      case 'warn':
        return 'Warning Issued';
      case 'ban_temporary':
        return 'Temporary Ban';
      case 'ban_permanent':
        return 'Account Banned';
      default:
        return 'Moderation Action';
    }
  }

  String _getActionMessage(String action, String? reason) {
    final reasonText = reason != null ? ' Reason: $reason' : '';
    switch (action) {
      case 'delete':
        return 'Your content has been removed due to a violation of community guidelines.$reasonText';
      case 'warn':
        return 'You have received a warning for violating community guidelines.$reasonText';
      case 'ban_temporary':
        return 'Your account has been temporarily banned for 7 days.$reasonText';
      case 'ban_permanent':
        return 'Your account has been permanently banned.$reasonText';
      default:
        return 'A moderation action has been taken on your content.$reasonText';
    }
  }

  Future<void> _deletePost(String postId, String adminUserId) async {
    // Soft delete by marking as deleted
    await _db.collection('posts').doc(postId).update({
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': adminUserId,
    });
  }

  Future<void> _deleteComment(String commentId, String adminUserId) async {
    // Comments are subcollections, need to find parent post
    // For now, mark as deleted directly
    final commentsSnapshot = await _db
        .collectionGroup('comments')
        .where(FieldPath.documentId, isEqualTo: commentId)
        .get();

    if (commentsSnapshot.docs.isNotEmpty) {
      await commentsSnapshot.docs.first.reference.update({
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': adminUserId,
      });
    }
  }

  Future<void> _deletePage(String pageId, String adminUserId) async {
    // Soft delete page
    await _db.collection('pages').doc(pageId).update({
      'isActive': false,
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': adminUserId,
    });
  }
}
