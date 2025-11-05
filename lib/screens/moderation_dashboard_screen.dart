// lib/screens/moderation_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/report_repository.dart';
import 'package:freegram/services/moderation_service.dart';
import 'package:freegram/models/report_model.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/page_repository.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/page_model.dart';
import 'package:intl/intl.dart';

class ModerationDashboardScreen extends StatefulWidget {
  const ModerationDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ModerationDashboardScreen> createState() =>
      _ModerationDashboardScreenState();
}

class _ModerationDashboardScreenState extends State<ModerationDashboardScreen>
    with SingleTickerProviderStateMixin {
  final ReportRepository _reportRepository = locator<ReportRepository>();
  final ModerationService _moderationService = locator<ModerationService>();
  final PostRepository _postRepository = locator<PostRepository>();
  final PageRepository _pageRepository = locator<PageRepository>();

  List<ReportModel> _reports = [];
  bool _isLoading = true;
  ReportStatus? _filterStatus;
  ReportCategory? _filterCategory;
  late TabController _tabController;

  Map<ReportStatus, int> _reportCounts = {};

  bool _isAdmin = false;
  bool _checkingAdmin = true;

  List<Map<String, dynamic>> _verificationRequests = [];
  bool _isLoadingVerifications = false;
  String? _verificationFilterStatus;
  Map<String, int> _verificationCounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 5, vsync: this); // 4 report tabs + 1 verification tab
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in')),
        );
      }
      return;
    }

    try {
      // Check if user has admin role in Firestore or custom claims
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final isAdmin = userData['isAdmin'] == true ||
            userData['role'] == 'admin' ||
            userData['admin'] == true;

        if (mounted) {
          setState(() {
            _isAdmin = isAdmin;
            _checkingAdmin = false;
          });

          if (!_isAdmin) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Access denied. Admin privileges required.'),
              ),
            );
            return;
          }
        }

        // Load data if admin
        _loadReports();
        _loadReportCounts();
        _loadVerificationRequests();
        _loadVerificationCounts();
      } else {
        if (mounted) {
          setState(() {
            _isAdmin = false;
            _checkingAdmin = false;
          });
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found')),
          );
        }
      }
    } catch (e) {
      debugPrint('ModerationDashboardScreen: Error checking admin: $e');
      if (mounted) {
        setState(() {
          _checkingAdmin = false;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking permissions: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final reports = await _reportRepository.getReports(
        status: _filterStatus,
        category: _filterCategory,
        limit: 100,
      );

      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ModerationDashboardScreen: Error loading reports: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadReportCounts() async {
    try {
      final counts = await _reportRepository.getReportCounts();
      if (mounted) {
        setState(() {
          _reportCounts = counts;
        });
      }
    } catch (e) {
      debugPrint('ModerationDashboardScreen: Error loading counts: $e');
    }
  }

  Future<void> _loadVerificationRequests() async {
    setState(() => _isLoadingVerifications = true);

    try {
      final requests = await _pageRepository.getVerificationRequests(
        status: _verificationFilterStatus,
        limit: 100,
      );

      if (mounted) {
        setState(() {
          _verificationRequests = requests;
          _isLoadingVerifications = false;
        });
      }
    } catch (e) {
      debugPrint(
          'ModerationDashboardScreen: Error loading verification requests: $e');
      if (mounted) {
        setState(() => _isLoadingVerifications = false);
      }
    }
  }

  Future<void> _loadVerificationCounts() async {
    try {
      final counts = await _pageRepository.getVerificationRequestCounts();
      if (mounted) {
        setState(() {
          _verificationCounts = counts;
        });
      }
    } catch (e) {
      debugPrint(
          'ModerationDashboardScreen: Error loading verification counts: $e');
    }
  }

  Future<void> _approveVerification(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _pageRepository.approveVerificationRequest(
        requestId: requestId,
        adminUserId: user.uid,
      );

      await _loadVerificationRequests();
      await _loadVerificationCounts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Verification request approved'),
          ),
        );
      }
    } catch (e) {
      debugPrint('ModerationDashboardScreen: Error approving verification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _rejectVerification(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Verification Request'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason (Optional)',
            hintText: 'Enter reason for rejection...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, reasonController.text.trim());
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null && reasonController.text.trim().isEmpty) {
      return; // User cancelled
    }

    try {
      await _pageRepository.rejectVerificationRequest(
        requestId: requestId,
        adminUserId: user.uid,
        reason: reason ?? reasonController.text.trim(),
      );

      await _loadVerificationRequests();
      await _loadVerificationCounts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Verification request rejected'),
          ),
        );
      }
    } catch (e) {
      debugPrint('ModerationDashboardScreen: Error rejecting verification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _removeVerification(String pageId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show confirmation dialog with reason input
    final reasonController = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to remove verification from this page?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (Optional)',
                hintText: 'Enter reason for removing verification...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'confirmed': true,
                'reason': reasonController.text.trim(),
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (result == null || result['confirmed'] != true) return;

    final reason = result['reason'] as String?;

    try {
      await _pageRepository.removeVerification(
        pageId: pageId,
        adminUserId: user.uid,
        reason: reason,
      );

      await _loadVerificationRequests();
      await _loadVerificationCounts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Verification removed successfully'),
          ),
        );
      }
    } catch (e) {
      debugPrint('ModerationDashboardScreen: Error removing verification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _reviewReport(
    ReportModel report,
    String action,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? reason;
    if (action == 'warn' || action.startsWith('ban_')) {
      reason = await _showReasonDialog(action);
      if (reason == null) return; // User cancelled
    }

    try {
      await _moderationService.reviewReport(
        reportId: report.reportId,
        adminUserId: user.uid,
        action: action,
        reason: reason,
      );

      await _loadReports();
      await _loadReportCounts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action taken: ${_getActionLabel(action)}')),
        );
      }
    } catch (e) {
      debugPrint('ModerationDashboardScreen: Error reviewing report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<String?> _showReasonDialog(String action) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reason for ${_getActionLabel(action)}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter reason...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  String _getActionLabel(String action) {
    switch (action) {
      case 'delete':
        return 'Delete Content';
      case 'warn':
        return 'Warn User';
      case 'ban_temporary':
        return 'Temporary Ban';
      case 'ban_permanent':
        return 'Permanent Ban';
      case 'dismiss':
        return 'Dismiss Report';
      default:
        return action;
    }
  }

  Future<void> _viewContent(ReportModel report) async {
    Widget? contentWidget;

    switch (report.reportedContentType) {
      case ReportContentType.post:
        final post =
            await _postRepository.getPostById(report.reportedContentId);
        if (post != null) {
          contentWidget = _buildPostPreview(post);
        }
        break;
      case ReportContentType.page:
        final page = await _pageRepository.getPage(report.reportedContentId);
        if (page != null) {
          contentWidget = _buildPagePreview(page);
        }
        break;
      case ReportContentType.comment:
      case ReportContentType.user:
        // Show basic info
        contentWidget = Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Content ID: ${report.reportedContentId}'),
        );
        break;
    }

    if (contentWidget != null && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
              'Reported ${_getContentTypeLabel(report.reportedContentType)}'),
          content: SizedBox(
            width: double.maxFinite,
            child: contentWidget,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPostPreview(PostModel post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Post by ${post.pageName ?? post.authorUsername}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(post.content),
        if (post.mediaItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              '${post.mediaItems.length} media file(s)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }

  Widget _buildPagePreview(PageModel page) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          page.pageName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(page.description.isNotEmpty ? page.description : 'No description'),
      ],
    );
  }

  String _getContentTypeLabel(ReportContentType type) {
    switch (type) {
      case ReportContentType.post:
        return 'Post';
      case ReportContentType.comment:
        return 'Comment';
      case ReportContentType.page:
        return 'Page';
      case ReportContentType.user:
        return 'User';
    }
  }

  String _getCategoryLabel(ReportCategory category) {
    switch (category) {
      case ReportCategory.spam:
        return 'Spam';
      case ReportCategory.harassment:
        return 'Harassment';
      case ReportCategory.falseInfo:
        return 'False Information';
      case ReportCategory.inappropriate:
        return 'Inappropriate';
      case ReportCategory.violence:
        return 'Violence';
      case ReportCategory.intellectualProperty:
        return 'Intellectual Property';
      case ReportCategory.other:
        return 'Other';
    }
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.reviewed:
        return Colors.blue;
      case ReportStatus.resolved:
        return Colors.green;
      case ReportStatus.dismissed:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moderation Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moderation Dashboard')),
        body: const Center(
          child: Text('Access denied. Admin privileges required.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          onTap: (index) {
            if (index < 4) {
              // Report tabs
              setState(() {
                _filterStatus = [
                  ReportStatus.pending,
                  ReportStatus.reviewed,
                  ReportStatus.resolved,
                  null
                ][index];
              });
              _loadReports();
            } else {
              // Verification tab
              setState(() {
                _verificationFilterStatus = null; // Show all initially
              });
              _loadVerificationRequests();
            }
          },
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Reviewed'),
            Tab(text: 'Resolved'),
            Tab(text: 'All Reports'),
            Tab(text: 'Verifications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Reports tabs
          _buildReportsTab(),
          _buildReportsTab(),
          _buildReportsTab(),
          _buildReportsTab(),
          // Verifications tab
          _buildVerificationsTab(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    return Column(
      children: [
        // Stats cards
        if (_reportCounts.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Pending',
                    _reportCounts[ReportStatus.pending] ?? 0,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Reviewed',
                    _reportCounts[ReportStatus.reviewed] ?? 0,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Resolved',
                    _reportCounts[ReportStatus.resolved] ?? 0,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ),
        // Reports list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No reports to review',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _loadReports();
                        await _loadReportCounts();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          return _buildReportCard(report);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildVerificationsTab() {
    return Column(
      children: [
        // Stats cards for verifications
        if (_verificationCounts.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Pending',
                    _verificationCounts['pending'] ?? 0,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Approved',
                    _verificationCounts['approved'] ?? 0,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Rejected',
                    _verificationCounts['rejected'] ?? 0,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ),
        // Filter buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _verificationFilterStatus == null,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _verificationFilterStatus = null);
                    _loadVerificationRequests();
                  }
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Pending'),
                selected: _verificationFilterStatus == 'pending',
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _verificationFilterStatus = 'pending');
                    _loadVerificationRequests();
                  }
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Approved'),
                selected: _verificationFilterStatus == 'approved',
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _verificationFilterStatus = 'approved');
                    _loadVerificationRequests();
                  }
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Rejected'),
                selected: _verificationFilterStatus == 'rejected',
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _verificationFilterStatus = 'rejected');
                    _loadVerificationRequests();
                  }
                },
              ),
            ],
          ),
        ),
        // Verification requests list
        Expanded(
          child: _isLoadingVerifications
              ? const Center(child: CircularProgressIndicator())
              : _verificationRequests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No verification requests',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _loadVerificationRequests();
                        await _loadVerificationCounts();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _verificationRequests.length,
                        itemBuilder: (context, index) {
                          final request = _verificationRequests[index];
                          return _buildVerificationRequestCard(request);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildVerificationRequestCard(Map<String, dynamic> request) {
    final status = request['status'] as String? ?? 'pending';
    final pageId = request['pageId'] as String?;
    final requestId = request['requestId'] as String;
    final businessDoc = request['businessDocumentation'] as String? ?? '';
    final identityProof = request['identityProof'] as String? ?? '';
    final additionalInfo = request['additionalInfo'] as String?;
    final createdAt = request['createdAt'] as Timestamp?;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            statusIcon,
            color: statusColor,
            size: 20,
          ),
        ),
        title: FutureBuilder<PageModel?>(
          future: pageId != null ? _pageRepository.getPage(pageId) : null,
          builder: (context, snapshot) {
            final pageName =
                snapshot.data?.pageName ?? pageId ?? 'Unknown Page';
            return Text(
              pageName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            );
          },
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${status.toUpperCase()}'),
            if (createdAt != null)
              Text(
                'Requested ${DateFormat('MMM d, y • h:mm a').format(createdAt.toDate())}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: Chip(
          label: Text(
            status.toUpperCase(),
            style: const TextStyle(fontSize: 10),
          ),
          backgroundColor: statusColor.withOpacity(0.1),
          labelStyle: TextStyle(color: statusColor),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection('Business Documentation', businessDoc),
                const SizedBox(height: 16),
                _buildInfoSection('Identity Proof', identityProof),
                if (additionalInfo != null && additionalInfo.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildInfoSection('Additional Information', additionalInfo),
                ],
                if (status == 'pending' && pageId != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveVerification(requestId),
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _rejectVerification(requestId),
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (status == 'approved' && pageId != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _removeVerification(pageId),
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: const Text('Remove Verification'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String label, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            content.isNotEmpty ? content : 'No information provided',
            style: TextStyle(
              color: content.isEmpty ? Colors.grey[600] : null,
              fontStyle: content.isEmpty ? FontStyle.italic : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(ReportModel report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: _getStatusColor(report.status).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.flag,
            color: _getStatusColor(report.status),
            size: 20,
          ),
        ),
        title: Text(
          '${_getContentTypeLabel(report.reportedContentType)} Report',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${_getCategoryLabel(report.reportCategory)}'),
            Text(
              'Reported ${DateFormat('MMM d, y • h:mm a').format(report.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Chip(
          label: Text(
            report.status.toString().split('.').last.toUpperCase(),
            style: const TextStyle(fontSize: 10),
          ),
          backgroundColor: _getStatusColor(report.status).withOpacity(0.1),
          labelStyle: TextStyle(color: _getStatusColor(report.status)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reason:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(report.reportReason),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _viewContent(report),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Content'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    if (report.status == ReportStatus.pending) ...[
                      OutlinedButton(
                        onPressed: () => _reviewReport(report, 'dismiss'),
                        child: const Text('Dismiss'),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (action) => _reviewReport(report, action),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete Content'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'warn',
                            child: Row(
                              children: [
                                Icon(Icons.warning, size: 18),
                                SizedBox(width: 8),
                                Text('Warn User'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'ban_temporary',
                            child: Row(
                              children: [
                                Icon(Icons.block, size: 18),
                                SizedBox(width: 8),
                                Text('Temp Ban'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'ban_permanent',
                            child: Row(
                              children: [
                                Icon(Icons.block, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Permanent Ban'),
                              ],
                            ),
                          ),
                        ],
                        child: ElevatedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.gavel, size: 18),
                          label: const Text('Take Action'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (report.reviewedBy != null &&
                    report.actionTaken != null) ...[
                  const Divider(height: 24),
                  Text(
                    'Action Taken: ${_getActionLabel(report.actionTaken!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (report.reviewedAt != null)
                    Text(
                      'Reviewed: ${DateFormat('MMM d, y • h:mm a').format(report.reviewedAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
