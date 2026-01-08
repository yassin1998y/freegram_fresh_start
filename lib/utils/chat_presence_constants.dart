import 'package:flutter/material.dart';

/// Chat Presence Constants
///
/// Centralized configuration for presence/online status, last seen timing,
/// and all related thresholds for professional chat UX.

class ChatPresenceConstants {
  // Private constructor to prevent instantiation
  ChatPresenceConstants._();

  // ========== PRESENCE STATES ==========
  /// User is actively using the app (foreground, interacting)
  static const String stateActive = 'active';

  /// User has app open but may be idle
  static const String stateOnline = 'online';

  /// User recently backgrounded the app (< 5 min)
  static const String stateAway = 'away';

  /// User is fully offline
  static const String stateOffline = 'offline';

  // ========== TIMING THRESHOLDS ==========

  /// How often to send heartbeat updates while app is active (30 seconds)
  static const Duration heartbeatInterval = Duration(seconds: 30);

  /// Debounce presence updates to avoid spam (10 seconds minimum between updates)
  static const Duration presenceDebounce = Duration(seconds: 10);

  /// Time before user is considered "away" after backgrounding (5 minutes)
  static const Duration awayThreshold = Duration(minutes: 5);

  /// Maximum age for "active now" display (2 minutes)
  static const Duration activeNowThreshold = Duration(minutes: 2);

  /// Maximum age for "just seen" display (5 minutes)
  static const Duration justSeenThreshold = Duration(minutes: 5);

  /// Timeout for considering user offline if no heartbeat (2 minutes)
  static const Duration offlineTimeout = Duration(minutes: 2);

  /// Retry delay after failed presence update (5 seconds)
  static const Duration retryDelay = Duration(seconds: 5);

  /// Maximum retries for failed presence updates
  static const int maxRetries = 3;

  // ========== DISPLAY THRESHOLDS ==========

  /// Show "Active now" if last seen < 2 minutes AND presence = true
  static const Duration displayActiveNow = Duration(minutes: 2);

  /// Show "Active Xm ago" for 2-60 minutes
  static const Duration displayMinutesThreshold = Duration(hours: 1);

  /// Show "Active Xh ago" for 1-24 hours
  static const Duration displayHoursThreshold = Duration(hours: 24);

  /// Show "Active X days ago" for 1-7 days
  static const Duration displayDaysThreshold = Duration(days: 7);

  /// Show actual date/time for > 7 days
  static const Duration displayDateThreshold = Duration(days: 7);

  // ========== LABELS ==========

  static const String labelActiveNow = 'Active now';
  static const String labelJustNow = 'Just now';
  static const String labelOnline = 'Online';
  static const String labelTyping = 'typing...';
  static const String labelAway = 'Away';
  static const String labelOffline = 'Offline';
  static const String labelLastSeen = 'last seen';
  static const String labelLastActive = 'last active';

  // ========== COLORS ==========

  static const Color activeColor = Color(0xFF4CAF50); // Green
  static const Color onlineColor = Color(0xFF4CAF50); // Green
  static const Color awayColor = Color(0xFFFFA726); // Orange
  static const Color offlineColor = Color(0xFF9E9E9E); // Gray
  static const Color typingColor = Color(0xFF2196F3); // Blue

  // ========== SIZES ==========

  static const double onlineIndicatorSize = 12.0;
  static const double onlineIndicatorBorderWidth = 2.0;
  static const double onlineIndicatorShadowBlur = 4.0;
  static const double lastSeenBadgePadding = 4.0;
  static const double lastSeenBadgeFontSize = 8.0;

  // ========== ANIMATIONS ==========

  static const Duration statusTransitionDuration = Duration(milliseconds: 300);
  static const Duration pulseAnimationDuration = Duration(milliseconds: 1500);
  static const Duration shimmerDuration = Duration(milliseconds: 1000);

  // ========== PRIVACY SETTINGS ==========

  static const String privacyEveryone = 'everyone';
  static const String privacyFriendsOnly = 'friends_only';
  static const String privacyNobody = 'nobody';

  // ========== CACHING ==========

  /// Cache presence data for this duration to reduce Firestore reads
  static const Duration presenceCacheDuration = Duration(minutes: 1);

  /// Maximum number of presence states to cache in memory
  static const int maxCachedPresenceStates = 100;

  // ========== PLATFORM SPECIFIC ==========

  /// iOS background task interval (minimum allowed is 15 minutes)
  static const Duration iosBackgroundInterval = Duration(minutes: 15);

  /// Android WorkManager interval for doze mode
  static const Duration androidWorkInterval = Duration(minutes: 15);

  /// Web visibility check interval
  static const Duration webVisibilityCheckInterval = Duration(seconds: 30);

  // ========== FIRESTORE PATHS ==========

  static const String usersCollection = 'users';
  static const String presenceField = 'presence';
  static const String lastSeenField = 'lastSeen';
  static const String presenceStateField = 'presenceState';
  static const String lastHeartbeatField = 'lastHeartbeat';

  // ========== RTDB PATHS ==========

  static const String rtdbStatusPath = 'status';

  // ========== ERROR MESSAGES ==========

  static const String errorUpdateFailed = 'Failed to update presence';
  static const String errorNetworkUnavailable = 'Network unavailable';
  static const String errorPermissionDenied = 'Permission denied';
  static const String errorUnknown = 'Unknown error occurred';

  // ========== ACCESSIBILITY ==========

  static const String semanticOnline = 'User is online';
  static const String semanticOffline = 'User is offline';
  static const String semanticAway = 'User is away';
  static const String semanticActive = 'User is active';
  static const String semanticTyping = 'User is typing';
  static const String semanticLastSeen = 'Last seen';

  // ========== NOTIFICATION SUPPRESSION ==========

  /// Don't notify if user was active within this duration
  static const Duration notificationSuppressDuration = Duration(minutes: 1);
}

/// Presence state enum for type safety
enum PresenceState {
  active,
  online,
  away,
  offline;

  String get label {
    switch (this) {
      case PresenceState.active:
        return ChatPresenceConstants.labelActiveNow;
      case PresenceState.online:
        return ChatPresenceConstants.labelOnline;
      case PresenceState.away:
        return ChatPresenceConstants.labelAway;
      case PresenceState.offline:
        return ChatPresenceConstants.labelOffline;
    }
  }

  Color get color {
    switch (this) {
      case PresenceState.active:
        return ChatPresenceConstants.activeColor;
      case PresenceState.online:
        return ChatPresenceConstants.onlineColor;
      case PresenceState.away:
        return ChatPresenceConstants.awayColor;
      case PresenceState.offline:
        return ChatPresenceConstants.offlineColor;
    }
  }

  static PresenceState fromString(String? value) {
    switch (value) {
      case 'active':
        return PresenceState.active;
      case 'online':
        return PresenceState.online;
      case 'away':
        return PresenceState.away;
      default:
        return PresenceState.offline;
    }
  }
}
