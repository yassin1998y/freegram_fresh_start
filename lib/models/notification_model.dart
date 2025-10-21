import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  like,
  comment,
  follow,
  friendRequest,
  requestAccepted,
  superLike,
  // New types for Nearby interactions
  nearbyWave,
  gameInvite,
}

class NotificationModel {
  final String id;
  final NotificationType type;
  final String fromUserId;
  final String fromUsername;
  final String? fromUserPhotoUrl;
  final String? postId; // For like/comment on post
  final String? commentId; // For specific comment context
  final String? message; // Optional: for custom messages
  final Timestamp timestamp;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.type,
    required this.fromUserId,
    required this.fromUsername,
    this.fromUserPhotoUrl,
    this.postId,
    this.commentId,
    this.message,
    required this.timestamp,
    this.isRead = false,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      type: _stringToNotificationType(data['type'] ?? ''),
      fromUserId: data['fromUserId'] ?? '',
      fromUsername: data['fromUsername'] ?? '',
      fromUserPhotoUrl: data['fromUserPhotoUrl'],
      postId: data['postId'],
      commentId: data['commentId'],
      message: data['message'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.toString().split('.').last,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'fromUserPhotoUrl': fromUserPhotoUrl,
      'postId': postId,
      'commentId': commentId,
      'message': message,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }

  static NotificationType _stringToNotificationType(String typeStr) {
    switch (typeStr) {
      case 'like':
        return NotificationType.like;
      case 'comment':
        return NotificationType.comment;
      case 'follow':
        return NotificationType.follow;
      case 'friend_request_received':
      case 'friendRequest': // Allow for both for robustness
        return NotificationType.friendRequest;
      case 'request_accepted':
      case 'requestAccepted':
        return NotificationType.requestAccepted;
      case 'super_like':
      case 'superLike':
        return NotificationType.superLike;
      case 'nearbyWave':
        return NotificationType.nearbyWave;
      case 'gameInvite':
        return NotificationType.gameInvite;
      default:
        print('Unknown notification type: $typeStr, defaulting to follow.');
        return NotificationType.follow;
    }
  }
}