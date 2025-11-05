// lib/models/story_model.dart

import 'package:freegram/models/story_tray_item_model.dart';

/// Legacy model for backward compatibility
/// Use StoryTrayItem for new code
@Deprecated('Use StoryTrayItem instead')
class StoryModel {
  final String userId;
  final String username;
  final String userAvatarUrl;
  final bool hasNewContent;

  const StoryModel({
    required this.userId,
    required this.username,
    required this.userAvatarUrl,
    this.hasNewContent = false,
  });

  /// Convert to StoryTrayItem
  StoryTrayItem toStoryTrayItem() {
    return StoryTrayItem(
      userId: userId,
      username: username,
      userAvatarUrl: userAvatarUrl,
      hasUnreadStory: hasNewContent,
      storyCount: hasNewContent ? 1 : 0,
    );
  }

  /// Create from StoryTrayItem
  factory StoryModel.fromStoryTrayItem(StoryTrayItem item) {
    return StoryModel(
      userId: item.userId,
      username: item.username,
      userAvatarUrl: item.userAvatarUrl,
      hasNewContent: item.hasUnreadStory,
    );
  }
}
