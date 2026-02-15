import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/friend_repository.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/navigation/app_routes.dart';

import 'package:freegram/models/gift_model.dart';

/// Friend picker screen for gift sending
class GiftSendFriendPickerScreen extends StatefulWidget {
  final GiftModel? preselectedGift;
  final String? ownedGiftId;

  const GiftSendFriendPickerScreen({
    super.key,
    this.preselectedGift,
    this.ownedGiftId,
  });

  @override
  State<GiftSendFriendPickerScreen> createState() =>
      _GiftSendFriendPickerScreenState();
}

class _GiftSendFriendPickerScreenState
    extends State<GiftSendFriendPickerScreen> {
  final _searchController = TextEditingController();
  final _friendRepo = locator<FriendRepository>();
  final _giftRepo = locator<GiftRepository>();

  String _searchQuery = '';
  _FilterOption _selectedFilter = _FilterOption.all;
  UserModel? _selectedFriend;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Gift To'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Filter chips
          _buildFilterChips(),

          // Recent recipients section
          _buildRecentRecipients(currentUser.uid),

          // Friends list
          Expanded(
            child: _buildFriendsList(currentUser.uid),
          ),

          // Continue button
          if (_selectedFriend != null) _buildContinueButton(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search friends...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value.toLowerCase());
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('All', _FilterOption.all),
          const SizedBox(width: 8),
          _buildFilterChip('Online', _FilterOption.online),
          const SizedBox(width: 8),
          _buildFilterChip('Recent', _FilterOption.recent),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, _FilterOption option) {
    final isSelected = _selectedFilter == option;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        HapticHelper.light();
        setState(() => _selectedFilter = option);
      },
      selectedColor: Colors.purple.shade100,
      checkmarkColor: Colors.purple.shade700,
    );
  }

  Widget _buildRecentRecipients(String userId) {
    return StreamBuilder(
      stream: _giftRepo.getRecentRecipients(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Recent Recipients',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final recipient = snapshot.data![index];
                  return _buildRecentRecipientCard(recipient);
                },
              ),
            ),
            const Divider(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildRecentRecipientCard(dynamic recipient) {
    // TODO: Replace with actual RecentRecipient model
    final username = recipient.recipientUsername ?? 'Unknown';
    final photoUrl = recipient.recipientPhotoUrl;

    return GestureDetector(
      onTap: () {
        HapticHelper.light();
        // TODO: Select this recipient
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : null,
              child: photoUrl == null ? Text(username[0].toUpperCase()) : null,
            ),
            const SizedBox(height: 4),
            Text(
              username,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList(String userId) {
    // Use getFriends to fetch the actual friends list
    return FutureBuilder<List<UserModel>>(
      future: _friendRepo.getFriends(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        var friends = snapshot.data ?? [];

        // Apply search filter locally
        if (_searchQuery.isNotEmpty) {
          friends = friends
              .where((friend) =>
                  friend.username.toLowerCase().contains(_searchQuery))
              .toList();
        }

        // Apply filter option
        if (_selectedFilter == _FilterOption.online) {
          friends = friends.where((f) => f.isOnline).toList();
        }
        // Recent filter is handled by the separate Recent Recipients section

        if (friends.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            return _buildFriendCard(friends[index]);
          },
        );
      },
    );
  }

  Widget _buildFriendCard(UserModel friend) {
    final isSelected = _selectedFriend?.id == friend.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.purple.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: (friend.photoUrl.isNotEmpty)
              ? NetworkImage(friend.photoUrl)
              : null,
          child: friend.photoUrl.isEmpty
              ? Text(friend.username[0].toUpperCase())
              : null,
        ),
        title: Text(
          friend.username,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(friend.bio),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Colors.purple.shade700)
            : const Icon(Icons.chevron_right),
        onTap: () {
          HapticHelper.light();
          setState(() {
            _selectedFriend = isSelected ? null : friend;
          });
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No friends found' : 'No friends yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search'
                : 'Add friends to send gifts',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              HapticHelper.medium();
              if (widget.preselectedGift != null) {
                Navigator.pushNamed(
                  context,
                  AppRoutes.giftSendComposer,
                  arguments: {
                    'recipient': _selectedFriend,
                    'gift': widget.preselectedGift,
                    'isOwned': true,
                    'ownedGiftId': widget.ownedGiftId,
                  },
                );
              } else {
                Navigator.pushNamed(
                  context,
                  AppRoutes.giftSendSelection,
                  arguments: {'recipient': _selectedFriend},
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.preselectedGift != null
                      ? 'Continue to Message'
                      : 'Continue to Select Gift',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _FilterOption {
  all,
  online,
  recent,
}
