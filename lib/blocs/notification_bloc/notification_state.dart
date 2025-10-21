part of 'notification_bloc.dart';

@immutable
abstract class NotificationState extends Equatable {
  const NotificationState();

  @override
  List<Object> get props => [];
}

/// The initial state before any notifications are loaded.
class NotificationInitial extends NotificationState {}

/// The state when notifications are being loaded.
class NotificationLoading extends NotificationState {}

/// The state when notifications have been successfully loaded.
class NotificationLoaded extends NotificationState {
  final List<NotificationModel> notifications;

  const NotificationLoaded(this.notifications);

  @override
  List<Object> get props => [notifications];
}

/// The state when an error occurs while loading notifications.
class NotificationError extends NotificationState {
  final String message;

  const NotificationError(this.message);

  @override
  List<Object> get props => [message];
}
