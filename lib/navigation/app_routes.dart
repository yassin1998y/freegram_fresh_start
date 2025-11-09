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
  static const String matchAnimation = '/matchAnimation';
  
  // Reels Routes
  static const String reels = '/reels';
  static const String createReel = '/createReel';

  // Story Routes
  static const String storyCreator = '/storyCreator';
  static const String textStoryCreator = '/textStoryCreator';
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
