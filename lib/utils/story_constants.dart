// lib/utils/story_constants.dart

/// Constants for Story creation and display
class StoryConstants {
  StoryConstants._(); // Private constructor to prevent instantiation

  // Story dimensions (9:16 aspect ratio, vertical)
  static const double storyWidth = 1080.0;
  static const double storyHeight = 1920.0;

  // Story video max duration (seconds)
  static const int maxVideoDurationSeconds = 20;

  // Story expiration (hours)
  static const int storyExpirationHours = 24;

  // Text story font size
  static const double textStoryFontSize = 72.0;

  // Text story padding
  static const double textStoryPadding = 160.0;
}
