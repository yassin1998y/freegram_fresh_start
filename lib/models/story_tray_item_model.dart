// lib/models/story_tray_item_model.dart

import 'package:equatable/equatable.dart';

/// Model for displaying stories in the tray (horizontal list)
class StoryTrayItem extends Equatable {
  final String userId;
  final String username;
  final String userAvatarUrl;
  final bool hasUnreadStory;
  final int storyCount;

  const StoryTrayItem({
    required this.userId,
    required this.username,
    required this.userAvatarUrl,
    this.hasUnreadStory = false,
    this.storyCount = 0,
  });

  StoryTrayItem copyWith({
    String? userId,
    String? username,
    String? userAvatarUrl,
    bool? hasUnreadStory,
    int? storyCount,
  }) {
    return StoryTrayItem(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      hasUnreadStory: hasUnreadStory ?? this.hasUnreadStory,
      storyCount: storyCount ?? this.storyCount,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        username,
        userAvatarUrl,
        hasUnreadStory,
        storyCount,
      ];
}
