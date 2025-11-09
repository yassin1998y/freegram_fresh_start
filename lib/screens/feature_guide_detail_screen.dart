// lib/screens/feature_guide_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/feature_guide_repository.dart';
import 'package:freegram/models/feature_guide_model.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class FeatureGuideDetailScreen extends StatefulWidget {
  final FeatureGuideModel guide;
  final bool isCompleted;

  const FeatureGuideDetailScreen({
    Key? key,
    required this.guide,
    required this.isCompleted,
  }) : super(key: key);

  @override
  State<FeatureGuideDetailScreen> createState() =>
      _FeatureGuideDetailScreenState();
}

class _FeatureGuideDetailScreenState extends State<FeatureGuideDetailScreen> {
  final FeatureGuideRepository _repository = locator<FeatureGuideRepository>();
  bool _isCompleted = false;
  bool _isMarkingComplete = false;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: feature_guide_detail_screen.dart');
    _isCompleted = widget.isCompleted;
  }

  Future<void> _markAsCompleted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isMarkingComplete = true;
    });

    try {
      await _repository.markGuideCompleted(user.uid, widget.guide.featureId);
      if (mounted) {
        setState(() {
          _isCompleted = true;
          _isMarkingComplete = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${widget.guide.featureName} marked as completed! 🎉'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('FeatureGuideDetailScreen: Error marking complete: $e');
      if (mounted) {
        setState(() {
          _isMarkingComplete = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildDifficultyBadge(FeatureDifficulty difficulty) {
    Color color;
    String label;

    switch (difficulty) {
      case FeatureDifficulty.easy:
        color = Colors.green;
        label = 'Easy';
        break;
      case FeatureDifficulty.medium:
        color = Colors.orange;
        label = 'Medium';
        break;
      case FeatureDifficulty.advanced:
        color = Colors.red;
        label = 'Advanced';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.guide.featureName),
        actions: [
          if (_isCompleted)
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      widget.guide.icon,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.guide.featureName,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDifficultyBadge(widget.guide.difficulty),
                          const SizedBox(width: 8),
                          Icon(Icons.access_time,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.guide.estimatedTime} min',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Description
            Text(
              'About',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.guide.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            // Steps
            if (widget.guide.steps.isNotEmpty) ...[
              Text(
                'How to Use',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ...widget.guide.steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step.description,
                              style: TextStyle(
                                color: Colors.grey[700],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_getActionLabel(step.action)}: ${step.target}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            // Screenshots
            if (widget.guide.screenshotUrls.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Screenshots',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.guide.screenshotUrls.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 12.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image:
                              NetworkImage(widget.guide.screenshotUrls[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            // Related features
            if (widget.guide.relatedFeatures.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Related Features',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.guide.relatedFeatures.map((featureId) {
                  return Chip(
                    label: Text(featureId),
                    onDeleted: () {
                      // Navigate to related feature (if implemented)
                      debugPrint('Navigate to feature: $featureId');
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 32),
            // Action buttons
            if (!_isCompleted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isMarkingComplete ? null : _markAsCompleted,
                  icon: _isMarkingComplete
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: AppProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(
                      _isMarkingComplete ? 'Marking...' : 'Mark as Completed'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Implement "Try It Now" deep linking
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Feature deep linking coming soon!'),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Try It Now'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getActionLabel(String action) {
    switch (action.toLowerCase()) {
      case 'tap_button':
        return 'Tap';
      case 'swipe':
        return 'Swipe';
      case 'long_press':
        return 'Long press';
      case 'navigate':
        return 'Navigate to';
      default:
        return action;
    }
  }
}
