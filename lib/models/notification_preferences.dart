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

  const NotificationPreferences({
    this.friendRequestsEnabled = true,
    this.friendAcceptedEnabled = true,
    this.messagesEnabled = true,
    this.nearbyWavesEnabled = true,
    this.superLikesEnabled = true,
    this.allNotificationsEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'friendRequestsEnabled': friendRequestsEnabled,
      'friendAcceptedEnabled': friendAcceptedEnabled,
      'messagesEnabled': messagesEnabled,
      'nearbyWavesEnabled': nearbyWavesEnabled,
      'superLikesEnabled': superLikesEnabled,
      'allNotificationsEnabled': allNotificationsEnabled,
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
      default:
        return true;
    }
  }
}
