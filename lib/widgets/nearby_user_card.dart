// lib/widgets/nearby_user_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Ensure debugPrint is available
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
import 'package:freegram/locator.dart';
// Correct import for the aliased UserModel
import 'package:freegram/models/user_model.dart' as ServerUserModel;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/repositories/user_repository.dart'; // Keep for FriendsBloc if needed
import 'package:freegram/services/sonar/local_cache_service.dart';
import 'package:freegram/services/sonar/sonar_controller.dart';
import 'package:freegram/widgets/island_popup.dart';
// Import the extension containing getNearbyUserByProfileId
import 'package:freegram/services/sync_manager.dart' show LocalCacheServiceHelper;
import 'package:collection/collection.dart'; // For firstWhereOrNull

class NearbyUserCard extends StatelessWidget {
  // Use the imported alias ServerUserModel
  final ServerUserModel.UserModel user;
  final int? genderValue; // Raw gender value (0, 1, 2) for placeholder
  final int rssi; // Keep for proximity bars
  final DateTime lastSeen;
  final VoidCallback onTap; // For opening full profile
  final VoidCallback onDelete;
  final String? deviceAddress;

  const NearbyUserCard({
    super.key,
    required this.user,
    this.genderValue,
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
      shape: const RoundedRectangleBorder( borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalContext) {
        // Use BlocProvider.value to pass the existing FriendsBloc from the context
        return BlocProvider.value(
          value: BlocProvider.of<FriendsBloc>(context),
          child: BlocBuilder<FriendsBloc, FriendsState>(
            builder: (context, friendsState) {
              // Handle loading state of FriendsBloc
              if (friendsState is! FriendsLoaded) {
                return const SizedBox(
                    height: 250, // Give it a set height while loading
                    child: Center(child: CircularProgressIndicator())
                );
              }
              // Once loaded, get current user data
              final currentUser = friendsState.user;
              // Access fields directly from the passed 'user' object (which is a ServerUserModel)
              final sharedInterests = user.interests.where((i) => currentUser.interests.any((ci) => ci.toLowerCase() == i.toLowerCase())).toList();
              final mutualFriends = user.friends.where((friendId) => currentUser.friends.contains(friendId)).toList();

              return DraggableScrollableSheet(
                initialChildSize: 0.6, // Start at 60% height
                minChildSize: 0.4, // Min 40%
                maxChildSize: 0.9, // Max 90%
                expand: false,
                builder: (_, scrollController) {
                  return Stack(
                    children: [
                      SingleChildScrollView(
                        controller: scrollController,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0).copyWith(bottom: 32), // Added bottom padding
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Drag handle
                              Container(
                                width: 40,
                                height: 5,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).dividerColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              // Profile Avatar and Name
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: user.photoUrl.isNotEmpty ? CachedNetworkImageProvider(user.photoUrl) : null,
                                child: user.photoUrl.isEmpty ? _buildGenderPlaceholderIcon(size: 30) : null,
                                backgroundColor: user.photoUrl.isEmpty ? _getGenderPlaceholderColor() : Colors.transparent,
                              ),
                              const SizedBox(height: 8),
                              Text(user.username, style: Theme.of(context).textTheme.headlineSmall),

                              // Nearby Status Message
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

                              // Shared Info Sections
                              if (mutualFriends.isNotEmpty)
                                _InfoSection(
                                  icon: Icons.people_outline,
                                  title: 'Friend${mutualFriends.length > 1 ? 's' : ''} in Common',
                                  // Corrected Text widget call
                                  child: Text('You both know ${mutualFriends.length} ${mutualFriends.length > 1 ? 'people' : 'person'}.'),
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
                                          labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12),
                                          visualDensity: VisualDensity.compact
                                      )).toList()
                                  ),
                                ),

                              if (mutualFriends.isNotEmpty || sharedInterests.isNotEmpty)
                                const Divider(height: 24),

                              // Action Buttons
                              // Pass the ServerUserModel.UserModel 'user' to _ActionButtons
                              _ActionButtons(
                                  currentUser: currentUser,
                                  targetUser: user, // Pass the correct user object
                                  modalContext: modalContext
                              ),
                              const SizedBox(height: 16),

                              // View Full Profile Button
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                                ),
                                onPressed: () {
                                  Navigator.pop(modalContext); // Close modal
                                  onTap(); // Execute original onTap (navigate to profile)
                                },
                                child: const Text('View Full Profile'),
                              ),
                              const SizedBox(height: 20), // Bottom padding
                            ],
                          ),
                        ),
                      ),
                      // Close Button
                      Positioned(
                        top: 16,
                        right: 16,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalContext),
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

  /// Added return type `Widget`
  Widget _buildGenderPlaceholderIcon({double size = 40}) {
    IconData iconData = Icons.person_outline;
    Color iconColor = Colors.grey.shade700;
    if (genderValue == 1) { // Male
      iconData = Icons.male;
      iconColor = Colors.blue.shade700;
    } else if (genderValue == 2) { // Female
      iconData = Icons.female;
      iconColor = Colors.pink.shade700;
    }
    return Icon(iconData, size: size, color: iconColor);
  }

  /// Added return type `Color` and default return
  Color _getGenderPlaceholderColor() {
    if (genderValue == 1) return Colors.blue.shade100;
    if (genderValue == 2) return Colors.pink.shade100;
    return Colors.grey.shade300; // Default
  }

  @override
  Widget build(BuildContext context) {
    final bool isNew = DateTime.now().difference(lastSeen).inSeconds < 60;
    final proximity = _getProximityBars(rssi);

    // Get placeholder styles
    Widget placeholderChild = _buildGenderPlaceholderIcon();
    Color placeholderBackground = _getGenderPlaceholderColor();

    return GestureDetector(
      onTap: () => _showUserActions(context), // Show modal on tap
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Display Image or Placeholder
            if (user.photoUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: user.photoUrl,
                fit: BoxFit.cover,
                // Show placeholder while loading image
                placeholder: (context, url) => Container(color: placeholderBackground, child: Center(child: placeholderChild)),
                // Show placeholder on error
                errorWidget: (context, error, stackTrace) =>
                    Container(color: placeholderBackground, child: Center(child: placeholderChild)),
              )
            else // Show gender placeholder if no photoUrl
              Container(color: placeholderBackground, child: Center(child: placeholderChild)),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // Username Text
            Positioned(
              bottom: 5,
              left: 5,
              right: 5,
              child: Text(
                user.username,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [const Shadow(blurRadius: 2, color: Colors.black54)]
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Delete Button
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
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),

            // Proximity Indicators (Top Left)
            Positioned(
              top: 4,
              left: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 'NEW' Badge
                  if (isNew)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent, borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'NEW',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Proximity Bars
                  Row(
                    children: List.generate(5, (index) {
                      IconData barIcon = Icons.signal_cellular_alt_1_bar_rounded;
                      if (proximity > index) {
                        barIcon = (proximity >= 4 && index >=3)
                            ? Icons.signal_cellular_alt_rounded // Full bars for 4 & 5
                            : Icons.signal_cellular_alt_2_bar_rounded; // Intermediate for 2 & 3
                        if (proximity >=2 && index == 1) barIcon = Icons.signal_cellular_alt_2_bar_rounded; // ensure 2nd bar shows intermediate
                      }

                      return Icon(
                        barIcon,
                        color: Colors.white.withOpacity(index < proximity ? 1.0 : 0.4),
                        size: 12,
                        shadows: const [Shadow(blurRadius: 1, color: Colors.black87)], // Add shadow
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

// --- MODAL HELPER WIDGETS (Corrected and Complete) ---

class _ActionButtons extends StatefulWidget {
  // Use the imported alias ServerUserModel
  final ServerUserModel.UserModel currentUser;
  final ServerUserModel.UserModel targetUser;
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
  bool _isLoadingWave = false;
  bool _isLoadingFriend = false;

  String? _getTargetUidShort() {
    // Use the helper method from LocalCacheService
    final nearbyUser = locator<LocalCacheService>().getNearbyUserByProfileId(widget.targetUser.id);
    if (nearbyUser != null) {
      return nearbyUser.uidShort;
    }
    // Fallback check: Check if the passed ID might already be the short one
    if (widget.targetUser.id.length <= 8) { // Assuming uidShort is 8 chars
      final directCheck = locator<LocalCacheService>().getNearbyUser(widget.targetUser.id);
      if (directCheck != null) return directCheck.uidShort;
    }
    debugPrint("Warning: Could not determine uidShort for target user ${widget.targetUser.id}");
    return null;
  }

  Future<void> _handleWave() async {
    if (_isLoadingWave) return;
    setState(() => _isLoadingWave = true);
    final targetUidShort = _getTargetUidShort();
    if (targetUidShort == null) {
      if(mounted) showIslandPopup(context: context, message: "Cannot wave yet (user data missing).", icon: Icons.error_outline);
      setState(() => _isLoadingWave = false);
      return;
    }
    try {
      await locator<SonarController>().sendWave(targetUidShort);
      if (mounted) {
        Navigator.pop(widget.modalContext);
        showIslandPopup(context: context, message: "Wave sent!", icon: Icons.waving_hand);
      }
    } catch (e) { if (mounted) showIslandPopup(context: context, message: "Failed to send wave: $e", icon: Icons.error_outline); }
    finally { if (mounted) setState(() => _isLoadingWave = false); }
  }

  Future<void> _handleAddFriend() async {
    // --- BUG FIX #2 ---
    // Check if the targetUser.id is a full UUID before sending
    // Assuming full UUIDs are significantly longer than 8 characters (our uidShort length)
    bool isFullId = widget.targetUser.id.length > 10; // Adjust length check if needed (e.g., > 20 for Firebase UUIDs)

    // --- DEBUG ---
    debugPrint("_handleAddFriend: Target ID: ${widget.targetUser.id}, Is Full ID: $isFullId");
    // --- END DEBUG ---

    if (!isFullId) {
      // If it's a short ID, queue the request locally instead of sending directly
      debugPrint("Queuing friend request locally for short ID: ${widget.targetUser.id}");
      if (_isLoadingFriend) return; // Prevent multiple queues
      setState(() => _isLoadingFriend = true);
      try {
        await locator<LocalCacheService>().queueFriendRequest(
            fromUserId: widget.currentUser.id,
            toUserId: widget.targetUser.id // Pass the short ID for queuing
        );
        if (mounted) {
          Navigator.pop(widget.modalContext);
          showIslandPopup(context: context, message: "Friend request queued!", icon: Icons.person_add_alt_1);
        }
      } catch (e) {
        if (mounted) {
          showIslandPopup(context: context, message: "Failed to queue request: $e", icon: Icons.error_outline);
        }
      } finally {
        // Only reset loading if still mounted and queuing failed
        if (mounted && !Navigator.canPop(widget.modalContext)) { // Check if modal is still open
          setState(() => _isLoadingFriend = false);
        }
      }
      return; // Stop here, don't proceed with direct BLoC call
    }
    // --- END BUG FIX #2 ---


    // --- Original Logic (for when it IS a full ID) ---
    if (_isLoadingFriend) return;
    setState(() => _isLoadingFriend = true);
    try {
      // Dispatch the event ONLY if it's a full ID
      debugPrint("Dispatching SendFriendRequest event for full ID: ${widget.targetUser.id}");
      context.read<FriendsBloc>().add(SendFriendRequest(widget.targetUser.id));

      // Give Bloc time to process (optimistic update might happen)
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        Navigator.pop(widget.modalContext);
        // Show success only if the request was actually sent via BLoC
        showIslandPopup(context: context, message: "Friend request sent!", icon: Icons.person_add_alt_1);
      }
    } catch (e) {
      if (mounted) {
        showIslandPopup(context: context, message: "Failed to send request: $e", icon: Icons.error_outline);
      }
      // Reset loading only on error for BLoC call
      if (mounted) setState(() => _isLoadingFriend = false);
    }
    // Don't reset loading state on success for BLoC call, let state handle it
  }

  void _handleInvite() {
    Navigator.pop(widget.modalContext);
    showIslandPopup(context: context, message: "Game invites coming soon!");
  }


  @override
  Widget build(BuildContext context) {
    // Get latest state directly via watch
    final friendsBlocState = context.watch<FriendsBloc>().state;

    // Handle loading state of friends bloc
    if (friendsBlocState is! FriendsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentUserData = friendsBlocState.user;

    bool isFriend = currentUserData.friends.contains(widget.targetUser.id);
    bool requestSent = currentUserData.friendRequestsSent.contains(widget.targetUser.id);
    bool requestReceived = currentUserData.friendRequestsReceived.contains(widget.targetUser.id);

    // --- BUG FIX #2 Condition ---
    // Check if the profile is synced (targetUser.id is a full UUID)
    bool profileSynced = widget.targetUser.id.length > 10; // Adjust if needed
    // --- END BUG FIX #2 Condition ---


    return Wrap(
      spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
      children: [
        _ActionButton( icon: Icons.waving_hand_outlined, label: 'Wave', isLoading: _isLoadingWave, onTap: _handleWave),
        _ActionButton( icon: Icons.chat_bubble_outline, label: 'Chat', onTap: () { showIslandPopup(context: context, message: "Chat temporarily disabled."); }),

        // Friend Action Button
        if (isFriend)
          const _ActionButton(icon: Icons.check_circle_outline, label: 'Friend', onTap: null) // Already friends, disable
        else if (requestSent)
        // Check if request was sent TO the full ID (if synced) or the short ID (if not yet synced)
          const _ActionButton(icon: Icons.hourglass_top_rounded, label: 'Requested', onTap: null) // Request sent, disable
        else if (requestReceived)
          // Show "Accept" button - Requires profile to be synced to accept
            _ActionButton(
                icon: Icons.mark_email_read_outlined,
                label: 'Accept',
                isLoading: _isLoadingFriend,
                // Disable accept if profile not synced
                onTap: !profileSynced ? null : () async {
                  setState(() => _isLoadingFriend = true);
                  context.read<FriendsBloc>().add(AcceptFriendRequest(widget.targetUser.id));
                  await Future.delayed(const Duration(milliseconds: 500)); // Wait for action
                  if(mounted) Navigator.pop(widget.modalContext);
                }
            )
          else
          // Show "Add Friend" or "Syncing..."
            _ActionButton(
              icon: Icons.person_add_alt_1,
              label: profileSynced ? 'Add Friend' : 'Add Friend', // Keep "Add Friend", let onTap handle logic
              isLoading: _isLoadingFriend,
              onTap: _handleAddFriend, // Let _handleAddFriend handle the logic
            ),

        _ActionButton( icon: Icons.sports_esports_outlined, label: 'Invite', onTap: _handleInvite),
      ],
    );
  }
}

// **FIXED:** Full implementation of _ActionButton
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap; // Changed to allow null
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    bool isDisabled = onTap == null; // Check if onTap is null
    return GestureDetector(
      // Use isDisabled flag
      onTap: isLoading || isDisabled ? null : onTap,
      child: Opacity(
        // Adjust opacity based on isDisabled
        opacity: isLoading || isDisabled ? 0.5 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54, // Ensure consistent size
              height: 54, // Ensure consistent size
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // Dim color if disabled
                color: isDisabled
                    ? Theme.of(context).dividerColor.withOpacity(0.3)
                    : Theme.of(context).dividerColor.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)))
              // Dim icon if disabled
                  : Icon(icon, color: isDisabled ? Colors.grey[500] : Theme.of(context).textTheme.bodyLarge?.color, size: 28),
            ),
            const SizedBox(height: 4),
            // Dim label if disabled
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDisabled ? Colors.grey[500] : null)),
          ],
        ),
      ),
    );
  }
}

// **FIXED:** Full implementation of _InfoSection
class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _InfoSection({
    required this.icon,
    required this.title,
    required this.child
  });

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
                    fontWeight: FontWeight.w600
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child, // The content (e.g., Wrap of chips or Text)
        ],
      ),
    );
  }
}