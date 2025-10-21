import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/profile_screen.dart';

class FriendsListScreen extends StatefulWidget {
  final int initialIndex;
  final String? userId;
  final Function(String friendId)? onFriendSelected;

  const FriendsListScreen({
    super.key,
    this.initialIndex = 0,
    this.userId,
    this.onFriendSelected,
  });

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool get _isSelectionMode => widget.onFriendSelected != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: widget.userId == null ? 3 : 1,
        vsync: this,
        initialIndex: widget.userId == null ? widget.initialIndex : 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId != null) {
      return _buildOtherUserProfile();
    }

    final appBarTitle =
    _isSelectionMode ? const Text('Select a Friend') : const Text('Manage Friends');

    final tabs = _isSelectionMode
        ? null
        : TabBar(
      controller: _tabController,
      indicatorColor: Theme.of(context).colorScheme.primary,
      labelColor: Theme.of(context).colorScheme.primary,
      unselectedLabelColor: Theme.of(context).iconTheme.color,
      tabs: const [
        Tab(text: 'Friends'),
        Tab(text: 'Requests'),
        Tab(text: 'Blocked'),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: appBarTitle,
        bottom: tabs,
      ),
      body: BlocBuilder<FriendsBloc, FriendsState>(
        builder: (context, state) {
          if (state is FriendsLoading || state is FriendsInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is FriendsError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is FriendsLoaded) {
            if (_isSelectionMode) {
              return _buildFriendsList(state.user.friends);
            }
            return TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsList(state.user.friends),
                _buildRequestsTab(state.user.friendRequestsReceived),
                _buildBlockedTab(state.user.blockedUsers),
              ],
            );
          }
          return const Center(child: Text('Something went wrong.'));
        },
      ),
    );
  }

  Widget _buildOtherUserProfile() {
    final userRepository = locator<UserRepository>();
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<UserModel>(
        future: userRepository.getUser(widget.userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Could not load user.'));
          }
          final user = snapshot.data!;
          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  title: Text("${user.username}'s Friends"),
                  automaticallyImplyLeading: false,
                  pinned: true,
                ),
              ];
            },
            body: _buildFriendsList(user.friends),
          );
        },
      ),
    );
  }

  Widget _buildFriendsList(List<String> friendIds) {
    if (friendIds.isEmpty) {
      return Center(child: Text('No friends to show.', style: Theme.of(context).textTheme.bodyMedium));
    }
    return ListView.builder(
      itemCount: friendIds.length,
      itemBuilder: (context, index) {
        final userId = friendIds[index];
        return UserListTile(
          userId: userId,
          onTap: _isSelectionMode
              ? () {
            Navigator.of(context).pop();
            widget.onFriendSelected!(userId);
          }
              : null,
        );
      },
    );
  }

  Widget _buildRequestsTab(List<String> requestIds) {
    if (requestIds.isEmpty) {
      return Center(child: Text('You have no pending friend requests.', style: Theme.of(context).textTheme.bodyMedium));
    }
    return ListView.builder(
      itemCount: requestIds.length,
      itemBuilder: (context, index) {
        final userId = requestIds[index];
        return UserListTile(
          userId: userId,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                tooltip: 'Accept',
                onPressed: () {
                  context.read<FriendsBloc>().add(AcceptFriendRequest(userId));
                },
              ),
              IconButton(
                icon: Icon(Icons.cancel, color: Theme.of(context).colorScheme.error),
                tooltip: 'Decline',
                onPressed: () {
                  context.read<FriendsBloc>().add(DeclineFriendRequest(userId));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlockedTab(List<String> blockedUserIds) {
    if (blockedUserIds.isEmpty) {
      return Center(child: Text('You have not blocked any users.', style: Theme.of(context).textTheme.bodyMedium));
    }
    return ListView.builder(
      itemCount: blockedUserIds.length,
      itemBuilder: (context, index) {
        final userId = blockedUserIds[index];
        return UserListTile(
          userId: userId,
          trailing: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            child: const Text('Unblock'),
            onPressed: () {
              context.read<FriendsBloc>().add(UnblockUser(userId));
            },
          ),
        );
      },
    );
  }
}

class UserListTile extends StatefulWidget {
  final String userId;
  final Widget? trailing;
  final VoidCallback? onTap;

  const UserListTile(
      {super.key, required this.userId, this.trailing, this.onTap});

  @override
  State<UserListTile> createState() => _UserListTileState();
}

class _UserListTileState extends State<UserListTile> {
  late Future<UserModel> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = locator<UserRepository>().getUser(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListTile(
            leading: CircleAvatar(backgroundColor: Theme.of(context).dividerColor),
            title: Container(
              height: 16,
              width: 120,
              color: Theme.of(context).dividerColor,
            ),
          );
        }
        if (snapshot.hasError) {
          return ListTile(
            leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.error),
            title:
            Text('Error loading user', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          );
        }

        final user = snapshot.data!;
        final photoUrl = user.photoUrl;

        return ListTile(
          leading: CircleAvatar(
            backgroundImage:
            (photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
            child: (photoUrl.isEmpty)
                ? Text(user.username.isNotEmpty
                ? user.username[0].toUpperCase()
                : '?')
                : null,
          ),
          title: Text(user.username, style: Theme.of(context).textTheme.titleMedium),
          trailing: widget.trailing,
          onTap: widget.onTap ??
                  () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: widget.userId)));
              },
        );
      },
    );
  }
}