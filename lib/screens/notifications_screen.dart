// lib/screens/notifications_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Use alias for Bloc import to avoid naming conflicts
import 'package:freegram/blocs/notification_bloc/notification_bloc.dart'
    as Bloc;
import 'package:freegram/locator.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/models/notification_model.dart';
import 'package:freegram/repositories/notification_repository.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/screens/post_detail_screen.dart';
import 'package:freegram/widgets/freegram_app_bar.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/common/app_button.dart';
import 'package:freegram/widgets/common/empty_state_widget.dart';
import 'package:freegram/theme/design_tokens.dart';

class NotificationsScreen extends StatelessWidget {
  // --- Added parameters for Modal Bottom Sheet (Fix #5) ---
  final bool isModal; // Flag to indicate if shown in a modal
  final ScrollController?
      scrollController; // Controller for scrolling within modal

  const NotificationsScreen({
    super.key,
    this.isModal = false, // Default to not being modal
    this.scrollController,
  });
  // --- END: Added parameters ---

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 SCREEN: notifications_screen.dart');
    // Provide the NotificationBloc to the widget subtree
    return BlocProvider(
      create: (context) => Bloc.NotificationBloc(
        // Use alias
        notificationRepository: locator<NotificationRepository>(),
      )..add(
          Bloc.LoadNotifications()), // Load notifications initially (Use alias)
      // Conditionally wrap content with Scaffold based on isModal flag
      child: isModal
          ? _NotificationsView(
              scrollController:
                  scrollController) // If modal, just return the view
          : Scaffold(
              // If not modal, provide Scaffold with FreegramAppBar
              appBar: FreegramAppBar(
                title: 'Notifications',
                showBackButton: true,
                actions: [
                  // Button to mark all notifications as read
                  BlocBuilder<Bloc.NotificationBloc, Bloc.NotificationState>(
                    builder: (context, state) {
                      // Check if there are any unread notifications in the loaded state
                      bool hasUnread = false;
                      if (state is Bloc.NotificationLoaded) {
                        hasUnread = state.notifications.any((n) => !n.isRead);
                      }
                      // Render the button, disable if no unread notifications
                      return AppIconButton(
                        icon: Icons.mark_chat_read_outlined,
                        tooltip: 'Mark All As Read',
                        onPressed: hasUnread
                            ? () {
                                context
                                    .read<Bloc.NotificationBloc>()
                                    .add(Bloc.MarkAllNotificationsAsRead());
                              }
                            : () {}, // Disabled state
                        color: hasUnread
                            ? null
                            : SemanticColors.textSecondary(
                                context), // Disabled color
                        isDisabled: !hasUnread,
                      );
                    },
                  ),
                ],
              ),
              body: _NotificationsView(scrollController: scrollController),
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
    return BlocBuilder<Bloc.NotificationBloc, Bloc.NotificationState>(
      // Use alias
      builder: (context, state) {
        // Show loading indicator
        if (state is Bloc.NotificationLoading) {
          // Use alias
          return const Center(child: AppProgressIndicator());
        }
        // Show error message
        if (state is Bloc.NotificationError) {
          // Use alias
          return Center(child: Text('Error: ${state.message}'));
        }
        // Show notification list if loaded
        if (state is Bloc.NotificationLoaded) {
          // Use alias
          final notifications = state.notifications;
          // Show empty state if no notifications
          if (notifications.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.notifications_off_outlined,
              title: 'No Notifications Yet',
              subtitle: 'Waves and friend requests will appear here.',
            );
          }

          // Build the list with custom header for modal
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Custom header for modal with close and mark all buttons
                if (scrollController != null) // Only show header in modal
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      DesignTokens.spaceMD,
                      DesignTokens.spaceMD,
                      DesignTokens.spaceMD,
                      DesignTokens.spaceSM,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(DesignTokens.radiusXL),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            DesignTokens.opacityMedium,
                          ),
                          blurRadius: DesignTokens.elevation2,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Drag handle
                        Container(
                          width: DesignTokens.bottomSheetHandleWidth,
                          height: DesignTokens.bottomSheetHandleHeight,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(DesignTokens.opacityMedium),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spaceMD),
                        // Header row with title and buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Notifications',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Row(
                              children: [
                                // Mark all as read button
                                BlocBuilder<Bloc.NotificationBloc,
                                    Bloc.NotificationState>(
                                  builder: (context, state) {
                                    bool hasUnread = false;
                                    if (state is Bloc.NotificationLoaded) {
                                      hasUnread = state.notifications
                                          .any((n) => !n.isRead);
                                    }
                                    return IconButton(
                                      icon: Icon(
                                        Icons.mark_chat_read_outlined,
                                        color: hasUnread
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.3),
                                      ),
                                      tooltip: 'Mark All As Read',
                                      onPressed: hasUnread
                                          ? () {
                                              context
                                                  .read<Bloc.NotificationBloc>()
                                                  .add(Bloc
                                                      .MarkAllNotificationsAsRead());
                                            }
                                          : null,
                                    );
                                  },
                                ),
                                // Close button
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
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
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 4), // Subtle spacing
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
        return const Center(
            child: Text("Something went wrong loading notifications."));
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
    final bool isUnread =
        !notification.isRead; // Check if notification is unread

    // Determine icon, color, and text based on notification type
    switch (notification.type) {
      case NotificationType.friendRequest:
        leadingIcon = Icons.person_add_alt_1;
        leadingIconColor = SemanticColors.info;
        notificationActionText = ' sent you a friend request.';
        break;
      case NotificationType.requestAccepted:
        leadingIcon = Icons.check_circle;
        leadingIconColor = SemanticColors.success;
        notificationActionText = ' accepted your friend request.';
        break;
      case NotificationType.superLike:
        leadingIcon = Icons.star;
        leadingIconColor = SemanticColors.warning;
        notificationActionText = ' super liked you!';
        break;
      case NotificationType.nearbyWave:
        leadingIcon = Icons.waving_hand;
        leadingIconColor = Theme.of(context).colorScheme.secondary;
        notificationActionText = ' waved at you from nearby!';
        break;
      case NotificationType.comment:
        leadingIcon = Icons.comment;
        leadingIconColor = SemanticColors.info;
        notificationActionText = ' commented on your post.';
        break;
      case NotificationType.reaction:
        leadingIcon = Icons.favorite;
        leadingIconColor = Theme.of(context).colorScheme.error;
        notificationActionText = ' liked your post.';
        break;
      case NotificationType.mention:
        leadingIcon = Icons.alternate_email;
        leadingIconColor = Theme.of(context).colorScheme.secondary;
        notificationActionText = ' mentioned you in a post.';
        break;
    }

    // --- START: Read Status UI Update (Fix #6) ---
    // Use AnimatedContainer for smooth background color transition
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      // Apply subtle background highlight if unread, otherwise transparent
      color: isUnread
          ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
          : Colors.transparent,
      // --- END: Read Status UI Update ---
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 20.0, vertical: 12.0), // Increased padding
        // Leading section with Avatar and Icon Overlay
        leading: SizedBox(
          width: DesignTokens.avatarSizeLarge,
          height: DesignTokens.avatarSizeLarge,
          child: Stack(
            clipBehavior: Clip.none, // Allow icon overlay to overflow
            children: [
              // User Avatar (GestureDetector for tap action)
              GestureDetector(
                onTap: () {
                  // Navigate to user's profile
                  locator<NavigationService>().navigateTo(
                    ProfileScreen(userId: notification.fromUserId),
                  );
                  // Note: Mark as read is handled by the ListTile's onTap, not here to avoid duplicates
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isUnread
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3)
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    backgroundImage: (notification.fromUserPhotoUrl != null &&
                            notification.fromUserPhotoUrl!.isNotEmpty)
                        ? CachedNetworkImageProvider(
                            notification.fromUserPhotoUrl!)
                        : null,
                    child: (notification.fromUserPhotoUrl == null ||
                            notification.fromUserPhotoUrl!.isEmpty)
                        ? Text(
                            notification.fromUsername.isNotEmpty
                                ? notification.fromUsername[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: DesignTokens.fontSizeLG,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              // Notification Type Icon Overlay
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(DesignTokens.spaceXS),
                  decoration: BoxDecoration(
                    color: leadingIconColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          DesignTokens.opacityMedium,
                        ),
                        blurRadius: DesignTokens.elevation1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    leadingIcon,
                    color: Colors.white,
                    size: DesignTokens.iconSM,
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
                  fontSize: DesignTokens.fontSizeMD,
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
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
          padding: const EdgeInsets.only(top: DesignTokens.spaceXS),
          child: Text(
            timeago.format(notification.timestamp.toDate()),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: DesignTokens.fontSizeXS,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3),
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
          // Navigate based on notification type
          if (notification.postId != null &&
              (notification.type == NotificationType.comment ||
                  notification.type == NotificationType.reaction ||
                  notification.type == NotificationType.mention)) {
            // Navigate to post detail screen
            locator<NavigationService>().navigateTo(
              PostDetailScreen(
                postId: notification.postId!,
                commentId: notification.commentId,
              ),
            );
          } else {
            // Navigate to user's profile for other types
            locator<NavigationService>().navigateTo(
              ProfileScreen(userId: notification.fromUserId),
            );
          }
          // --- Mark as read on tap (Fix #6) ---
          // If the notification was unread, dispatch event to mark it read
          if (isUnread) {
            context
                .read<Bloc.NotificationBloc>()
                .add(Bloc.MarkNotificationAsRead(notification.id)); // Use alias
          }
        },
      ),
    );
  }
}
