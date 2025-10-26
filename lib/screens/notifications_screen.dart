// lib/screens/notifications_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Use alias for Bloc import to avoid naming conflicts
import 'package:freegram/blocs/notification_bloc/notification_bloc.dart' as Bloc;
import 'package:freegram/locator.dart';
import 'package:freegram/models/notification_model.dart';
import 'package:freegram/repositories/notification_repository.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatelessWidget {
  // --- Added parameters for Modal Bottom Sheet (Fix #5) ---
  final bool isModal; // Flag to indicate if shown in a modal
  final ScrollController? scrollController; // Controller for scrolling within modal

  const NotificationsScreen({
    super.key,
    this.isModal = false, // Default to not being modal
    this.scrollController,
  });
  // --- END: Added parameters ---


  @override
  Widget build(BuildContext context) {
    // Provide the NotificationBloc to the widget subtree
    return BlocProvider(
      create: (context) => Bloc.NotificationBloc( // Use alias
        notificationRepository: locator<NotificationRepository>(),
      )..add(Bloc.LoadNotifications()), // Load notifications initially (Use alias)
      // Conditionally wrap content with Scaffold based on isModal flag
      child: isModal
          ? _NotificationsView(scrollController: scrollController) // If modal, just return the view
          : Scaffold( // If not modal, provide Scaffold with AppBar
        body: Column(
          children: [
            // Header moved to body
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      "Notifications",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  // Actions moved to header
            // Button to mark all notifications as read
            BlocBuilder<Bloc.NotificationBloc, Bloc.NotificationState>( // Use alias
              builder: (context, state) {
                // Check if there are any unread notifications in the loaded state
                bool hasUnread = false;
                if (state is Bloc.NotificationLoaded) { // Use alias
                  hasUnread = state.notifications.any((n) => !n.isRead);
                }
                // Render the button, disable if no unread notifications
                return IconButton(
                  icon: const Icon(Icons.mark_chat_read_outlined),
                  tooltip: 'Mark All As Read',
                  // onPressed is null if 'hasUnread' is false, disabling the button
                  onPressed: hasUnread
                      ? () {
                    // Dispatch the event to the BLoC
                    context.read<Bloc.NotificationBloc>().add(Bloc.MarkAllNotificationsAsRead()); // Use alias
                  }
                      : null,
                );
              },
            ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _NotificationsView(scrollController: scrollController),
            ),
          ],
        ),
      ),
    );
  }
}

// Internal view widget containing the list
class _NotificationsView extends StatelessWidget {
  // --- Added parameter for Modal Bottom Sheet (Fix #5) ---
  final ScrollController? scrollController; // Accept optional controller

  const _NotificationsView({this.scrollController});
  // --- END: Added parameter ---

  @override
  Widget build(BuildContext context) {
    // Listens to NotificationBloc state to build the UI
    return BlocBuilder<Bloc.NotificationBloc, Bloc.NotificationState>( // Use alias
      builder: (context, state) {
        // Show loading indicator
        if (state is Bloc.NotificationLoading) { // Use alias
          return const Center(child: CircularProgressIndicator());
        }
        // Show error message
        if (state is Bloc.NotificationError) { // Use alias
          return Center(child: Text('Error: ${state.message}'));
        }
        // Show notification list if loaded
        if (state is Bloc.NotificationLoaded) { // Use alias
          final notifications = state.notifications;
          // Show empty state if no notifications
          if (notifications.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text("No Notifications Yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("Waves and friend requests will appear here.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            );
          }
          
          // Build the list with custom header for modal
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Custom header for modal with close and mark all buttons
                if (scrollController != null) // Only show header in modal
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Header row with title and buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Notifications',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              // Mark all as read button
                              BlocBuilder<Bloc.NotificationBloc, Bloc.NotificationState>(
                                builder: (context, state) {
                                  bool hasUnread = false;
                                  if (state is Bloc.NotificationLoaded) {
                                    hasUnread = state.notifications.any((n) => !n.isRead);
                                  }
                                  return IconButton(
                                    icon: Icon(
                                      Icons.mark_chat_read_outlined,
                                      color: hasUnread 
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                    ),
                                    tooltip: 'Mark All As Read',
                                    onPressed: hasUnread
                                        ? () {
                                            context.read<Bloc.NotificationBloc>().add(Bloc.MarkAllNotificationsAsRead());
                                          }
                                        : null,
                                  );
                                },
                              ),
                              // Close button
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              
              // Notification list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 4), // Subtle spacing
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return NotificationTile(notification: notification);
                  },
                ),
              ),
            ],
          ),
        );
        }
        // Fallback for any other state
        return const Center(child: Text("Something went wrong loading notifications."));
      },
    );
  }
}

