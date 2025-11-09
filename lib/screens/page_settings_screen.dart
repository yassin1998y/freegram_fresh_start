// lib/screens/page_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/page_repository.dart';
import 'package:freegram/widgets/common/keyboard_safe_area.dart';
import 'package:freegram/models/page_model.dart';
import 'package:freegram/screens/page_analytics_screen.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class PageSettingsScreen extends StatefulWidget {
  final String pageId;

  const PageSettingsScreen({
    Key? key,
    required this.pageId,
  }) : super(key: key);

  @override
  State<PageSettingsScreen> createState() => _PageSettingsScreenState();
}

class _PageSettingsScreenState extends State<PageSettingsScreen> {
  final PageRepository _pageRepository = locator<PageRepository>();
  final _auth = FirebaseAuth.instance;

  PageModel? _page;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: page_settings_screen.dart');
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() => _isLoading = true);

    try {
      final page = await _pageRepository.getPage(widget.pageId);
      setState(() {
        _page = page;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading page: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  bool _isOwner() {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _page == null) return false;
    return _page!.ownerId == currentUser.uid;
  }

  Future<void> _requestVerification() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _page == null) return;

    // Show dialog for verification request
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _VerificationRequestDialog(
        pageId: widget.pageId,
        userId: currentUser.uid,
        pageRepository: _pageRepository,
        onSuccess: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Colors.green,
                content: Text('Verification request submitted successfully!'),
              ),
            );
            _loadPage(); // Reload page to show updated status
          }
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red,
                content: Text('Error: $error'),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Page Settings')),
        body: const Center(child: AppProgressIndicator()),
      );
    }

    if (_page == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Page Settings')),
        body: const Center(child: Text('Page not found')),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Page Settings'),
      ),
      body: KeyboardSafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Verification Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _page!.verificationStatus ==
                                  VerificationStatus.verified
                              ? Icons.verified
                              : _page!.verificationStatus ==
                                      VerificationStatus.pending
                                  ? Icons.pending
                                  : Icons.verified_user_outlined,
                          color: _page!.verificationStatus ==
                                  VerificationStatus.verified
                              ? Colors.blue
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Verification Status',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _page!.verificationStatus == VerificationStatus.verified
                          ? 'Verified ✓'
                          : _page!.verificationStatus ==
                                  VerificationStatus.pending
                              ? 'Verification pending review'
                              : 'Not verified',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_page!.verificationStatus !=
                        VerificationStatus.verified) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _requestVerification,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Request Verification'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Analytics Section
            Card(
              child: ListTile(
                leading: const Icon(Icons.analytics),
                title: const Text('Page Analytics'),
                subtitle: const Text('View detailed analytics and insights'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PageAnalyticsScreen(pageId: widget.pageId),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Admin Management (Owner only)
            if (_isOwner()) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('Manage Admins'),
                  subtitle: const Text('Add or remove page administrators'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to admin management screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Admin management coming soon')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Danger Zone (Owner only)
            if (_isOwner()) ...[
              const Divider(),
              Card(
                color: Colors.red.shade50,
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: const Text(
                    'Delete Page',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text('Permanently delete this page'),
                  onTap: () {
                    // TODO: Implement delete confirmation
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Page deletion coming soon')),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerificationRequestDialog extends StatefulWidget {
  final String pageId;
  final String userId;
  final PageRepository pageRepository;
  final VoidCallback onSuccess;
  final void Function(String) onError;

  const _VerificationRequestDialog({
    Key? key,
    required this.pageId,
    required this.userId,
    required this.pageRepository,
    required this.onSuccess,
    required this.onError,
  }) : super(key: key);

  @override
  State<_VerificationRequestDialog> createState() =>
      _VerificationRequestDialogState();
}

class _VerificationRequestDialogState
    extends State<_VerificationRequestDialog> {
  final _businessDocController = TextEditingController();
  final _identityProofController = TextEditingController();
  final _additionalInfoController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _businessDocController.addListener(_onChanged);
    _identityProofController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _businessDocController.dispose();
    _identityProofController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool get _canSubmit {
    return !_isSubmitting &&
        _businessDocController.text.trim().isNotEmpty &&
        _identityProofController.text.trim().isNotEmpty;
  }

  Future<void> _submitVerification() async {
    if (!_canSubmit) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.pageRepository.requestVerification(
        pageId: widget.pageId,
        userId: widget.userId,
        businessDocumentation: _businessDocController.text.trim(),
        identityProof: _identityProofController.text.trim(),
        additionalInfo: _additionalInfoController.text.trim().isEmpty
            ? null
            : _additionalInfoController.text.trim(),
      );

      // Use post-frame callback to avoid navigation lock
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
            widget.onSuccess();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _isSubmitting = false;
          _errorMessage = errorMessage;
        });
        widget.onError(errorMessage);
        // Don't close dialog on error, let user retry
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request Verification'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide the following information for verification:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _businessDocController,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Business Documentation *',
                hintText: 'Link or description of business documentation',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _identityProofController,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Identity Proof *',
                hintText: 'Link or description of identity proof',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _additionalInfoController,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Additional Information (Optional)',
                hintText: 'Any additional information that might help',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            if (_isSubmitting) ...[
              const SizedBox(height: 16),
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: AppProgressIndicator(),
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canSubmit ? _submitVerification : null,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: AppProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
