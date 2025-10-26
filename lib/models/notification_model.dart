import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  // like, // Removed
  // comment, // Removed
  // follow, // Removed
  friendRequest,
  requestAccepted,
  superLike, // Keep
  nearbyWave,
  // gameInvite, // Removed
}

class NotificationModel {
  final String id;
  final NotificationType type;
  final String fromUserId;
  final String fromUsername;
  final String? fromUserPhotoUrl;
  final String? postId; // Keep for potential future use or context? Or remove if truly unused.
  final String? commentId; // Keep for potential future use or context? Or remove if truly unused.
  final String? message; // Optional: for custom messages like waves
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
      postId: data['postId'], // Keep parsing if field might still exist
      commentId: data['commentId'], // Keep parsing if field might still exist
      message: data['message'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isRead: data['read'] ?? false, // Field is stored as 'read' in Firestore
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.toString().split('.').last, // Convert enum to string
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'fromUserPhotoUrl': fromUserPhotoUrl,
      'postId': postId,
      'commentId': commentId,
      'message': message,
      'timestamp': timestamp,
      'read': isRead, // Field is stored as 'read' in Firestore
    };
  }

  // Updated to remove deleted types
  static NotificationType _stringToNotificationType(String typeStr) {
    switch (typeStr) {
    // case 'like': return NotificationType.like; // Removed
    // case 'comment': return NotificationType.comment; // Removed
    // case 'follow': return NotificationType.follow; // Removed
      case 'friend_request_received': // Allow legacy string
      case 'friendRequest':
        return NotificationType.friendRequest;
      case 'request_accepted': // Allow legacy string
      case 'requestAccepted':
        return NotificationType.requestAccepted;
      case 'super_like': // Allow legacy string
      case 'superLike':
        return NotificationType.superLike; // Keep
      case 'nearbyWave':
        return NotificationType.nearbyWave;
    // case 'gameInvite': return NotificationType.gameInvite; // Removed
      default:
      // Default to friendRequest or throw an error if unknown type is critical
        print('Unknown notification type: $typeStr, defaulting to friendRequest.');
        return NotificationType.friendRequest;
    }
  }
}