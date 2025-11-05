// lib/models/feature_guide_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum FeatureDifficulty { easy, medium, advanced }

class FeatureGuideStep extends Equatable {
  final String title;
  final String description;
  final String action; // 'tap_button', 'swipe', 'long_press', 'navigate'
  final String target; // Button/feature identifier

  const FeatureGuideStep({
    required this.title,
    required this.description,
    required this.action,
    required this.target,
  });

  factory FeatureGuideStep.fromMap(Map<String, dynamic> map) {
    return FeatureGuideStep(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      action: map['action'] ?? 'tap_button',
      target: map['target'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'action': action,
      'target': target,
    };
  }

  @override
  List<Object?> get props => [title, description, action, target];
}

class FeatureGuideModel extends Equatable {
  final String featureId;
  final String featureName;
  final String
      category; // 'posting', 'discovery', 'engagement', 'monetization', 'management'
  final String description;
  final String icon; // Icon name or emoji
  final String? videoUrl; // Optional tutorial video
  final List<String> screenshotUrls;
  final List<FeatureGuideStep> steps;
  final List<String> relatedFeatures; // Other feature IDs
  final FeatureDifficulty difficulty;
  final int estimatedTime; // Minutes

  const FeatureGuideModel({
    required this.featureId,
    required this.featureName,
    required this.category,
    required this.description,
    required this.icon,
    this.videoUrl,
    this.screenshotUrls = const [],
    this.steps = const [],
    this.relatedFeatures = const [],
    this.difficulty = FeatureDifficulty.easy,
    this.estimatedTime = 5,
  });

  factory FeatureGuideModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FeatureGuideModel.fromMap(doc.id, data);
  }

  factory FeatureGuideModel.fromMap(String id, Map<String, dynamic> data) {
    final stepsData = data['steps'] as List<dynamic>? ?? [];
    final steps = stepsData
        .map((step) => FeatureGuideStep.fromMap(step as Map<String, dynamic>))
        .toList();

    return FeatureGuideModel(
      featureId: id,
      featureName: data['featureName'] ?? '',
      category: data['category'] ?? 'posting',
      description: data['description'] ?? '',
      icon: data['icon'] ?? '📱',
      videoUrl: data['videoUrl'] as String?,
      screenshotUrls: List<String>.from(data['screenshotUrls'] ?? []),
      steps: steps,
      relatedFeatures: List<String>.from(data['relatedFeatures'] ?? []),
      difficulty: _stringToDifficulty(data['difficulty'] ?? 'easy'),
      estimatedTime: (data['estimatedTime'] ?? 5) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'featureId': featureId,
      'featureName': featureName,
      'category': category,
      'description': description,
      'icon': icon,
      'videoUrl': videoUrl,
      'screenshotUrls': screenshotUrls,
      'steps': steps.map((step) => step.toMap()).toList(),
      'relatedFeatures': relatedFeatures,
      'difficulty': _difficultyToString(difficulty),
      'estimatedTime': estimatedTime,
    };
  }

  FeatureGuideModel copyWith({
    String? featureId,
    String? featureName,
    String? category,
    String? description,
    String? icon,
    String? videoUrl,
    List<String>? screenshotUrls,
    List<FeatureGuideStep>? steps,
    List<String>? relatedFeatures,
    FeatureDifficulty? difficulty,
    int? estimatedTime,
  }) {
    return FeatureGuideModel(
      featureId: featureId ?? this.featureId,
      featureName: featureName ?? this.featureName,
      category: category ?? this.category,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      videoUrl: videoUrl ?? this.videoUrl,
      screenshotUrls: screenshotUrls ?? this.screenshotUrls,
      steps: steps ?? this.steps,
      relatedFeatures: relatedFeatures ?? this.relatedFeatures,
      difficulty: difficulty ?? this.difficulty,
      estimatedTime: estimatedTime ?? this.estimatedTime,
    );
  }

  static FeatureDifficulty _stringToDifficulty(String str) {
    switch (str.toLowerCase()) {
      case 'easy':
        return FeatureDifficulty.easy;
      case 'medium':
        return FeatureDifficulty.medium;
      case 'advanced':
        return FeatureDifficulty.advanced;
      default:
        return FeatureDifficulty.easy;
    }
  }

  static String _difficultyToString(FeatureDifficulty difficulty) {
    switch (difficulty) {
      case FeatureDifficulty.easy:
        return 'easy';
      case FeatureDifficulty.medium:
        return 'medium';
      case FeatureDifficulty.advanced:
        return 'advanced';
    }
  }

  @override
  List<Object?> get props => [
        featureId,
        featureName,
        category,
        description,
        icon,
        videoUrl,
        screenshotUrls,
        steps,
        relatedFeatures,
        difficulty,
        estimatedTime,
      ];
}
