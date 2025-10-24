import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/notification_bloc/notification_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/notification_model.dart';
import 'package:freegram/repositories/notification_repository.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationBloc(
        notificationRepository: locator<NotificationRepository>(),
      )..add(LoadNotifications()),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  Widget _buildAppBarAction(BuildContext context, IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: IconButton(
        icon: Icon(icon, color: Theme.of(context).iconTheme.color, size: 28),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // The nested navigator in main_screen will handle the back button automatically.
        title: const Text("Notifications"),
      ),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state is NotificationLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is NotificationError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is NotificationLoaded) {
            final notifications = state.notifications;
            if (notifications.isEmpty) {
              return const Center(child: Text('No notifications yet.'));
            }
            return ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return NotificationTile(notification: notification);
              },
            );
          }
          return const Center(child: Text("Something went wrong."));
        },
      ),
    );
  }
}

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
    final bool isUnread = !notification.isRead;

    switch (notification.type) {

      case NotificationType.friendRequest:
        leadingIcon = Icons.person_add_alt_1;
        leadingIconColor = Colors.blueAccent;
        notificationActionText = ' sent you a friend request.';
        break;
      case NotificationType.requestAccepted:
        leadingIcon = Icons.check_circle;
        leadingIconColor = Colors.green;
        notificationActionText = ' accepted your friend request.';
        break;
      case NotificationType.superLike:
        leadingIcon = Icons.star;
        leadingIconColor = Colors.amber;
        notificationActionText = ' super liked you!';
        break;
      case NotificationType.nearbyWave:
        leadingIcon = Icons.waving_hand;
        leadingIconColor = Colors.deepPurpleAccent;
        notificationActionText = ' waved at you from nearby!';
        break;

    }

    return Container(
      color: isUnread ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : null,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            leading: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(userId: notification.fromUserId),
                        ),
                      );
                      if (isUnread) {
                        context.read<NotificationBloc>().add(MarkNotificationAsRead(notification.id));
                      }
                    },
                    child: CircleAvatar(
                      radius: 28,
                      backgroundImage: (notification.fromUserPhotoUrl != null && notification.fromUserPhotoUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(notification.fromUserPhotoUrl!)
                          : null,
                      child: (notification.fromUserPhotoUrl == null || notification.fromUserPhotoUrl!.isEmpty)
                          ? Text(notification.fromUsername.isNotEmpty ? notification.fromUsername[0].toUpperCase() : '?')
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2)
                      ),
                      child: Icon(leadingIcon, color: leadingIconColor, size: 16),
                    ),
                  )
                ],
              ),
            ),
            title: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: notification.fromUsername,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: notificationActionText,
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
            subtitle: Text(
              timeago.format(notification.timestamp.toDate()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: isUnread
                ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            )
                : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: notification.fromUserId),
                ),
              );
              if (isUnread) {
                context.read<NotificationBloc>().add(MarkNotificationAsRead(notification.id));
              }
            },
          ),
          const Divider(height: 1, indent: 88, endIndent: 16),
        ],
      ),
    );
  }
}