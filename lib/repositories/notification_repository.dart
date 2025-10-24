import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/notification_model.dart'; // Keep NotificationModel import
import 'package:flutter/foundation.dart'; // Import for debugPrint

/// A repository dedicated to handling all user notification operations.
class NotificationRepository {
  final FirebaseFirestore _db;

  NotificationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Adds a new notification to a user's subcollection.
  /// Ensure the 'type' string matches one of the remaining NotificationType enum values.
  Future<void> addNotification({
    required String userId,
    required String type, // Should be 'friendRequest', 'requestAccepted', 'superLike', or 'nearbyWave'
    required String fromUsername,
    required String fromUserId,
    String? fromUserPhotoUrl,
    String? postId, // Keep for context? (e.g., if superLike was on a profile vs post)
    String? postImageUrl, // Keep for context?
    String? commentText, // Keep for context?
    String? message, // Keep for wave message
  }) {
    // Basic validation for type based on remaining enums
    // Use NotificationType enum directly for better type safety if possible
    final validTypesAsString = NotificationType.values.map((e) => e.name).toList();
    // Also allow legacy strings if necessary
    validTypesAsString.addAll(['friend_request_received', 'request_accepted', 'super_like']);

    if (!validTypesAsString.contains(type)) {
      debugPrint("NotificationRepository Warning: Attempted to add notification with invalid type: $type");
      // Optionally throw an error or just return to prevent adding invalid types
      // throw ArgumentError("Invalid notification type: $type");
      return Future.value(); // Silently ignore invalid types for now
    }

    // Map legacy types to current enum string representation before saving
    String finalTypeString = type;
    if (type == 'friend_request_received') finalTypeString = NotificationType.friendRequest.name;
    if (type == 'request_accepted') finalTypeString = NotificationType.requestAccepted.name;
    if (type == 'super_like') finalTypeString = NotificationType.superLike.name;


    final data = <String, dynamic>{
      'type': finalTypeString, // Save the corrected type string
      'fromUsername': fromUsername,
      'fromUserId': fromUserId,
      'fromUserPhotoUrl': fromUserPhotoUrl,
      'postId': postId,
      'postImageUrl': postImageUrl,
      'commentText': commentText,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false, // Default to unread
    };
    // Remove null values to keep Firestore documents cleaner
    data.removeWhere((key, value) => value == null);

    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add(data);
  }


  // getNotificationsStream remains the same (relies on NotificationModel.fromFirestore)
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(50) // Keep limit for performance
        .snapshots()
        .map((snapshot) {
      // Filter out notifications with types that no longer exist in the enum, if necessary
      // Although _stringToNotificationType handles defaults, you might want stricter filtering here.
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
      // Optional: Filter based on valid types if _stringToNotificationType default is not desired
      // .where((notification) => NotificationType.values.contains(notification.type))
          .toList();
    });
  }

  // getUnreadNotificationCountStream remains the same
  Stream<int> getUnreadNotificationCountStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length); // Count unread documents
  }

  // markNotificationAsRead remains the same
  Future<void> markNotificationAsRead(String userId, String notificationId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  // markAllNotificationsAsRead remains the same
  Future<bool> markAllNotificationsAsRead(String userId) async {
    final notificationsRef =
    _db.collection('users').doc(userId).collection('notifications');
    // Get only unread notifications
    final unreadNotifications =
    await notificationsRef.where('read', isEqualTo: false).get();
    if (unreadNotifications.docs.isEmpty) return false; // No unread notifications

    // Use a batch write for efficiency
    final batch = _db.batch();
    for (var doc in unreadNotifications.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
    return true; // Indicate that notifications were marked as read
  }
}