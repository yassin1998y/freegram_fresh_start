part of 'notification_bloc.dart';

@immutable
abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object> get props => [];
}

/// Event to load all notifications for the current user.
class LoadNotifications extends NotificationEvent {}

/// Event to mark a single notification as read.
class MarkNotificationAsRead extends NotificationEvent {
  final String notificationId;

  const MarkNotificationAsRead(this.notificationId);

  @override
  List<Object> get props => [notificationId];
}

/// Internal event triggered when the notification stream pushes an update.
class _NotificationsUpdated extends NotificationEvent {
  final List<NotificationModel> notifications;

  const _NotificationsUpdated(this.notifications);

  @override
  List<Object> get props => [notifications];
}
