// lib/screens/search_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/search_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/search_repository.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/models/page_model.dart';
import 'package:freegram/widgets/feed_widgets/post_card.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/screens/page_profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SearchBloc(
        searchRepository: locator<SearchRepository>(),
        postRepository: locator<PostRepository>(),
      ),
      child: const _SearchScreenView(),
    );
  }
}

class _SearchScreenView extends StatefulWidget {
  const _SearchScreenView();

  @override
  State<_SearchScreenView> createState() => _SearchScreenViewState();
}

class _SearchScreenViewState extends State<_SearchScreenView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: BlocBuilder<SearchBloc, SearchState>(
            builder: (context, state) {
              // Only show tabs when we have search results
              if (state is SearchResultsLoaded) {
                return TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Posts'),
                    Tab(text: 'Users'),
                    Tab(text: 'Pages'),
                    Tab(text: 'Hashtags'),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search posts, users, pages, hashtags...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<SearchBloc>().add(
                                const SearchQueryChanged(''),
                              );
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              onChanged: (value) {
                context.read<SearchBloc>().add(
                      SearchQueryChanged(value),
                    );
              },
            ),
          ),
          // Results
          Expanded(
            child: BlocBuilder<SearchBloc, SearchState>(
              builder: (context, state) {
                if (state is SearchInitial) {
                  return _buildInitialView(context, state);
                } else if (state is SearchLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is SearchResultsLoaded) {
                  return _buildResultsView(context, state);
                } else if (state is SearchError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${state.message}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (_searchController.text.isNotEmpty) {
                              context.read<SearchBloc>().add(
                                    SearchQueryChanged(_searchController.text),
                                  );
                            }
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialView(BuildContext context, SearchInitial state) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Recent Searches
        if (state.recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.read<SearchBloc>().add(const ClearSearchHistory());
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...state.recentSearches.map((search) => ListTile(
                leading: const Icon(Icons.history),
                title: Text(search),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  _searchController.text = search;
                  context.read<SearchBloc>().add(
                        SearchQueryChanged(search),
                      );
                },
              )),
          const Divider(),
        ],
        // Trending Hashtags
        if (state.trendingHashtags.isNotEmpty) ...[
          const Text(
            'Trending Hashtags',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: state.trendingHashtags.map((hashtag) {
              return InkWell(
                onTap: () {
                  _searchController.text = '#$hashtag';
                  context.read<SearchBloc>().add(
                        SearchQueryChanged('#$hashtag'),
                      );
                },
                child: Chip(
                  avatar: const Icon(Icons.tag, size: 18),
                  label: Text('#$hashtag'),
                ),
              );
            }).toList(),
          ),
        ],
        // Empty state
        if (state.recentSearches.isEmpty && state.trendingHashtags.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Start searching to find posts, users, pages, and hashtags',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultsView(BuildContext context, SearchResultsLoaded state) {
    if (!state.hasResults) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        // All tab - combined view
        _buildAllTab(context, state),
        // Posts tab
        _buildPostsTab(context, state.posts),
        // Users tab
        _buildUsersTab(context, state.users),
        // Pages tab
        _buildPagesTab(context, state.pages),
        // Hashtags tab
        _buildHashtagsTab(context, state.hashtags),
      ],
    );
  }

  Widget _buildAllTab(BuildContext context, SearchResultsLoaded state) {
    final allItems = <Widget>[];

    // Add posts
    if (state.posts.isNotEmpty) {
      allItems.add(_buildSectionHeader('Posts', state.posts.length));
      allItems.addAll(
        state.posts.take(3).map((post) => PostCard(
              item: PostFeedItem(
                post: post,
                displayType: PostDisplayType.organic,
              ),
            )),
      );
      if (state.posts.length > 3) {
        allItems.add(
          TextButton(
            onPressed: () => _tabController.animateTo(1),
            child: Text('View all ${state.posts.length} posts'),
          ),
        );
      }
    }

    // Add users
    if (state.users.isNotEmpty) {
      allItems.add(_buildSectionHeader('Users', state.users.length));
      allItems.addAll(
        state.users.take(3).map((user) => _buildUserTile(context, user)),
      );
      if (state.users.length > 3) {
        allItems.add(
          TextButton(
            onPressed: () => _tabController.animateTo(2),
            child: Text('View all ${state.users.length} users'),
          ),
        );
      }
    }

    // Add pages
    if (state.pages.isNotEmpty) {
      allItems.add(_buildSectionHeader('Pages', state.pages.length));
      allItems.addAll(
        state.pages.take(3).map((page) => _buildPageTile(context, page)),
      );
      if (state.pages.length > 3) {
        allItems.add(
          TextButton(
            onPressed: () => _tabController.animateTo(3),
            child: Text('View all ${state.pages.length} pages'),
          ),
        );
      }
    }

    // Add hashtags
    if (state.hashtags.isNotEmpty) {
      allItems.add(_buildSectionHeader('Hashtags', state.hashtags.length));
      allItems.addAll(
        state.hashtags.take(3).map((post) => PostCard(
              item: PostFeedItem(
                post: post,
                displayType: PostDisplayType.organic,
              ),
            )),
      );
      if (state.hashtags.length > 3) {
        allItems.add(
          TextButton(
            onPressed: () => _tabController.animateTo(4),
            child: Text('View all ${state.hashtags.length} hashtag results'),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: allItems,
    );
  }

  Widget _buildPostsTab(BuildContext context, List<PostModel> posts) {
    if (posts.isEmpty) {
      return const Center(
        child: Text('No posts found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return PostCard(
          item: PostFeedItem(
            post: posts[index],
            displayType: PostDisplayType.organic,
          ),
        );
      },
    );
  }

  Widget _buildUsersTab(BuildContext context, List<UserModel> users) {
    if (users.isEmpty) {
      return const Center(
        child: Text('No users found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: users.length,
      itemBuilder: (context, index) {
        return _buildUserTile(context, users[index]);
      },
    );
  }

  Widget _buildPagesTab(BuildContext context, List<PageModel> pages) {
    if (pages.isEmpty) {
      return const Center(
        child: Text('No pages found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: pages.length,
      itemBuilder: (context, index) {
        return _buildPageTile(context, pages[index]);
      },
    );
  }

  Widget _buildHashtagsTab(BuildContext context, List<PostModel> hashtags) {
    if (hashtags.isEmpty) {
      return const Center(
        child: Text('No hashtag results found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: hashtags.length,
      itemBuilder: (context, index) {
        return PostCard(
          item: PostFeedItem(
            post: hashtags[index],
            displayType: PostDisplayType.organic,
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        '$title ($count)',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, UserModel user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.photoUrl.isNotEmpty
            ? CachedNetworkImageProvider(user.photoUrl)
            : null,
        child: user.photoUrl.isEmpty ? const Icon(Icons.person) : null,
      ),
      title: Text(user.username),
      subtitle: user.bio.isNotEmpty ? Text(user.bio) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: user.id),
          ),
        );
      },
    );
  }

  Widget _buildPageTile(BuildContext context, PageModel page) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: page.profileImageUrl.isNotEmpty
            ? CachedNetworkImageProvider(page.profileImageUrl)
            : null,
        child: page.profileImageUrl.isEmpty ? const Icon(Icons.pages) : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(page.pageName),
          ),
          if (page.verificationStatus == VerificationStatus.verified) ...[
            const SizedBox(width: 8),
            const Icon(Icons.verified, size: 18, color: Colors.blue),
          ],
        ],
      ),
      subtitle: page.description.isNotEmpty ? Text(page.description) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PageProfileScreen(pageId: page.pageId),
          ),
        );
      },
    );
  }
}
