// lib/screens/feed/following_feed_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/blocs/following_feed_bloc.dart';
import 'package:freegram/widgets/feed_widgets/post_card.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class FollowingFeedTab extends StatefulWidget {
  const FollowingFeedTab({Key? key}) : super(key: key);

  @override
  State<FollowingFeedTab> createState() => _FollowingFeedTabState();
}

class _FollowingFeedTabState extends State<FollowingFeedTab> {
  final ScrollController _scrollController = ScrollController();
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // Load initial feed - BLoC is now provided by FeedScreen parent
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      // Use WidgetsBinding to ensure context is available after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          context.read<FollowingFeedBloc>().add(
                LoadFollowingFeedEvent(
                  userId: userId,
                  refresh: true,
                ),
              );
        }
      });
    }

    // Infinite scroll detection
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        context.read<FollowingFeedBloc>().add(
              LoadMoreFollowingFeedEvent(userId: userId),
            );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // BLoC is provided by FeedScreen parent
    return BlocBuilder<FollowingFeedBloc, FollowingFeedState>(
      builder: (context, state) {
        if (state is FollowingFeedLoading) {
          return _buildLoadingSkeleton();
        }

        if (state is FollowingFeedError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${state.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final userId = _auth.currentUser?.uid;
                    if (userId != null) {
                      context.read<FollowingFeedBloc>().add(
                            LoadFollowingFeedEvent(
                              userId: userId,
                              refresh: true,
                            ),
                          );
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state is FollowingFeedLoaded) {
          if (state.posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.feed, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No posts yet',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/createPost');
                    },
                    child: const Text('Create your first post!'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final userId = _auth.currentUser?.uid;
              if (userId != null) {
                context.read<FollowingFeedBloc>().add(
                      LoadFollowingFeedEvent(
                        userId: userId,
                        refresh: true,
                      ),
                    );
              }
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              controller: _scrollController,
              itemCount: state.posts.length + (state.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                // Show loading indicator at the end
                if (index == state.posts.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: AppProgressIndicator(),
                    ),
                  );
                }

                // Render PostCard with PostFeedItem
                final postItem = state.posts[index];
                return PostCard(item: postItem);
              },
            ),
          );
        }

        return const Center(child: Text('Initializing feed...'));
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          height: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[400],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 16,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 12,
                width: double.infinity,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Container(
                height: 12,
                width: 200,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.grey[300],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
