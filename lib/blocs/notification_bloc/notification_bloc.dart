import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/notification_model.dart';
import 'package:freegram/repositories/notification_repository.dart';
import 'package:meta/meta.dart';

part 'notification_event.dart';
part 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository _notificationRepository;
  final FirebaseAuth _firebaseAuth;
  StreamSubscription? _notificationsSubscription;

  NotificationBloc({
    required NotificationRepository notificationRepository,
    FirebaseAuth? firebaseAuth,
  })  : _notificationRepository = notificationRepository,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        super(NotificationInitial()) {
    on<LoadNotifications>(_onLoadNotifications);
    on<_NotificationsUpdated>(_onNotificationsUpdated);
    on<MarkNotificationAsRead>(_onMarkNotificationAsRead);
  }

  void _onLoadNotifications(
      LoadNotifications event, Emitter<NotificationState> emit) {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      emit(const NotificationError("User not authenticated."));
      return;
    }

    emit(NotificationLoading());
    _notificationsSubscription?.cancel();
    _notificationsSubscription =
        _notificationRepository.getNotificationsStream(user.uid).listen(
              (notifications) {
            add(_NotificationsUpdated(notifications));
          },
          onError: (error) {
            emit(NotificationError(error.toString()));
          },
        );
  }

  void _onNotificationsUpdated(
      _NotificationsUpdated event, Emitter<NotificationState> emit) {
    emit(NotificationLoaded(event.notifications));
  }

  Future<void> _onMarkNotificationAsRead(
      MarkNotificationAsRead event, Emitter<NotificationState> emit) async {
    final user = _firebaseAuth.currentUser;
    if (user != null && state is NotificationLoaded) {
      final currentState = state as NotificationLoaded;

      // [FIX #15] Optimistically update the UI before the database call.
      // 1. Create a new list of notifications from the current state.
      final updatedNotifications = List<NotificationModel>.from(currentState.notifications);

      // 2. Find the index of the notification that was read.
      final index = updatedNotifications.indexWhere((n) => n.id == event.notificationId);

      // 3. If found, create a new 'read' version of it and replace it in the list.
      if (index != -1) {
        final oldNotification = updatedNotifications[index];
        updatedNotifications[index] = NotificationModel(
          id: oldNotification.id,
          type: oldNotification.type,
          fromUserId: oldNotification.fromUserId,
          fromUsername: oldNotification.fromUsername,
          fromUserPhotoUrl: oldNotification.fromUserPhotoUrl,
          postId: oldNotification.postId,
          commentId: oldNotification.commentId,
          message: oldNotification.message,
          timestamp: oldNotification.timestamp,
          isRead: true, // The only change
        );

        // 4. Immediately emit the new state so the UI updates instantly.
        emit(NotificationLoaded(updatedNotifications));
      }

      // 5. Now, update the database in the background. The UI won't wait for this.
      await _notificationRepository.markNotificationAsRead(
          user.uid, event.notificationId);
    }
  }

  @override
  Future<void> close() {
    _notificationsSubscription?.cancel();
    return super.close();
  }
}