// lib/widgets/nearby_user_card.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/widgets/island_popup.dart';

class NearbyUserCard extends StatelessWidget {
  final UserModel user;
  final int rssi;
  final DateTime lastSeen;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  // This is no longer needed for the discovery-only version but kept for future use.
  final String? deviceAddress;

  const NearbyUserCard({
    super.key,
    required this.user,
    required this.rssi,
    required this.lastSeen,
    required this.onTap,
    required this.onDelete,
    this.deviceAddress,
  });

  int _getProximityBars(int rssi) {
    if (rssi > -60) return 5; // Very close
    if (rssi > -70) return 4;
    if (rssi > -80) return 3;
    if (rssi > -90) return 2;
    return 1; // Far
  }

  void _showUserActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return BlocProvider(
          create: (context) => FriendsBloc(
            userRepository: locator<UserRepository>(),
          )..add(LoadFriends()),
          child: BlocBuilder<FriendsBloc, FriendsState>(
            builder: (context, state) {
              if (state is! FriendsLoaded) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final currentUser = state.user;
              final sharedInterests = user.interests
                  .where((interest) => currentUser.interests.any((i) => i.toLowerCase() == interest.toLowerCase()))
                  .toList();
              final mutualFriends = user.friends
                  .where((friendId) => currentUser.friends.contains(friendId))
                  .toList();

              return DraggableScrollableSheet(
                initialChildSize: 0.6,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                expand: false,
                builder: (_, scrollController) {
                  return Stack(
                    children: [
                      SingleChildScrollView(
                        controller: scrollController,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 5,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).dividerColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: user.photoUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(user.photoUrl)
                                    : null,
                                child: user.photoUrl.isEmpty ? Text(user.username[0]) : null,
                              ),
                              const SizedBox(height: 8),
                              Text(user.username, style: Theme.of(context).textTheme.headlineSmall),
                              if (user.nearbyStatusMessage.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    '"${user.nearbyStatusMessage}" ${user.nearbyStatusEmoji}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).textTheme.bodySmall?.color,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              const Divider(height: 24),

                              if (mutualFriends.isNotEmpty)
                                _InfoSection(
                                  icon: Icons.people_outline,
                                  title: 'Friend of a Friend',
                                  child: Text(
                                    'You and ${user.username} both know ${mutualFriends.length} people.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),

                              if (sharedInterests.isNotEmpty)
                                _InfoSection(
                                  icon: Icons.favorite_border,
                                  title: 'Shared Interests',
                                  child: Wrap(
                                    spacing: 6.0,
                                    runSpacing: 4.0,
                                    alignment: WrapAlignment.center,
                                    children: sharedInterests.map((interest) => Chip(
                                      label: Text(interest),
                                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      labelStyle: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontSize: 12,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    )).toList(),
                                  ),
                                ),

                              const Divider(height: 24),

                              _ActionButtons(
                                currentUser: currentUser,
                                targetUser: user,
                                modalContext: ctx,
                              ),

                              const SizedBox(height: 16),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  onTap();
                                },
                                child: const Text('View Full Profile'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isNew = DateTime.now().difference(lastSeen).inSeconds < 60;
    final proximity = _getProximityBars(rssi);

    return GestureDetector(
      onTap: () => _showUserActions(context),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (user.photoUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: user.photoUrl,
                fit: BoxFit.cover,
                errorWidget: (context, error, stackTrace) =>
                    Icon(Icons.person, size: 40, color: Theme.of(context).iconTheme.color),
              )
            else
              Icon(Icons.person, size: 40, color: Theme.of(context).iconTheme.color),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              bottom: 5,
              left: 5,
              right: 5,
              child: Text(
                user.username,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child:
                  const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isNew)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'NEW',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < proximity
                            ? Icons.signal_cellular_alt_rounded
                            : Icons.signal_cellular_alt_1_bar_rounded,
                        color: Colors.white
                            .withOpacity(index < proximity ? 1.0 : 0.4),
                        size: 12,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatefulWidget {
  final UserModel currentUser;
  final UserModel targetUser;
  final BuildContext modalContext;

  const _ActionButtons({
    required this.currentUser,
    required this.targetUser,
    required this.modalContext,
  });

  @override
  State<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<_ActionButtons> {
  bool _isLoading = false;

  void _handleBotInteraction(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Cannot $featureName a bot user.")),
    );
  }

  Future<void> _handleAction(Future<void> Function() action, String successMessage) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsBloc = context.read<FriendsBloc>();
    final isBot = widget.targetUser.id.startsWith('bot_');

    bool isFriend = widget.currentUser.friends.contains(widget.targetUser.id);
    bool requestSent = widget.currentUser.friendRequestsSent.contains(widget.targetUser.id);
    bool requestReceived = widget.currentUser.friendRequestsReceived.contains(widget.targetUser.id);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        _ActionButton(
          icon: Icons.waving_hand_outlined,
          label: 'Wave',
          isLoading: _isLoading,
          onTap: () {
            showIslandPopup(context: context, message: "Chat temporarily disabled.");
          },
        ),
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          label: 'Chat',
          isLoading: _isLoading,
          onTap: () {
            showIslandPopup(context: context, message: "Chat temporarily disabled.");
          },
        ),
        if (!isFriend && !requestSent && !requestReceived)
          _ActionButton(
            icon: Icons.person_add_alt_1_outlined,
            label: 'Add Friend',
            isLoading: _isLoading,
            onTap: isBot
                ? () => _handleBotInteraction('add')
                : () => _handleAction(
                  () async => friendsBloc.add(SendFriendRequest(widget.targetUser.id)),
              'Friend request sent to ${widget.targetUser.username}!',
            ),
          ),
        _ActionButton(
          icon: Icons.sports_esports_outlined,
          label: 'Invite',
          onTap: () {
            Navigator.pop(widget.modalContext);
            showIslandPopup(context: context, message: "Game invites coming soon!");
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary))
                : Icon(icon, color: Theme.of(context).textTheme.bodyLarge?.color),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _InfoSection({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Theme.of(context).iconTheme.color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}