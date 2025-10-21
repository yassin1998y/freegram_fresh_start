import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/item_definition.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/repositories/inventory_repository.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/chat_screen.dart';
import 'package:freegram/screens/edit_profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/screens/inventory_screen.dart';
import 'package:freegram/screens/qr_display_screen.dart';
import 'package:freegram/widgets/gradient_button.dart';
import 'package:freegram/widgets/gradient_outlined_button.dart';
import 'post_detail_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
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

class _ProfileScreenViewState extends State<_ProfileScreenView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
    final postRepository = locator<PostRepository>();
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

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  title: Text(user.username),
                  centerTitle: true,
                  floating: true,
                  pinned: true,
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
                  ],
                  bottom: TabBar(
                    controller: _tabController,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(context).iconTheme.color,
                    tabs: const [
                      Tab(icon: Icon(Icons.grid_on)),
                      Tab(icon: Icon(Icons.bookmark_border)),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    user: user,
                    isCurrentUserProfile: isCurrentUserProfile,
                    onStartChat: () => _startChat(context, user),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsGrid(postRepository, widget.userId),
                const Center(child: Text('Saved posts will appear here.')),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostsGrid(PostRepository repository, String userId) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        return Future.value();
      },
      child: StreamBuilder<QuerySnapshot>(
        stream: repository.getUserPostsStream(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('No posts yet.',
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
              ),
            );
          }

          final posts = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(2.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final postData = post.data() as Map<String, dynamic>;
              final isReel = postData['postType'] == 'reel';
              final imageUrl =
                  postData['thumbnailUrl'] ?? postData['imageUrl'] ?? '';

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PostDetailScreen(postSnapshot: post),
                  ));
                },
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Theme.of(context).dividerColor),
                      errorWidget: (context, url, error) =>
                      const Icon(Icons.error),
                    ),
                    if (isReel)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(Icons.play_circle_filled,
                            color: Colors.white, size: 24),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
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
              _buildProfileAvatar(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                    stream:
                    locator<PostRepository>().getUserPostsStream(user.id),
                    builder: (context, snapshot) {
                      final postCount = snapshot.data?.docs.length ?? 0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(label: 'Posts', count: postCount),
                          _StatItem(label: 'Friends', count: user.friends.length),
                          _StatItem(label: 'Level', count: user.level),
                        ],
                      );
                    }),
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

  Widget _buildProfileAvatar() {
    if (user.equippedProfileFrameId == null) {
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
    }
    return FutureBuilder<ItemDefinition>(
      future: locator<InventoryRepository>()
          .getItemDefinition(user.equippedProfileFrameId!),
      builder: (context, snapshot) {
        final frameUrl = snapshot.data?.imageUrl;
        return Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: user.photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(user.photoUrl)
                  : null,
              child: user.photoUrl.isEmpty
                  ? Text(
                user.username.isNotEmpty
                    ? user.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(fontSize: 40),
              )
                  : null,
            ),
            if (frameUrl != null)
              Image.network(
                frameUrl,
                width: 110,
                height: 110,
              ),
          ],
        );
      },
    );
  }

  Widget _buildCurrentUserActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GradientOutlinedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    EditProfileScreen(currentUserData: user.toMap()))),
            text: 'Edit Profile',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GradientOutlinedButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const InventoryScreen())),
            text: 'Inventory',
          ),
        ),
      ],
    );
  }

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
              child: GradientOutlinedButton(
                onPressed: () =>
                    context.read<FriendsBloc>().add(UnblockUser(user.id)),
                text: 'Unblock',
              ),
            );
          }

          if (requestReceived) {
            return GradientButton(
              onPressed: () => context
                  .read<FriendsBloc>()
                  .add(AcceptFriendRequest(user.id)),
              text: 'Accept Request',
            );
          }

          return Row(
            children: [
              Expanded(
                child: isFriend || requestSent
                    ? GradientOutlinedButton(
                  onPressed:
                  isFriend ? () => _confirmRemoveFriend(context) : null,
                  text: isFriend ? 'Friends' : 'Request Sent',
                )
                    : GradientButton(
                  onPressed: () => context
                      .read<FriendsBloc>()
                      .add(SendFriendRequest(user.id)),
                  text: 'Add Friend',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GradientOutlinedButton(
                  onPressed: onStartChat,
                  text: 'Message',
                ),
              ),
            ],
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

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
      context.read<FriendsBloc>().add(RemoveFriend(user.id));
    }
  }
}

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