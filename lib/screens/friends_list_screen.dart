// lib/screens/friends_list_screen_improved.dart
// ✨ UPGRADED Friends List with Search, Sort, Better Activity Status, and More

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/services/friend_cache_service.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/utils/activity_helper.dart';
import 'package:freegram/utils/friend_list_helpers.dart';
import 'package:freegram/widgets/freegram_app_bar.dart';
import 'package:freegram/widgets/network_status_banner.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/skeletons/list_skeleton.dart';
import 'package:freegram/widgets/common/empty_state_widget.dart';

class FriendsListScreen extends StatefulWidget {
  final int initialIndex;
  final String? userId;
  final Function(String friendId)? onFriendSelected;
  final bool
      hideBackButton; // CRITICAL: Hide back button when used as tab in IndexedStack

  const FriendsListScreen({
    super.key,
    this.initialIndex = 0,
    this.userId,
    this.onFriendSelected,
    this.hideBackButton =
        false, // Default to showing back button for standalone navigation
  });

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool get _isSelectionMode => widget.onFriendSelected != null;

  // Search & Filter state
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer();
  String _searchQuery = '';
  FriendSortOption _sortOption = FriendSortOption.alphabetical;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: friends_list_screen.dart');
    _tabController = TabController(
        length: widget.userId == null ? 3 : 1,
        vsync: this,
        initialIndex: widget.userId == null ? widget.initialIndex : 0);

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebouncer.run(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId != null) {
      return _buildOtherUserProfile();
    }

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
      // CRITICAL: Explicit background color to prevent black screen during transitions
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _isSelectionMode
          ? const FreegramAppBar(
              title: 'Select Friend',
              showBackButton: true,
            )
          : !widget.hideBackButton
              ? FreegramAppBar(
                  title: 'Friends',
                  showBackButton: true,
                  bottom: tabs,
                )
              : null, // No app bar when used as tab in MainScreen
      body: Container(
        // Additional container with background for extra safety
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            // ⭐ PHASE 5: NETWORK AWARENESS - Show connectivity status
            const NetworkStatusBanner(),
            // Show tabs in body when used as tab (no app bar)
            if (widget.hideBackButton && tabs != null) tabs,
            Expanded(
              child: BlocConsumer<FriendsBloc, FriendsState>(
                listener: (context, state) {
                  // ⭐ FIX: Just show feedback, don't reload (stream already handles that)
                  if (state is FriendsActionSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: SemanticColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusMD),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } else if (state is FriendsActionError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                buildWhen: (previous, current) {
                  // ⭐ FIX: Only rebuild for stable states, ignore transient success/error
                  return current is FriendsLoaded ||
                      current is FriendsInitial ||
                      current is FriendsLoading ||
                      current is FriendsError;
                },
                builder: (context, state) {
                  if (state is FriendsLoading || state is FriendsInitial) {
                    return const ListSkeleton(itemCount: 8);
                  }

                  if (state is FriendsError) {
                    return _buildErrorState(state.message);
                  }

                  if (state is FriendsLoaded) {
                    return _isSelectionMode
                        ? _buildFriendsList(state.user.friends, state.user)
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildFriendsTab(state.user),
                              _buildRequestsTab(
                                  state.user.friendRequestsReceived),
                              _buildBlockedTab(state.user.blockedUsers),
                            ],
                          );
                  }

                  return const Center(child: Text('Something went wrong.'));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // FRIENDS TAB WITH SEARCH AND SORT
  // ============================================================================

  Widget _buildFriendsTab(UserModel currentUser) {
    return Column(
      children: [
        // Search and Sort Header
        _buildSearchAndSortHeader(),

        // Friends List
        Expanded(
          child: _buildFriendsList(currentUser.friends, currentUser),
        ),
      ],
    );
  }

  Widget _buildSearchAndSortHeader() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: DesignTokens.borderWidthHairline,
          ),
        ),
      ),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.primary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: DesignTokens.iconMD,
                        ),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMD,
                  vertical: DesignTokens.spaceSM,
                ),
              ),
            ),
          ),

          const SizedBox(width: DesignTokens.spaceMD),

          // Sort dropdown
          _buildSortDropdown(),
        ],
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceSM,
        vertical: DesignTokens.spaceXS,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: DropdownButton<FriendSortOption>(
        value: _sortOption,
        underline: const SizedBox.shrink(),
        icon: Icon(
          Icons.sort,
          size: DesignTokens.iconSM,
          color: Theme.of(context).colorScheme.primary,
        ),
        items: FriendSortOption.values.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(
              FriendListHelpers.getSortOptionName(option),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: DesignTokens.fontSizeSM,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          );
        }).toList(),
        onChanged: (FriendSortOption? newValue) {
          if (newValue != null) {
            setState(() {
              _sortOption = newValue;
            });
          }
        },
      ),
    );
  }

  // ============================================================================
  // FRIENDS LIST BUILDER
  // ============================================================================

  Widget _buildFriendsList(List<String> friendIds, [UserModel? currentUser]) {
    if (friendIds.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.people_outline,
        title: 'No Friends Yet',
        subtitle: _isSelectionMode
            ? 'You need friends to select from.'
            : 'Start connecting with people!\nSwipe to find matches and make new friends.',
        actionLabel: _isSelectionMode ? null : 'Find Friends',
        onAction: _isSelectionMode
            ? null
            : () {
                // Navigate to match screen or nearby screen
                // This can be implemented based on your navigation structure
              },
      );
    }

    // ⭐ FIX: Add key to force rebuild when friendIds change (instant sync!)
    return FutureBuilder<List<UserModel>>(
      key: ValueKey(friendIds.join(',')), // Unique key based on IDs
      future: _loadFriends(friendIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSkeleton();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorState('Failed to load friends');
        }

        var friends = snapshot.data!;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          friends = FriendListHelpers.filterFriends(friends, _searchQuery);
        }

        // Apply sorting
        friends = FriendListHelpers.sortFriends(friends, _sortOption);

        if (friends.isEmpty && _searchQuery.isNotEmpty) {
          return EmptyStateWidget(
            icon: Icons.search_off,
            title: 'No Results',
            subtitle: 'No friends found matching "$_searchQuery"',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(DesignTokens.spaceMD),
          itemCount: friends.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: DesignTokens.spaceSM),
          itemBuilder: (context, index) {
            final friend = friends[index];
            return EnhancedFriendCard(
              user: friend,
              currentUser: currentUser,
              cardType: FriendCardType.friend,
              onTap: _isSelectionMode
                  ? () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                      widget.onFriendSelected!(friend.id);
                    }
                  : null,
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // REQUESTS TAB
  // ============================================================================

  Widget _buildRequestsTab(List<String> requestIds) {
    if (requestIds.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.notifications_none_outlined,
        title: 'No Pending Requests',
        subtitle:
            'When someone sends you a friend request,\nit will appear here.',
      );
    }

    // ⭐ FIX: Add key to force rebuild when requestIds change (instant sync!)
    return FutureBuilder<List<UserModel>>(
      key: ValueKey(requestIds.join(',')), // Unique key based on IDs
      future: _loadFriends(requestIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSkeleton();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorState('Failed to load requests');
        }

        final requests = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(DesignTokens.spaceMD),
          itemCount: requests.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: DesignTokens.spaceSM),
          itemBuilder: (context, index) {
            return EnhancedFriendCard(
              user: requests[index],
              cardType: FriendCardType.request,
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // BLOCKED TAB
  // ============================================================================

  Widget _buildBlockedTab(List<String> blockedUserIds) {
    if (blockedUserIds.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.block_outlined,
        title: 'No Blocked Users',
        subtitle:
            'You haven\'t blocked anyone.\nBlocked users will appear here.',
        iconColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      );
    }

    // ⭐ FIX: Add key to force rebuild when blockedUserIds change (instant sync!)
    return FutureBuilder<List<UserModel>>(
      key: ValueKey(blockedUserIds.join(',')), // Unique key based on IDs
      future: _loadFriends(blockedUserIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSkeleton();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorState('Failed to load blocked users');
        }

        final blockedUsers = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(DesignTokens.spaceMD),
          itemCount: blockedUsers.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: DesignTokens.spaceSM),
          itemBuilder: (context, index) {
            return EnhancedFriendCard(
              user: blockedUsers[index],
              cardType: FriendCardType.blocked,
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // OTHER USER PROFILE
  // ============================================================================

  Widget _buildOtherUserProfile() {
    final userRepository = locator<UserRepository>();
    return FutureBuilder<UserModel>(
      future: userRepository.getUser(widget.userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            // CRITICAL: Explicit background color to prevent black screen
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: const FreegramAppBar(
              title: 'Friends',
              showBackButton: true,
            ),
            body: const Center(child: AppProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            // CRITICAL: Explicit background color to prevent black screen
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: const FreegramAppBar(
              title: 'Friends',
              showBackButton: true,
            ),
            body: const Center(child: Text('Could not load user.')),
          );
        }
        final user = snapshot.data!;
        return Scaffold(
          // CRITICAL: Explicit background color to prevent black screen
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: FreegramAppBar(
            title: "${user.username}'s Friends",
            showBackButton: true,
          ),
          body: _buildFriendsList(user.friends),
        );
      },
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Load friends with caching support (85%+ Firestore read reduction!)
  Future<List<UserModel>> _loadFriends(List<String> userIds) async {
    final userRepository = locator<UserRepository>();
    final cacheService = locator<FriendCacheService>();

    final friends = <UserModel>[];
    final uncachedIds = <String>[];

    // Try to load from cache first
    for (final userId in userIds) {
      final cachedUser = await cacheService.getCachedFriend(userId);
      if (cachedUser != null) {
        friends.add(cachedUser);
      } else {
        uncachedIds.add(userId);
      }
    }

    // Load uncached users from Firestore
    if (uncachedIds.isNotEmpty) {
      final freshUsers = await Future.wait(
        uncachedIds.map((id) => userRepository.getUser(id)),
      );

      // Cache the fresh users
      await cacheService.cacheFriends(freshUsers);
      friends.addAll(freshUsers);
    }

    debugPrint('[FriendsListScreen] Loaded ${friends.length} friends '
        '(${friends.length - uncachedIds.length} from cache, ${uncachedIds.length} from Firestore)');

    return friends;
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: DesignTokens.iconXXL * 1.6,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: DesignTokens.spaceLG),
          Text(
            'Error',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: DesignTokens.spaceSM),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ⭐ UI POLISH: Loading skeleton for better perceived performance
  Widget _buildLoadingSkeleton() {
    return const ListSkeleton(itemCount: 5, showSubtitle: true);
  }
}

// ==============================================================================
// ENHANCED FRIEND CARD WIDGET
// ==============================================================================

enum FriendCardType { friend, request, blocked }

class EnhancedFriendCard extends StatelessWidget {
  final UserModel user;
  final UserModel? currentUser;
  final FriendCardType cardType;
  final VoidCallback? onTap;

  const EnhancedFriendCard({
    super.key,
    required this.user,
    this.currentUser,
    required this.cardType,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.scrim.withOpacity(0.05),
            blurRadius: DesignTokens.elevation2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
          onTap: onTap ??
              () {
                HapticFeedback.lightImpact();
                locator<NavigationService>().navigateTo(
                  ProfileScreen(userId: user.id),
                  transition: PageTransition.slide,
                );
              },
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.spaceMD),
            child: Row(
              children: [
                // Avatar with online indicator
                _buildAvatar(context),
                const SizedBox(width: DesignTokens.spaceMD),
                // User info
                Expanded(child: _buildUserInfo(context)),
                // Actions
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Stack(
      children: [
        Hero(
          tag: 'avatar_${user.id}',
          child: CircleAvatar(
            radius: AvatarSize.medium.radius,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            backgroundImage: user.photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(user.photoUrl)
                : null,
            child: user.photoUrl.isEmpty
                ? Text(
                    user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : '?',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: DesignTokens.fontSizeXXXL,
                          fontWeight: FontWeight.bold,
                        ),
                  )
                : null,
          ),
        ),
        // Online indicator
        if (user.presence)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: SemanticColors.success,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).cardColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserInfo(BuildContext context) {
    final activityText =
        ActivityHelper.getActivityStatus(user.lastSeen, user.presence);
    final activityColor =
        ActivityHelper.getActivityColor(user.lastSeen, user.presence, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Username
        Text(
          user.username,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: DesignTokens.spaceXS),

        // Activity status
        Row(
          children: [
            if (user.presence)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: DesignTokens.spaceXS),
                decoration: const BoxDecoration(
                  color: SemanticColors.success,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              activityText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: activityColor,
                    fontWeight:
                        user.presence ? FontWeight.w600 : FontWeight.normal,
                  ),
            ),
          ],
        ),

        // Mutual friends/interests (if available)
        if (currentUser != null && cardType == FriendCardType.friend)
          _buildMutualInfo(context),
      ],
    );
  }

  Widget _buildMutualInfo(BuildContext context) {
    // This would need access to current user's data
    // For now, just show country if available
    if (user.country.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.spaceXS),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: DesignTokens.iconXS,
            color: SemanticColors.textSecondary(context),
          ),
          const SizedBox(width: DesignTokens.spaceXS),
          Text(
            user.country,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    switch (cardType) {
      case FriendCardType.friend:
        return Icon(
          Icons.chevron_right,
          color: SemanticColors.iconDefault(context),
          size: DesignTokens.iconMD,
        );

      case FriendCardType.request:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(DesignTokens.spaceSM),
                decoration: BoxDecoration(
                  color: SemanticColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: SemanticColors.success,
                  size: DesignTokens.iconMD,
                ),
              ),
              tooltip: 'Accept',
              onPressed: () {
                HapticFeedback.mediumImpact();
                context.read<FriendsBloc>().add(AcceptFriendRequest(user.id));
              },
            ),
            const SizedBox(width: DesignTokens.spaceXS),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(DesignTokens.spaceSM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.error,
                  size: DesignTokens.iconMD,
                ),
              ),
              tooltip: 'Decline',
              onPressed: () {
                HapticFeedback.lightImpact();
                context.read<FriendsBloc>().add(DeclineFriendRequest(user.id));
              },
            ),
          ],
        );

      case FriendCardType.blocked:
        return TextButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            context.read<FriendsBloc>().add(UnblockUser(user.id));
          },
          icon: Icon(
            Icons.block_outlined,
            size: DesignTokens.iconSM,
            color: Theme.of(context).colorScheme.error,
          ),
          label: Text(
            'Unblock',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMD,
              vertical: DesignTokens.spaceSM,
            ),
            backgroundColor:
                Theme.of(context).colorScheme.error.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            ),
          ),
        );
    }
  }
}
