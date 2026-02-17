// lib/widgets/chat_widgets/professional_chat_list_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/improved_chat_screen.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/services/presence_manager.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/chat_widgets/professional_presence_indicator.dart';
import 'package:freegram/widgets/chat_widgets/professional_typing_indicator.dart';
import 'package:freegram/widgets/core/user_avatar.dart';
import 'package:freegram/widgets/island_popup.dart';
import 'package:freegram/widgets/achievements/badge_insight_dialog.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Professional Chat List Item with swipe actions and enhanced design
/// Improvements: #9, #10, #12, #13, #14, #16, #17, #18
class ProfessionalChatListItem extends StatefulWidget {
  final DocumentSnapshot chat;
  final String currentUserId;

  const ProfessionalChatListItem({
    super.key,
    required this.chat,
    required this.currentUserId,
  });

  @override
  State<ProfessionalChatListItem> createState() =>
      _ProfessionalChatListItemState();
}

class _ProfessionalChatListItemState extends State<ProfessionalChatListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _swipeController;
  final bool _isPinned = false;
  final bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      duration: AnimationTokens.fast,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  // Removed _formatLastSeenShort - now using PresenceData.getShortDisplayText()

  @override
  Widget build(BuildContext context) {
    final chatRepository = locator<ChatRepository>();
    final userRepository = locator<UserRepository>();
    final chatData = widget.chat.data() as Map<String, dynamic>;
    final usernames = chatData['usernames'] as Map<String, dynamic>? ?? {};
    var otherUserId = (chatData['users'] as List)
        .firstWhere((id) => id != widget.currentUserId, orElse: () => '');

    // Fallback for self-chat or single-user chat
    if (otherUserId == '') {
      otherUserId = widget.currentUserId;
    }
    final otherUsername = usernames[otherUserId] ?? 'User';

    // Get presence stream from optimized PresenceManager
    final presenceManager = locator<PresenceManager>();
    final presenceStream = presenceManager.getUserPresence(otherUserId);

    return StreamBuilder<UserModel>(
      stream: userRepository.getUserStream(otherUserId),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        final user = userSnapshot.data!;
        final photoUrl = user.photoUrl;

        final List<dynamic> unreadFor = chatData['unreadFor'] ?? [];
        final bool isUnread = unreadFor.contains(widget.currentUserId);
        final int unreadCount =
            isUnread ? 1 : 0; // TODO: Implement actual count

        String lastMessage = chatData['lastMessage'] ?? '';
        if (chatData.containsKey('lastMessageIsImage') &&
            chatData['lastMessageIsImage'] == true) {
          lastMessage = '📷 Photo';
        }

        final messageTimestamp = chatData['lastMessageTimestamp'] as Timestamp?;
        final formattedMessageTime = messageTimestamp != null
            ? timeago.format(messageTimestamp.toDate(), locale: 'en_short')
            : '';

        // Check if user is typing
        final typingStatus =
            chatData['typingStatus'] as Map<String, dynamic>? ?? {};
        final isTyping = typingStatus[otherUserId] == true;

        return Dismissible(
          key: Key(widget.chat.id),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              // Delete
              return await _showDeleteConfirmation(context, otherUsername);
            } else {
              // Archive (not implemented yet)
              HapticFeedback.mediumImpact();
              showIslandPopup(
                context: context,
                message: 'Archive coming soon',
                icon: Icons.archive,
              );
              return false;
            }
          },
          onDismissed: (direction) async {
            if (direction == DismissDirection.endToStart) {
              await chatRepository.deleteChat(widget.chat.id);
              if (!context.mounted) return;
              showIslandPopup(
                context: context,
                message: '$otherUsername chat deleted',
                icon: Icons.check_circle,
              );
            }
          },
          background: _buildSwipeBackground(
            context: context,
            alignment: Alignment.centerLeft,
            color: SemanticColors.success,
            icon: Icons.archive_rounded,
            label: 'Archive',
          ),
          secondaryBackground: _buildSwipeBackground(
            context: context,
            alignment: Alignment.centerRight,
            color: Theme.of(context).colorScheme.error,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                locator<NavigationService>().navigateTo(
                  ImprovedChatScreen(
                    chatId: widget.chat.id,
                    otherUsername: otherUsername,
                  ),
                  transition: PageTransition.slide,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMD,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent, // Pure surface approach
                  border: Border(
                    bottom: BorderSide(
                      color:
                          Theme.of(context).dividerColor.withValues(alpha: 0.1),
                      width: 1.0,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Unread vertical accent indicator
                    if (isUnread)
                      Container(
                        width: 3,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    // Avatar with status
                    _buildAvatar(
                      photoUrl,
                      presenceStream,
                      otherUsername,
                      otherUserId,
                      user.equippedBadgeUrl,
                    ),

                    const SizedBox(width: DesignTokens.spaceMD),

                    // Chat info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (_isPinned)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(
                                    Icons.push_pin,
                                    size: DesignTokens.iconXS,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  otherUsername,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: isUnread
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: DesignTokens.fontSizeMD,
                                        color: isUnread
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : null,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: DesignTokens.spaceXS),
                          isTyping
                              ? const ProfessionalTypingIndicator()
                              : Text(
                                  lastMessage,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: isUnread
                                            ? Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.color
                                            : Colors.grey[600],
                                        fontWeight: isUnread
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                        fontSize: DesignTokens.fontSizeSM,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ],
                      ),
                    ),

                    const SizedBox(width: DesignTokens.spaceSM),

                    // Trailing (time & unread badge)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isMuted)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.volume_off,
                                  size: DesignTokens.iconSM,
                                  color: Colors.grey[400],
                                ),
                              ),
                            Text(
                              formattedMessageTime,
                              style: TextStyle(
                                color: isUnread
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[600],
                                fontSize: DesignTokens.fontSizeXS,
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        if (isUnread) ...[
                          const SizedBox(height: DesignTokens.spaceXS),
                          _buildUnreadBadge(unreadCount),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(
    String photoUrl,
    Stream<PresenceData> presenceStream,
    String username,
    String userId,
    String? badgeUrl,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        locator<NavigationService>().navigateTo(
          ProfileScreen(userId: userId),
          transition: PageTransition.slide,
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Avatar with hero animation
          Hero(
            tag: 'avatar_$userId',
            child: StreamBuilder<PresenceData>(
              stream: presenceStream,
              builder: (context, snapshot) {
                final isOnline = snapshot.data?.isOnline ?? false;
                return Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isOnline
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.0,
                          )
                        : null,
                  ),
                  child: UserAvatarMedium(
                    url: photoUrl,
                    badgeUrl: badgeUrl,
                    onBadgeTap: badgeUrl != null
                        ? () => showBadgeInsight(context, badgeUrl: badgeUrl)
                        : null,
                  ),
                );
              },
            ),
          ),

          // Professional presence indicator
          Positioned(
            bottom: 0,
            right: 0,
            child: ProfessionalPresenceIndicator(
              presenceStream: presenceStream,
              size: 16,
              showPulse: true,
            ),
          ),

          // Last seen badge (only if offline)
          Positioned(
            bottom: -2,
            right: -2,
            child: PresenceBadge(
              presenceStream: presenceStream,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnreadBadge(int count) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: AnimationTokens.normal,
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSwipeBackground({
    required BuildContext context,
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, String username) {
    HapticFeedback.mediumImpact();
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text(
            'Are you sure you want to delete your chat with $username? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
