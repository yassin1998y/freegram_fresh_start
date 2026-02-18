// lib/screens/report_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/widgets/common/keyboard_safe_area.dart';
import 'package:freegram/repositories/report_repository.dart';
import 'package:freegram/models/report_model.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class ReportScreen extends StatefulWidget {
  final ReportContentType contentType;
  final String contentId;

  const ReportScreen({
    Key? key,
    required this.contentType,
    required this.contentId,
  }) : super(key: key);

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ReportRepository _reportRepository = locator<ReportRepository>();
  final TextEditingController _reasonController = TextEditingController();
  ReportCategory? _selectedCategory;
  bool _isSubmitting = false;

  final Map<ReportCategory, Map<String, dynamic>> _categories = {
    ReportCategory.spam: {
      'label': 'Spam',
      'icon': Icons.block,
      'description': 'Repetitive, unwanted, or deceptive content',
    },
    ReportCategory.harassment: {
      'label': 'Harassment or Bullying',
      'icon': Icons.warning,
      'description': 'Content that attacks or threatens someone',
    },
    ReportCategory.falseInfo: {
      'label': 'False Information',
      'icon': Icons.info_outline,
      'description': 'Misleading or factually incorrect information',
    },
    ReportCategory.inappropriate: {
      'label': 'Inappropriate Content',
      'icon': Icons.remove_circle_outline,
      'description': 'Content that violates community guidelines',
    },
    ReportCategory.violence: {
      'label': 'Violence',
      'icon': Icons.dangerous,
      'description': 'Violent or graphic content',
    },
    ReportCategory.intellectualProperty: {
      'label': 'Intellectual Property Violation',
      'icon': Icons.copyright,
      'description': 'Content that infringes copyright or trademarks',
    },
    ReportCategory.other: {
      'label': 'Other',
      'icon': Icons.more_horiz,
      'description': 'Something else that violates our policies',
    },
  };

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _reportRepository.reportContent(
        contentType: widget.contentType,
        contentId: widget.contentId,
        userId: user.uid,
        category: _selectedCategory!,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Report submitted successfully. Thank you for helping keep our community safe.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('ReportScreen: Error submitting report: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('already reported')
                ? 'You have already reported this content'
                : 'Failed to submit report. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 SCREEN: report_screen.dart');
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Report Content'),
      ),
      body: KeyboardSafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why are you reporting this?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your report is anonymous and helps us keep our community safe.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 24),
              ..._categories.entries.map((entry) {
                final category = entry.key;
                final data = entry.value;
                final isSelected = _selectedCategory == category;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  decoration: Containers.glassCard(context).copyWith(
                    color: isSelected
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1)
                        : null,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.0)
                        : null,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            data['icon'] as IconData,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['label'] as String,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data['description'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              if (_selectedCategory != null) ...[
                Text(
                  'Additional Details (Optional)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reasonController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Provide any additional context...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: AppProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit Report'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
