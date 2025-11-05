// lib/models/story_tray_data_model.dart

import 'package:equatable/equatable.dart';
import 'package:freegram/models/story_media_model.dart';

/// Data model for the story tray with proper sorting
class StoryTrayData extends Equatable {
  final StoryMedia? myStory;
  final List<StoryMedia> unreadStories;
  final List<StoryMedia> seenStories;

  // Additional metadata for UI
  final Map<String, String> userAvatars; // userId -> avatarUrl
  final Map<String, String> usernames; // userId -> username

  const StoryTrayData({
    this.myStory,
    required this.unreadStories,
    required this.seenStories,
    required this.userAvatars,
    required this.usernames,
  });

  @override
  List<Object?> get props => [
        myStory,
        unreadStories,
        seenStories,
        userAvatars,
        usernames,
      ];
}
