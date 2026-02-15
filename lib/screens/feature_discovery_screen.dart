// lib/screens/feature_discovery_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/feature_guide_repository.dart';
import 'package:freegram/models/feature_guide_model.dart';
import 'package:freegram/screens/feature_guide_detail_screen.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class FeatureDiscoveryScreen extends StatefulWidget {
  const FeatureDiscoveryScreen({Key? key}) : super(key: key);

  @override
  State<FeatureDiscoveryScreen> createState() => _FeatureDiscoveryScreenState();
}

class _FeatureDiscoveryScreenState extends State<FeatureDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  final FeatureGuideRepository _repository = locator<FeatureGuideRepository>();
  late TabController _tabController;

  List<FeatureGuideModel> _allGuides = [];
  List<String> _completedGuides = [];
  Map<String, dynamic> _progressStats = {};
  bool _isLoading = true;

  final List<String> _categories = [
    'posting',
    'discovery',
    'engagement',
    'monetization',
    'management',
  ];

  final Map<String, String> _categoryLabels = {
    'posting': '📝 Posting',
    'discovery': '🔍 Discovery',
    'engagement': '💚 Engagement',
    'monetization': '🚀 Growth',
    'management': '⚙️ Management',
  };

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: feature_discovery_screen.dart');
    _tabController = TabController(length: _categories.length + 1, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final guides = await _repository.getFeatureGuides();
      final completed = await _repository.getUserProgress(user.uid);
      final stats = await _repository.getUserProgressStats(user.uid);

      if (mounted) {
        setState(() {
          _allGuides = guides;
          _completedGuides = completed;
          _progressStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('FeatureDiscoveryScreen: Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<FeatureGuideModel> _getGuidesForCategory(String? category) {
    if (category == null) return _allGuides;
    return _allGuides.where((guide) => guide.category == category).toList();
  }

  bool _isCompleted(String featureId) {
    return _completedGuides.contains(featureId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Discovery'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(text: 'All'),
            ..._categories.map((cat) => Tab(text: _categoryLabels[cat] ?? cat)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: AppProgressIndicator())
          : Column(
              children: [
                // Progress card
                if (_progressStats['total'] != null &&
                    _progressStats['total'] > 0)
                  Container(
                    margin: const EdgeInsets.all(16.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Progress',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        AppLinearProgressIndicator(
                          value: (_progressStats['percentage'] ?? 0) / 100,
                          backgroundColor: Colors.grey[300],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_progressStats['completed'] ?? 0} of ${_progressStats['total'] ?? 0} features completed',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                // Guides list
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // All tab
                      _buildGuidesList(null),
                      // Category tabs
                      ..._categories.map((cat) => _buildGuidesList(cat)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGuidesList(String? category) {
    final guides = _getGuidesForCategory(category);

    if (guides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No guides available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: guides.length,
      itemBuilder: (context, index) {
        final guide = guides[index];
        final isCompleted = _isCompleted(guide.featureId);

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FeatureGuideDetailScreen(
                    guide: guide,
                    isCompleted: isCompleted,
                  ),
                ),
              ).then((_) {
                // Refresh on return
                _loadData();
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        guide.icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                guide.featureName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (isCompleted)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          guide.description,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildDifficultyChip(guide.difficulty),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${guide.estimatedTime} min',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDifficultyChip(FeatureDifficulty difficulty) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
