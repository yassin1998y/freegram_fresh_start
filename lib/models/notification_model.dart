import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  friendRequest,
  requestAccepted,
  superLike,
  nearbyWave,
  giftReceived, // Received a virtual gift
  comment, // Comment on post
  reaction, // Reaction to post
  mention, // Mentioned in post
}

class NotificationModel {
  final String id;
  final NotificationType type;
  final String fromUserId;
  final String fromUsername;
  final String? fromUserPhotoUrl;
  final String? postId;
  final String? commentId;
  final String? message;
  final String? giftId;
  final String? giftName;
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
    this.giftId,
    this.giftName,
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
      giftId: data['giftId'],
      giftName: data['giftName'] ?? data['giftId'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isRead: data['read'] ?? false,
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
      'giftId': giftId,
      'giftName': giftName,
      'timestamp': timestamp,
      'read': isRead,
    };
  }

  static NotificationType _stringToNotificationType(String typeStr) {
    switch (typeStr) {
      case 'friend_request_received':
      case 'friendRequest':
        return NotificationType.friendRequest;
      case 'request_accepted':
      case 'requestAccepted':
        return NotificationType.requestAccepted;
      case 'super_like':
      case 'superLike':
        return NotificationType.superLike;
      case 'nearbyWave':
        return NotificationType.nearbyWave;
      case 'gift_received':
      case 'giftReceived':
        return NotificationType.giftReceived;
      case 'comment':
        return NotificationType.comment;
      case 'reaction':
        return NotificationType.reaction;
      case 'mention':
        return NotificationType.mention;
      default:
        return NotificationType.friendRequest;
    }
  }
}
