// lib/models/notification_preferences.dart
// Bug #37: Notification preferences model
// TODO: Add to UserModel when implementing notification settings

class NotificationPreferences {
  final bool friendRequestsEnabled;
  final bool friendAcceptedEnabled;
  final bool messagesEnabled;
  final bool nearbyWavesEnabled;
  final bool superLikesEnabled;
  final bool allNotificationsEnabled;

  // Post Notifications
  final bool likesEnabled;
  final bool commentsEnabled;
  final bool mentionsEnabled;

  // Reel Notifications
  final bool reelLikesEnabled;
  final bool reelCommentsEnabled;

  // System
  final bool batchingEnabled;

  const NotificationPreferences({
    this.friendRequestsEnabled = true,
    this.friendAcceptedEnabled = true,
    this.messagesEnabled = true,
    this.nearbyWavesEnabled = true,
    this.superLikesEnabled = true,
    this.allNotificationsEnabled = true,
    this.likesEnabled = true,
    this.commentsEnabled = true,
    this.mentionsEnabled = true,
    this.reelLikesEnabled = true,
    this.reelCommentsEnabled = true,
    this.batchingEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'friendRequestsEnabled': friendRequestsEnabled,
      'friendAcceptedEnabled': friendAcceptedEnabled,
      'messagesEnabled': messagesEnabled,
      'nearbyWavesEnabled': nearbyWavesEnabled,
      'superLikesEnabled': superLikesEnabled,
      'allNotificationsEnabled': allNotificationsEnabled,
      'likesEnabled': likesEnabled,
      'commentsEnabled': commentsEnabled,
      'mentionsEnabled': mentionsEnabled,
      'reelLikesEnabled': reelLikesEnabled,
      'reelCommentsEnabled': reelCommentsEnabled,
      'batchingEnabled': batchingEnabled,
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      friendRequestsEnabled: map['friendRequestsEnabled'] ?? true,
      friendAcceptedEnabled: map['friendAcceptedEnabled'] ?? true,
      messagesEnabled: map['messagesEnabled'] ?? true,
      nearbyWavesEnabled: map['nearbyWavesEnabled'] ?? true,
      superLikesEnabled: map['superLikesEnabled'] ?? true,
      allNotificationsEnabled: map['allNotificationsEnabled'] ?? true,
      likesEnabled: map['likesEnabled'] ?? true,
      commentsEnabled: map['commentsEnabled'] ?? true,
      mentionsEnabled: map['mentionsEnabled'] ?? true,
      reelLikesEnabled: map['reelLikesEnabled'] ?? true,
      reelCommentsEnabled: map['reelCommentsEnabled'] ?? true,
      batchingEnabled: map['batchingEnabled'] ?? true,
    );
  }

  bool shouldSendNotification(String notificationType) {
    if (!allNotificationsEnabled) return false;

    switch (notificationType) {
      case 'friendRequest':
        return friendRequestsEnabled;
      case 'requestAccepted':
        return friendAcceptedEnabled;
      case 'message':
        return messagesEnabled;
      case 'nearbyWave':
        return nearbyWavesEnabled;
      case 'superLike':
        return superLikesEnabled;
      case 'like':
      case 'reaction':
        return likesEnabled;
      case 'comment':
        return commentsEnabled;
      case 'mention':
        return mentionsEnabled;
      case 'reelLike':
        return reelLikesEnabled;
      case 'reelComment':
        return reelCommentsEnabled;
      default:
        return true;
    }
  }
}
