import 'package:cloud_firestore/cloud_firestore.dart'; // Keep for QuerySnapshot if needed elsewhere, though maybe not directly here anymore
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
import 'package:freegram/locator.dart';
// import 'package:freegram/models/item_definition.dart'; // Remove
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/chat_repository.dart';
// import 'package:freegram/repositories/inventory_repository.dart'; // Remove
// import 'package:freegram/repositories/post_repository.dart'; // Remove
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/chat_screen.dart';
import 'package:freegram/screens/edit_profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
// import 'package:freegram/screens/inventory_screen.dart'; // Remove
import 'package:freegram/screens/qr_display_screen.dart';
// import 'package:freegram/widgets/gradient_button.dart'; // Remove
// import 'package:freegram/widgets/gradient_outlined_button.dart'; // Remove
// import 'post_detail_screen.dart'; // Remove

class ProfileScreen extends StatelessWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Keep FriendsBloc for friend status actions
    return BlocProvider(
      create: (context) => FriendsBloc(
        userRepository: locator<UserRepository>(),
      )..add(LoadFriends()),
      child: _ProfileScreenView(userId: userId),
    );
  }
}

class _ProfileScreenView extends StatefulWidget {
  final String userId;
  const _ProfileScreenView({required this.userId});

  @override
  State<_ProfileScreenView> createState() => _ProfileScreenViewState();
}

// Removed SingleTickerProviderStateMixin as TabController is removed
class _ProfileScreenViewState extends State<_ProfileScreenView> {
  // Removed TabController initialization and disposal

  Future<void> _startChat(BuildContext context, UserModel user) async {
    final chatId = await locator<ChatRepository>().startOrGetChat(
      user.id,
      user.username,
    );
    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUsername: user.username,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRepository = locator<UserRepository>();
    // final postRepository = locator<PostRepository>(); // Remove PostRepository instance
    final isCurrentUserProfile =
        FirebaseAuth.instance.currentUser?.uid == widget.userId;

    return Scaffold(
      body: StreamBuilder<UserModel>(
        stream: userRepository.getUserStream(widget.userId),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData) {
            return const Center(child: Text('User not found.'));
          }
          if (userSnapshot.hasError) {
            return Center(child: Text('Error: ${userSnapshot.error}'));
          }

          final user = userSnapshot.data!;

          // Use CustomScrollView instead of NestedScrollView as tabs are removed
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(user.username),
                centerTitle: true,
                floating: true, // Keep floating for better UX
                pinned: true, // Keep pinned
                actions: [
                  if (isCurrentUserProfile)
                    IconButton(
                      icon: const Icon(Icons.qr_code_2_outlined),
                      tooltip: 'My QR Code',
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => QrDisplayScreen(user: user),
                        ));
                      },
                    ),
                  // Removed TabBar from bottom
                ],
              ),
              SliverToBoxAdapter(
                child: _ProfileHeader(
                  user: user,
                  isCurrentUserProfile: isCurrentUserProfile,
                  onStartChat: () => _startChat(context, user),
                ),
              ),
              // Removed TabBarView and _buildPostsGrid
              const SliverFillRemaining( // Placeholder if needed, or remove if header fills screen
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    // Optionally add a message if profile seems empty
                    // child: Text('User posts will appear here.'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

// Removed _buildPostsGrid method
}

class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  final bool isCurrentUserProfile;
  final VoidCallback onStartChat;

  const _ProfileHeader({
    required this.user,
    required this.isCurrentUserProfile,
    required this.onStartChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildProfileAvatar(), // Keep avatar logic (removed frame logic)
              Expanded(
                // Removed StreamBuilder for post count
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // _StatItem(label: 'Posts', count: postCount), // Remove Posts stat
                    _StatItem(label: 'Friends', count: user.friends.length), // Keep Friends
                    // _StatItem(label: 'Level', count: user.level), // Remove Level stat
                    // Optionally add another stat if desired (e.g., join date)
                    _StatItem(label: 'Age', count: user.age), // Example: Add Age
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (user.bio.isNotEmpty)
            Text(user.bio, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          if (isCurrentUserProfile)
            _buildCurrentUserActionButtons(context)
          else
            _buildOtherUserActionButtons(context),
        ],
      ),
    );
  }

  // _buildProfileAvatar updated to remove frame logic
  Widget _buildProfileAvatar() {
    // Simplified: Always return the basic CircleAvatar
    return CircleAvatar(
      radius: 45,
      backgroundColor: Colors.grey.shade300,
      backgroundImage: user.photoUrl.isNotEmpty
          ? CachedNetworkImageProvider(user.photoUrl)
          : null,
      child: user.photoUrl.isEmpty
          ? Text(
        user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 40),
      )
          : null,
    );
    // Removed FutureBuilder for equippedProfileFrameId
  }


  // _buildCurrentUserActionButtons updated to remove Inventory button and Gradient widgets
  Widget _buildCurrentUserActionButtons(BuildContext context) {
    // Use standard OutlinedButton
    return SizedBox(
      width: double.infinity, // Make button take full width
      child: OutlinedButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                EditProfileScreen(currentUserData: user.toMap()))),
        child: const Text('Edit Profile'),
        // Add styling if needed
        // style: OutlinedButton.styleFrom(...)
      ),
    );
    // Removed Row and second button (Inventory)
  }

  // _buildOtherUserActionButtons updated to use standard buttons
  Widget _buildOtherUserActionButtons(BuildContext context) {
    return BlocBuilder<FriendsBloc, FriendsState>(
      builder: (context, state) {
        if (state is FriendsLoaded) {
          final currentUser = state.user;
          bool isFriend = currentUser.friends.contains(user.id);
          bool requestSent = currentUser.friendRequestsSent.contains(user.id);
          bool requestReceived =
          currentUser.friendRequestsReceived.contains(user.id);
          bool isBlocked = currentUser.blockedUsers.contains(user.id);

          if (isBlocked) {
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton( // Use OutlinedButton
                onPressed: () =>
                    context.read<FriendsBloc>().add(UnblockUser(user.id)),
                child: const Text('Unblock'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
              ),
            );
          }

          if (requestReceived) {
            return SizedBox(
              width: double.infinity,
              child: ElevatedButton( // Use ElevatedButton
                onPressed: () => context
                    .read<FriendsBloc>()
                    .add(AcceptFriendRequest(user.id)),
                child: const Text('Accept Request'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            );
          }

          return Row(
            children: [
              Expanded(
                child: isFriend || requestSent
                    ? OutlinedButton( // Use OutlinedButton
                  onPressed:
                  isFriend ? () => _confirmRemoveFriend(context) : null, // Disable if requestSent
                  child: Text(isFriend ? 'Friends' : 'Request Sent'),
                )
                    : ElevatedButton( // Use ElevatedButton
                  onPressed: () => context
                      .read<FriendsBloc>()
                      .add(SendFriendRequest(user.id)),
                  child: const Text('Add Friend'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton( // Use OutlinedButton
                  onPressed: onStartChat,
                  child: const Text('Message'),
                ),
              ),
            ],
          );
        }
        // Show loading or placeholder while FriendsBloc loads
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }


  // _confirmRemoveFriend remains the same
  Future<void> _confirmRemoveFriend(BuildContext context) async {
    final bool? shouldRemove = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Friend?'),
          content: Text(
              'Are you sure you want to remove ${user.username} as a friend?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldRemove == true) {
      // Use read to access bloc if context is available
      context.read<FriendsBloc>().add(RemoveFriend(user.id));
    }
  }
}

// _StatItem remains the same
class _StatItem extends StatelessWidget {
  final String label;
  final int count;

  const _StatItem({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}