// lib/screens/trending_feed_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/blocs/unified_feed_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/services/ad_service.dart';
import 'package:freegram/utils/enums.dart';
import 'package:freegram/widgets/feed_widgets/post_card.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class TrendingFeedTab extends StatefulWidget {
  const TrendingFeedTab({Key? key}) : super(key: key);

  @override
  State<TrendingFeedTab> createState() => _TrendingFeedTabState();
}

class _TrendingFeedTabState extends State<TrendingFeedTab> {
  TimeFilter _selectedFilter = TimeFilter.allTime;
  late UnifiedFeedBloc _feedBloc;
  final ScrollController _scrollController = ScrollController();
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    final userId = _auth.currentUser?.uid ?? '';
    _feedBloc = UnifiedFeedBloc(
      postRepository: locator<PostRepository>(),
      userRepository: locator<UserRepository>(),
      adService: locator<AdService>(),
    );

    // Load initial feed
    _feedBloc.add(LoadUnifiedFeedEvent(
      userId: userId,
      refresh: true,
      timeFilter: _selectedFilter,
    ));

    // Infinite scroll detection
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        _feedBloc.add(LoadMoreUnifiedFeedEvent(
          userId: userId,
          timeFilter: _selectedFilter,
        ));
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _feedBloc.close();
    super.dispose();
  }

  void _onFilterChanged(TimeFilter newFilter) {
    setState(() {
      _selectedFilter = newFilter;
    });
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      _feedBloc.add(LoadUnifiedFeedEvent(
        userId: userId,
        refresh: true,
        timeFilter: _selectedFilter,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _feedBloc,
      child: Scaffold(
        body: Column(
          children: [
            // Trending Hashtags Section (Optional Improvement)
            _buildTrendingHashtagsSection(),

            // Time Filters Section
            _buildTimeFiltersSection(),

            // Posts List
            Expanded(
              child: BlocProvider.value(
                value: _feedBloc,
                child: BlocBuilder<UnifiedFeedBloc, UnifiedFeedState>(
                  builder: (context, state) {
                    if (state is UnifiedFeedLoading) {
                      return const Center(child: AppProgressIndicator());
                    }

                    if (state is UnifiedFeedError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: ${state.error}'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                final userId = _auth.currentUser?.uid;
                                if (userId != null) {
                                  _feedBloc.add(LoadUnifiedFeedEvent(
                                    userId: userId,
                                    refresh: true,
                                    timeFilter: _selectedFilter,
                                  ));
                                }
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (state is UnifiedFeedLoaded) {
                      // Filter to only show trending posts (PostFeedItem with trending display type)
                      final trendingPosts = state.items
                          .whereType<PostFeedItem>()
                          .where((item) =>
                              item.displayType == PostDisplayType.trending)
                          .map((item) => item.post)
                          .toList();

                      if (trendingPosts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.trending_up,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'No trending posts yet',
                                style: TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Check back later for trending content!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          final userId = _auth.currentUser?.uid;
                          if (userId != null) {
                            _feedBloc.add(LoadUnifiedFeedEvent(
                              userId: userId,
                              refresh: true,
                              timeFilter: _selectedFilter,
                            ));
                          }
                          await Future.delayed(
                              const Duration(milliseconds: 500));
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: trendingPosts.length,
                          itemBuilder: (context, index) {
                            return PostCard(
                              item: PostFeedItem(
                                post: trendingPosts[index],
                                displayType: PostDisplayType.trending,
                              ),
                            );
                          },
                        ),
                      );
                    }

                    return const Center(child: Text('Initializing feed...'));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingHashtagsSection() {
    final postRepository = locator<PostRepository>();

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: FutureBuilder<List<String>>(
        future: postRepository.getTrendingHashtags(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: SizedBox(
              height: 20,
              width: 20,
              child: AppProgressIndicator(strokeWidth: 2),
            ));
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return const SizedBox.shrink(); // Hide section if no hashtags
          }

          final hashtags = snapshot.data!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Trending Hashtags',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: hashtags.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Chip(
                        label: Text(
                          hashtags[index],
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.3),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 0.5,
                        ),
                        onDeleted: () {
                          // Optional: Allow tapping to search/filter by hashtag
                        },
                        deleteIcon: const Icon(Icons.trending_up, size: 14),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeFiltersSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const Text(
            'Time:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFilterChip(
                  label: 'Today',
                  filter: TimeFilter.today,
                ),
                _buildFilterChip(
                  label: 'This Week',
                  filter: TimeFilter.thisWeek,
                ),
                _buildFilterChip(
                  label: 'All Time',
                  filter: TimeFilter.allTime,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required TimeFilter filter,
  }) {
    final isSelected = _selectedFilter == filter;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onFilterChanged(filter),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