// Widget for displaying a single notification item
class NotificationTile extends StatelessWidget {
  final NotificationModel notification;

  const NotificationTile({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    IconData leadingIcon;
    Color leadingIconColor;
    String notificationActionText;
    final bool isUnread = !notification.isRead; // Check if notification is unread

    // Determine icon, color, and text based on notification type
    switch (notification.type) {
      case NotificationType.friendRequest:
        leadingIcon = Icons.person_add_alt_1; leadingIconColor = Colors.blueAccent;
        notificationActionText = ' sent you a friend request.'; break;
      case NotificationType.requestAccepted:
        leadingIcon = Icons.check_circle; leadingIconColor = Colors.green;
        notificationActionText = ' accepted your friend request.'; break;
      case NotificationType.superLike:
        leadingIcon = Icons.star; leadingIconColor = Colors.amber;
        notificationActionText = ' super liked you!'; break;
      case NotificationType.nearbyWave:
        leadingIcon = Icons.waving_hand; leadingIconColor = Colors.deepPurpleAccent;
        notificationActionText = ' waved at you from nearby!'; break;
    // No default needed as enum covers all possibilities
    }

    // --- START: Read Status UI Update (Fix #6) ---
    // Use AnimatedContainer for smooth background color transition
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      // Apply subtle background highlight if unread, otherwise transparent
      color: isUnread ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : Colors.transparent,
      // --- END: Read Status UI Update ---
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0), // Increased padding
            // Leading section with Avatar and Icon Overlay
            leading: SizedBox(
              width: 60, height: 60,
              child: Stack(
                clipBehavior: Clip.none, // Allow icon overlay to overflow
                children: [
                  // User Avatar (GestureDetector for tap action)
                  GestureDetector(
                    onTap: () {
                      // Navigate to user's profile
                      Navigator.push( context, MaterialPageRoute(
                          builder: (context) => ProfileScreen(userId: notification.fromUserId)),
                      );
                      // Note: Mark as read is handled by the ListTile's onTap, not here to avoid duplicates
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isUnread 
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                            : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        backgroundImage: (notification.fromUserPhotoUrl != null && notification.fromUserPhotoUrl!.isNotEmpty)
                            ? CachedNetworkImageProvider(notification.fromUserPhotoUrl!) : null,
                        child: (notification.fromUserPhotoUrl == null || notification.fromUserPhotoUrl!.isEmpty)
                            ? Text(
                                notification.fromUsername.isNotEmpty ? notification.fromUsername[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ) : null,
                      ),
                    ),
                  ),
                  // Notification Type Icon Overlay
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: leadingIconColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        leadingIcon, 
                        color: Colors.white, 
                        size: 14,
                      ),
                    ),
                  )
                ],
              ),
            ),
            // Title (Username + Action Text) using RichText for styling
            title: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                ),
                children: [
                  TextSpan( 
                    text: notification.fromUsername, 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  TextSpan( 
                    text: notificationActionText, 
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              maxLines: 2, 
              overflow: TextOverflow.ellipsis,
            ),
            // Subtitle (Timestamp)
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                timeago.format(notification.timestamp.toDate()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            // Trailing section with improved unread indicator
            trailing: isUnread
                ? Container(
                    width: 8, 
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: 8, height: 8),
            // --- END: Read Status UI Update ---
            // ListTile Tap Action (Navigates AND marks read)
            onTap: () {
              // Navigate to user's profile
              Navigator.push( context, MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: notification.fromUserId)),
              );
              // --- Mark as read on tap (Fix #6) ---
              // If the notification was unread, dispatch event to mark it read
              if (isUnread) {
                context.read<Bloc.NotificationBloc>().add(Bloc.MarkNotificationAsRead(notification.id)); // Use alias
              }
            },
          ),
    );
  }
}