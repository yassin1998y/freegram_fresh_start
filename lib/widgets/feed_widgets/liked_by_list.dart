// lib/widgets/feed_widgets/liked_by_list.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class LikedByList extends StatefulWidget {
  final String postId;
  final int totalLikes;

  const LikedByList({
    Key? key,
    required this.postId,
    required this.totalLikes,
  }) : super(key: key);

  @override
  State<LikedByList> createState() => _LikedByListState();
}

class _LikedByListState extends State<LikedByList> {
  final List<String> _likedUserIds = [];
  final Map<String, Map<String, dynamic>> _userData = {};
  bool _isLoading = true;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadLikedUsers();
  }

  Future<void> _loadLikedUsers() async {
    if (!_hasMore || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final userIds = await locator<PostRepository>().getLikedByUsers(
        widget.postId,
        lastDocument: _lastDocument,
      );

      if (userIds.isNotEmpty) {
        // Get user data for each user ID
        final usersRef = FirebaseFirestore.instance.collection('users');
        final userSnapshots = await Future.wait(
          userIds.map((userId) => usersRef.doc(userId).get()),
        );

        final newUserData = <String, Map<String, dynamic>>{};
        for (var i = 0; i < userIds.length; i++) {
          if (userSnapshots[i].exists) {
            newUserData[userIds[i]] = userSnapshots[i].data()!;
          }
        }

        setState(() {
          _likedUserIds.addAll(userIds);
          _userData.addAll(newUserData);
          _hasMore = userIds.length == 20; // Assuming limit is 20
        });
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onUserTap(String userId) {
    // TODO: Navigate to user profile screen
    // For now, just show a snackbar
    final username = _userData[userId]?['username'] ?? 'Unknown';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('View profile: $username')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[300]!,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.favorite,
                    color: Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${widget.totalLikes} ${widget.totalLikes == 1 ? 'like' : 'likes'}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Users list
            Flexible(
              child: _isLoading && _likedUserIds.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: const AppProgressIndicator(),
                      ),
                    )
                  : _likedUserIds.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.favorite_border,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No likes yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _likedUserIds.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _likedUserIds.length) {
                              // Load more button
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: _isLoading
                                    ? const Center(
                                        child: const AppProgressIndicator(),
                                      )
                                    : TextButton(
                                        onPressed: _loadLikedUsers,
                                        child: const Text('Load more'),
                                      ),
                              );
                            }

                            final userId = _likedUserIds[index];
                            final userData = _userData[userId];
                            final username = userData?['username'] ?? 'Unknown';
                            final photoUrl = userData?['photoUrl'] ?? '';

                            return ListTile(
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundImage: photoUrl.isNotEmpty
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl.isEmpty
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(
                                username,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              subtitle: userData?['bio'] != null &&
                                      userData!['bio'].toString().isNotEmpty
                                  ? Text(
                                      userData['bio'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey[600]),
                                    )
                                  : null,
                              onTap: () => _onUserTap(userId),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
