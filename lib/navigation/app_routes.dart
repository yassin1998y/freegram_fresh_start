// lib/navigation/app_routes.dart

/// Professional Route Names with Type Safety
/// All route names are defined as constants for easy refactoring
class AppRoutes {
  // Prevent instantiation
  AppRoutes._();

  // Auth Routes
  static const String login = '/login';
  static const String signup = '/signup';
  static const String onboarding = '/onboarding';

  // Main App Routes
  static const String main = '/main';
  static const String nearby = '/nearby';
  static const String feed = '/feed';
  static const String createPost = '/createPost';
  static const String match = '/match';
  static const String friends = '/friends';
  static const String menu = '/menu';

  // Profile Routes
  static const String profile = '/profile';
  static const String editProfile = '/editProfile';
  static const String qrDisplay = '/qrDisplay';

  // Chat Routes
  static const String chatList = '/chatList';
  static const String chat = '/chat';
  static const String nearbyChatList = '/nearbyChatList';
  static const String nearbyChat = '/nearbyChat';

  // Settings Routes
  static const String settings = '/settings';
  static const String notificationSettings = '/notificationSettings';
  static const String notifications = '/notifications';

  // Other Routes
  static const String store = '/store';
  static const String wishlist = '/wishlist';
  static const String boostPost = '/boostPost';
  static const String inventory = '/inventory';
  static const String referral = '/referral';
  static const String matchAnimation = '/matchAnimation';

  // Gift Routes
  static const String giftSendSelection = '/giftSendSelection';
  static const String giftSendComposer = '/gift-send-composer';
  static const String giftSendFriendPicker = '/gift-send-friend-picker';

  // Reels Routes
  static const String reels = '/reels';
  static const String createReel = '/createReel';

  // Story Routes
  static const String storyCreator = '/storyCreator';
  static const String textStoryCreator = '/textStoryCreator';
  // Social & Discovery
  static const String hashtagExplore = '/hashtagExplore';
  static const String search = '/search';
  static const String locationPicker = '/locationPicker';
  static const String mentionedPosts = '/mentionedPosts';

  // Media & Viewer
  static const String postDetail = '/postDetail';
  static const String storyViewer = '/storyViewer';
  static const String imageGallery = '/imageGallery';
  static const String videoPlayer = '/videoPlayer';

  // Gifting Economy
  static const String marketplace = '/marketplace';
  static const String categoryBrowse = '/categoryBrowse';
  static const String giftHistory = '/giftHistory';
  static const String giftDetail = '/giftDetail';
  static const String limitedEditions = '/limitedEditions';

  // Admin & Analytics
  static const String analyticsDashboard = '/analyticsDashboard';
  static const String moderationDashboard = '/moderationDashboard';
  static const String boostAnalytics = '/boostAnalytics';
  static const String report = '/report';

  // Specialized Hubs
  static const String leaderboard = '/leaderboard';
  static const String achievements = '/achievements';
  static const String dailyRewards = '/dailyRewards';
  static const String pageProfile = '/pageProfile';
  static const String pageSettings = '/pageSettings';
  static const String pageAnalytics = '/pageAnalytics';

  // General Utilities
  static const String featureDiscovery = '/featureDiscovery';
  static const String createPage = '/createPage';
}

/// Type-safe route arguments
/// Use these classes to pass arguments between screens
class RouteArguments {
  // Prevent instantiation
  RouteArguments._();
}

/// Profile Screen Arguments
class ProfileArguments {
  final String userId;
  final String? heroTag; // For hero animations

  const ProfileArguments({
    required this.userId,
    this.heroTag,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      if (heroTag != null) 'heroTag': heroTag,
    };
  }

  factory ProfileArguments.fromMap(Map<String, dynamic>? map) {
    return ProfileArguments(
      userId: map?['userId'] as String? ?? '',
      heroTag: map?['heroTag'] as String?,
    );
  }
}

/// Chat Screen Arguments
class ChatArguments {
  final String chatId;
  final String otherUserId;
  final String? otherUsername;
  final String? otherPhotoUrl;

