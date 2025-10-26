// lib/blocs/notification_bloc.dart
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:freegram/models/notification_model.dart';
import 'package:freegram/repositories/notification_repository.dart';
import 'package:meta/meta.dart';

// Link event and state files
part 'notification_event.dart';
part 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository _notificationRepository;
  final FirebaseAuth _firebaseAuth;
  StreamSubscription? _notificationsSubscription; // Subscription to Firestore stream
  final Set<String> _processingNotifications = <String>{}; // Track notifications being processed

  NotificationBloc({
    required NotificationRepository notificationRepository,
    FirebaseAuth? firebaseAuth, // Allow injecting FirebaseAuth for testing
  })  : _notificationRepository = notificationRepository,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        super(NotificationInitial()) {
    // Register event handlers
    on<LoadNotifications>(_onLoadNotifications);
    on<_NotificationsUpdated>(_onNotificationsUpdated);
    on<MarkNotificationAsRead>(_onMarkNotificationAsRead);
    // --- Added Handler for Fix #6 ---
    on<MarkAllNotificationsAsRead>(_onMarkAllNotificationsAsRead);
    // --- END: Added Handler ---
  }

  // Handles the initial loading of notifications
  void _onLoadNotifications(
      LoadNotifications event, Emitter<NotificationState> emit) {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      emit(const NotificationError("User not authenticated."));
      return;
    }

    emit(NotificationLoading()); // Emit loading state
    _notificationsSubscription?.cancel(); // Cancel previous subscription if any
    // Subscribe to the notification stream from the repository
    _notificationsSubscription =
        _notificationRepository.getNotificationsStream(user.uid).listen(
              (notifications) {
            // When new data arrives, trigger an internal update event
            add(_NotificationsUpdated(notifications));
          },
          onError: (error) {
            // Handle errors from the stream
            emit(NotificationError(error.toString()));
          },
        );
  }

  // Handles updates received from the notification stream
  void _onNotificationsUpdated(
      _NotificationsUpdated event, Emitter<NotificationState> emit) {
    // Clear any notifications that are now marked as read from the stream
    // This prevents stale processing state
    for (final notification in event.notifications) {
      if (notification.isRead) {
        _processingNotifications.remove(notification.id);
      }
    }
    
    // Emit the loaded state with the new list of notifications
    emit(NotificationLoaded(event.notifications));
  }

  // Handles marking a single notification as read
  Future<void> _onMarkNotificationAsRead(
      MarkNotificationAsRead event, Emitter<NotificationState> emit) async {
    final user = _firebaseAuth.currentUser;
    
    // Prevent duplicate processing of the same notification
    if (_processingNotifications.contains(event.notificationId)) {
      debugPrint("NotificationBloc: Notification ${event.notificationId} is already being processed. Skipping.");
      return;
    }
    
    // Ensure user is logged in and state is loaded
    if (user != null && state is NotificationLoaded) {
      final currentState = state as NotificationLoaded;

      // Optimistically update the UI state immediately
      final updatedNotifications = List<NotificationModel>.from(currentState.notifications);
      final index = updatedNotifications.indexWhere((n) => n.id == event.notificationId);

      if (index != -1) {
        final oldNotification = updatedNotifications[index];
        // Only proceed if it's currently marked as unread
        if (!oldNotification.isRead) {
          // Mark as being processed
          _processingNotifications.add(event.notificationId);
          // Create an updated version of the notification marked as read
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
            isRead: true, // Mark as read
          );
          // Emit the updated state for instant UI feedback
          emit(NotificationLoaded(updatedNotifications));
          debugPrint("NotificationBloc: Optimistically marked ${event.notificationId} as read in state.");

          // Update the database in the background
          try {
            await _notificationRepository.markNotificationAsRead(
                user.uid, event.notificationId);
            debugPrint("NotificationBloc: Marked notification ${event.notificationId} as read in DB.");
            // No need to emit again on success, UI already updated
          } catch (e) {
            debugPrint("NotificationBloc: Error marking single notification as read in DB: $e. Reverting state.");
            // If DB update fails, revert the UI state back to the previous one
            emit(currentState);
            // Optionally emit an error state to inform the user
            // emit(NotificationError("Failed to mark notification as read"));
          } finally {
            // Always remove from processing set when done
            _processingNotifications.remove(event.notificationId);
          }
        } else {
          debugPrint("NotificationBloc: Notification ${event.notificationId} was already read. Skipping update.");
        }
      } else {
        debugPrint("NotificationBloc Warning: Could not find notification ${event.notificationId} in state to mark as read.");
      }
    }
  }

  // --- START: Handler for MarkAllNotificationsAsRead (Fix #6) ---
  // Handles marking all notifications as read
  Future<void> _onMarkAllNotificationsAsRead(
      MarkAllNotificationsAsRead event, Emitter<NotificationState> emit) async {
    final user = _firebaseAuth.currentUser;
    // Ensure user is logged in and state is loaded
    if (user != null && state is NotificationLoaded) {
      final currentState = state as NotificationLoaded;

      // Check if there are actually any unread notifications
      final bool hasUnread = currentState.notifications.any((n) => !n.isRead);
      if (!hasUnread) {
        debugPrint("NotificationBloc: No unread notifications to mark. Skipping.");
        return; // Nothing to do
      }

      // 1. Optimistically update UI state: Create a new list with everything marked as read
      final updatedNotifications = currentState.notifications.map((n) {
        // If already read, return the same object, otherwise create a new 'read' version
        return n.isRead ? n : NotificationModel(
          id: n.id,
          type: n.type,
          fromUserId: n.fromUserId,
          fromUsername: n.fromUsername,
          fromUserPhotoUrl: n.fromUserPhotoUrl,
          postId: n.postId,
          commentId: n.commentId,
          message: n.message,
          timestamp: n.timestamp,
          isRead: true, // Mark as read
        );
      }).toList();

      // 2. Emit the updated state for instant UI feedback
      emit(NotificationLoaded(updatedNotifications));
      debugPrint("NotificationBloc: Optimistically marked all as read in state.");

      // 3. Update the database in the background
      try {
        bool result = await _notificationRepository.markAllNotificationsAsRead(user.uid);
        if(result) {
          debugPrint("NotificationBloc: Marked all notifications as read in DB.");
        } else {
          // This might happen if notifications were marked read elsewhere between UI update and DB call
          debugPrint("NotificationBloc: markAllNotificationsAsRead repo call returned false (likely no unread found in DB).");
        }
        // No need to emit again on success
      } catch (e) {
        debugPrint("NotificationBloc: Error marking all notifications as read in DB: $e. Reverting state.");
        // If DB update fails, revert the UI state
        emit(currentState);
        // Optionally emit an error state
        // emit(NotificationError("Failed to mark all notifications as read"));
      }
    }
  }
  // --- END: Handler ---


  @override
  Future<void> close() {
    _notificationsSubscription?.cancel(); // Clean up stream subscription
    return super.close();
  }
}