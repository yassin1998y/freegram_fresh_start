// lib/widgets/feature_tutorial_overlay.dart

import 'package:flutter/material.dart';
import 'package:freegram/models/feature_guide_model.dart';
import 'package:freegram/widgets/guided_overlay.dart';

/// Wrapper widget to start a feature tutorial overlay
/// Uses the existing GuidedOverlay infrastructure
class FeatureTutorialOverlay extends StatelessWidget {
  final Widget child;
  final FeatureGuideModel guide;
  final Map<String, GlobalKey> targetKeys; // Map of step.target to GlobalKey
  final VoidCallback? onFinish;
  final VoidCallback? onSkip;

  const FeatureTutorialOverlay({
    Key? key,
    required this.child,
    required this.guide,
    required this.targetKeys,
    this.onFinish,
    this.onSkip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (guide.steps.isEmpty) {
      return child;
    }

    // Convert FeatureGuideStep to GuideStep
    final guideSteps = guide.steps
        .where((step) => targetKeys.containsKey(step.target))
        .map((step) {
      final targetKey = targetKeys[step.target]!;
      return GuideStep(
        targetKey: targetKey,
        description: step.description,
        fallbackAlignment: Alignment.center,
      );
    }).toList();

    // Use GuidedOverlay to display tutorial
    return Stack(
      children: [
        child,
        if (guideSteps.isNotEmpty)
          GuidedOverlay(
            steps: guideSteps,
            onFinish: onFinish ?? () {},
          ),
      ],
    );
  }

  /// Helper method to show tutorial for a specific feature
  static void showTutorial({
    required BuildContext context,
    required FeatureGuideModel guide,
    required Map<String, GlobalKey> targetKeys,
    VoidCallback? onFinish,
    VoidCallback? onSkip,
  }) {
    // Find target widgets and show showcase
    // This is a simplified version - full implementation would find and highlight widgets
    debugPrint(
        'FeatureTutorialOverlay: Starting tutorial for ${guide.featureName}');

    // TODO: Implement full showcase integration
    // For now, just show a dialog with steps
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(guide.featureName),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: guide.steps.length,
            itemBuilder: (context, index) {
              final step = guide.steps[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${index + 1}'),
                ),
                title: Text(step.title),
                subtitle: Text(step.description),
              );
            },
          ),
        ),
        actions: [
          if (onSkip != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onSkip();
              },
              child: const Text('Skip'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onFinish != null) onFinish();
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
