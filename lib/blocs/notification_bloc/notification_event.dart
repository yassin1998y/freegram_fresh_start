// lib/blocs/notification_event.dart
part of 'notification_bloc.dart'; // Links to notification_bloc.dart

@immutable
abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object> get props => [];
}

/// Event to trigger loading notifications for the current user.
class LoadNotifications extends NotificationEvent {}

/// Event to mark a specific notification as read.
class MarkNotificationAsRead extends NotificationEvent {
  final String notificationId;

  const MarkNotificationAsRead(this.notificationId);

  @override
  List<Object> get props => [notificationId];
}

// --- Added Event for Fix #6 ---
/// Event to trigger marking all unread notifications as read.
class MarkAllNotificationsAsRead extends NotificationEvent {}
// --- END: Added Event ---


/// Internal event used by the BLoC when the notification stream provides updates.
class _NotificationsUpdated extends NotificationEvent {
  final List<NotificationModel> notifications;

  const _NotificationsUpdated(this.notifications);

  @override
  List<Object> get props => [notifications];
}