  const ChatArguments({
    required this.chatId,
    required this.otherUserId,
    this.otherUsername,
    this.otherPhotoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'otherUserId': otherUserId,
      if (otherUsername != null) 'otherUsername': otherUsername,
      if (otherPhotoUrl != null) 'otherPhotoUrl': otherPhotoUrl,
    };
  }

  factory ChatArguments.fromMap(Map<String, dynamic>? map) {
    return ChatArguments(
      chatId: map?['chatId'] as String? ?? '',
      otherUserId: map?['otherUserId'] as String? ?? '',
      otherUsername: map?['otherUsername'] as String?,
      otherPhotoUrl: map?['otherPhotoUrl'] as String?,
    );
  }
}

/// Edit Profile Arguments
class EditProfileArguments {
  final Map<String, dynamic> currentUserData;
  final bool isCompletingProfile;

  const EditProfileArguments({
    required this.currentUserData,
    this.isCompletingProfile = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'currentUserData': currentUserData,
      'isCompletingProfile': isCompletingProfile,
    };
  }

  factory EditProfileArguments.fromMap(Map<String, dynamic>? map) {
    return EditProfileArguments(
      currentUserData: map?['currentUserData'] as Map<String, dynamic>? ?? {},
      isCompletingProfile: map?['isCompletingProfile'] as bool? ?? false,
    );
  }
}

/// Match Animation Arguments
class MatchAnimationArguments {
  final String matchedUserId;
  final String matchedUsername;
  final String? matchedPhotoUrl;

  const MatchAnimationArguments({
    required this.matchedUserId,
    required this.matchedUsername,
    this.matchedPhotoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'matchedUserId': matchedUserId,
      'matchedUsername': matchedUsername,
      if (matchedPhotoUrl != null) 'matchedPhotoUrl': matchedPhotoUrl,
    };
  }

  factory MatchAnimationArguments.fromMap(Map<String, dynamic>? map) {
    return MatchAnimationArguments(
      matchedUserId: map?['matchedUserId'] as String? ?? '',
      matchedUsername: map?['matchedUsername'] as String? ?? '',
      matchedPhotoUrl: map?['matchedPhotoUrl'] as String?,
    );
  }
}

/// Post Detail Arguments
class PostDetailArguments {
  final String postId;

  const PostDetailArguments({required this.postId});
}

/// Hashtag Explore Arguments
class HashtagExploreArguments {
  final String hashtag;

  const HashtagExploreArguments({required this.hashtag});
}

/// Category Browse Arguments
class CategoryBrowseArguments {
  final dynamic
      category; // Using dynamic to avoid circular dependency, usually GiftCategory

  const CategoryBrowseArguments({required this.category});
}

/// Gift Detail Arguments
class GiftDetailArguments {
  final dynamic
      gift; // Using dynamic to avoid circular dependency, usually GiftModel

  const GiftDetailArguments({required this.gift});
}

/// Video Player Arguments
class VideoPlayerArguments {
  final dynamic mediaItem; // MediaItem model
  final Duration? initialPosition;

  const VideoPlayerArguments({
    required this.mediaItem,
    this.initialPosition,
  });
}

/// Image Gallery Arguments
class ImageGalleryArguments {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageGalleryArguments({
    required this.imageUrls,
    this.initialIndex = 0,
  });
}

/// Report Arguments
class ReportArguments {
  final String contentId;
  final dynamic contentType; // ReportContentType enum

  const ReportArguments({
    required this.contentId,
    required this.contentType,
  });
}

/// Boost Analytics Arguments
class BoostAnalyticsArguments {
  final dynamic post; // PostModel

  const BoostAnalyticsArguments({required this.post});
}

/// Page Profile Arguments
class PageProfileArguments {
  final String pageId;

  const PageProfileArguments({required this.pageId});
}

/// Page Settings Arguments
class PageSettingsArguments {
  final String pageId;

  const PageSettingsArguments({required this.pageId});
}

/// Story Viewer Arguments
class StoryViewerArguments {
  final String startingUserId;

  const StoryViewerArguments({
    required this.startingUserId,
  });
}

class BoostPostArguments {
  final dynamic post; // PostModel

  const BoostPostArguments({required this.post});
}
