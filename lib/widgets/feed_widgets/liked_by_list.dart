// lib/widgets/feed_widgets/liked_by_list.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/screens/profile_screen.dart';

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
    // CRITICAL FIX: Allow initial load even if _isLoading is true
    // Only prevent loading if we're already loading AND have data, or if no more data
    if ((_isLoading && _likedUserIds.isNotEmpty) || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      // CRITICAL FIX: Get reactions with documents for pagination
      Query reactionsQuery = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('reactions')
          .orderBy('timestamp', descending: true)
          .limit(20);

      if (_lastDocument != null) {
        reactionsQuery = reactionsQuery.startAfterDocument(_lastDocument!);
      }

      final reactionsSnapshot = await reactionsQuery.get();

      if (reactionsSnapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      // Update last document for pagination
      _lastDocument = reactionsSnapshot.docs.last;

      // Extract user IDs from document IDs (userId is the document ID)
      final userIds = reactionsSnapshot.docs.map((doc) => doc.id).toList();

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
        // If we got less than 20, there's no more data
        _hasMore = reactionsSnapshot.docs.length == 20;
      });
    } catch (e) {
      debugPrint('LikedByList: Error loading users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: ${e.toString()}')),
        );
      }
      setState(() => _hasMore = false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onUserTap(String userId) async {
    // Navigate to user profile screen
    try {
      Navigator.of(context).pop(); // Close the dialog first
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: userId),
        ),
      );
    } catch (e) {
      debugPrint('LikedByList: Error navigating to profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open profile: ${e.toString()}')),
        );
      }
    }
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
                  Icon(
                    Icons.favorite,
                    size: DesignTokens.iconLG,
                    color: SemanticColors.reactionLiked,
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
                        child: AppProgressIndicator(),
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
                                  size: DesignTokens.iconXXL * 1.5,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(DesignTokens.opacityMedium),
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
                                        child: AppProgressIndicator(),
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
