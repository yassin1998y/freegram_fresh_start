import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/repositories/friend_repository.dart';
import 'package:freegram/screens/improved_chat_screen.dart';
import 'package:freegram/screens/edit_profile_screen.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/utils/mutual_friends_helper.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/widgets/feed_widgets/post_card.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/widgets/reels/user_reels_tab.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/profile/gift_showcase.dart';
import 'package:freegram/screens/analytics_dashboard_screen.dart';
import 'package:freegram/screens/achievements_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 SCREEN: profile_screen.dart');
    // Keep FriendsBloc for friend status actions
    return BlocProvider(
      create: (context) => FriendsBloc(
        userRepository: locator<UserRepository>(),
        friendRepository: locator<FriendRepository>(),
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
      locator<NavigationService>().navigateTo(
        ImprovedChatScreen(
          chatId: chatId,
          otherUsername: user.username,
        ),
        transition: PageTransition.slide,
      );
    }
  }

  void _showProfileOptions(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusXL),
        ),
      ),
      builder: (bottomSheetContext) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DesignTokens.radiusXL),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: DesignTokens.spaceMD),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(
                      DesignTokens.opacityMedium,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceLG),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusSM),
                    ),
                    child: Icon(
                      Icons.block_outlined,
                      color: theme.colorScheme.error,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Block User',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(bottomSheetContext);
                    _confirmBlockUser(context, user);
                  },
                ),
                const SizedBox(height: DesignTokens.spaceMD),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmBlockUser(BuildContext context, UserModel user) async {
    final bool? shouldBlock = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Block User?'),
          content: Text(
            'Are you sure you want to block ${user.username}? They won\'t be able to message you or see your profile.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Block',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );

    if (shouldBlock == true && mounted) {
      HapticFeedback.mediumImpact();

      // Block user
      context.read<FriendsBloc>().add(BlockUser(user.id));

      // OPTIMIZATION: Use BlocListener pattern instead of manual stream subscription
      // This is handled by BlocConsumer in _buildOtherUserActions, so we don't need
      // a separate subscription here. The BlocConsumer will handle state changes.
      // Just show a loading indicator and let BlocConsumer handle the result
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRepository = locator<UserRepository>();
    // final postRepository = locator<PostRepository>(); // Remove PostRepository instance
    final isCurrentUserProfile =
        FirebaseAuth.instance.currentUser?.uid == widget.userId;

    return Scaffold(
      // CRITICAL: Explicit background color to prevent black screen during transitions
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<UserModel>(
        stream: userRepository.getUserStream(widget.userId),
        builder: (context, userSnapshot) {
          // CRITICAL: Wrap all states in Scaffold to ensure proper background
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: const Center(child: AppProgressIndicator()),
            );
          }
          if (!userSnapshot.hasData) {
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: const Center(child: Text('User not found.')),
            );
          }
          if (userSnapshot.hasError) {
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: Center(child: Text('Error: ${userSnapshot.error}')),
            );
          }

          final user = userSnapshot.data!;

          // Modern NestedScrollView with tabs for Posts and Reels
          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  // Match FreegramAppBar branding style
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Full "Freegram" branding
                      Text(
                        'Freegram',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: DesignTokens.fontSizeXXL,
                              fontWeight: FontWeight.bold,
                              color: SonarPulseTheme.primaryAccent,
                              letterSpacing: DesignTokens.letterSpacingTight,
                            ),
                      ),
                      const SizedBox(width: DesignTokens.spaceMD),
                      Container(
                        width: 2,
                        height: 20,
                        decoration: BoxDecoration(
                          color: SemanticColors.textSecondary(context)
                              .withOpacity(DesignTokens.opacityMedium),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spaceMD),
                      Text(
                        'Profile',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontSize: DesignTokens.fontSizeXL,
                                  fontWeight: FontWeight.w500,
                                ),
                      ),
                    ],
                  ),
                  centerTitle: true,
                  floating: true,
                  pinned: true,
                  expandedHeight: 0, // No extra height
                  actions: [
                    if (!isCurrentUserProfile)
                      // Options menu for other users
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded),
                        tooltip: 'More options',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _showProfileOptions(context, user);
                        },
                      ),
                    const SizedBox(width: DesignTokens.spaceXS),
                  ],
                ),
                SliverToBoxAdapter(
                  child: _ModernProfileHeader(
                    user: user,
                    isCurrentUserProfile: isCurrentUserProfile,
                    onStartChat: () => _startChat(context, user),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Posts'),
                        Tab(text: 'Reels'),
                      ],
                      indicatorColor: SonarPulseTheme.primaryAccent,
                      labelColor: SonarPulseTheme.primaryAccent,
                      unselectedLabelColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(DesignTokens.opacityMedium),
                      labelStyle: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                // Posts tab - Use ListView for proper scrolling
                _UserPostsSection(userId: widget.userId),
                // Reels tab
                UserReelsTab(userId: widget.userId),
              ],
            ),
          );
        },
      ),
    );
  }
}

// User Posts Section Widget (moved outside ProfileScreen)
class _UserPostsSection extends StatefulWidget {
  final String userId;

  const _UserPostsSection({required this.userId});

  @override
  State<_UserPostsSection> createState() => _UserPostsSectionState();
}

class _UserPostsSectionState extends State<_UserPostsSection> {
  final PostRepository _postRepository = locator<PostRepository>();
  List<PostModel> _pinnedPosts = [];
  List<PostModel> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      // Load pinned posts first
      final pinned = await _postRepository.getPinnedPosts(widget.userId);

      // Load all posts (which will include pinned ones)
      final allPosts =
          await _postRepository.getUserPosts(userId: widget.userId);

      // Separate pinned from non-pinned
      final pinnedIds = pinned.map((p) => p.id).toSet();
      final nonPinned =
          allPosts.where((p) => !pinnedIds.contains(p.id)).toList();

      if (mounted) {
        setState(() {
          _pinnedPosts = pinned;
          _posts = nonPinned;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ProfileScreen: Error loading posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(DesignTokens.spaceMD),
        child: Center(child: AppProgressIndicator()),
      );
    }

    if (_pinnedPosts.isEmpty && _posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.grid_off_outlined,
                size: DesignTokens.iconXXL,
                color: SemanticColors.textSecondary(context),
              ),
              const SizedBox(height: DesignTokens.spaceSM),
              Text(
                'No posts yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: SemanticColors.textSecondary(context),
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Pinned posts section
        if (_pinnedPosts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMD,
              vertical: DesignTokens.spaceSM,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.push_pin,
                  size: DesignTokens.iconMD,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                Text(
                  'Pinned',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: DesignTokens.fontSizeMD,
                      ),
                ),
              ],
            ),
          ),
          ..._pinnedPosts.map((post) => PostCard(
                item: PostFeedItem(
                  post: post,
                  displayType: PostDisplayType.organic,
                ),
              )),
          const SizedBox(height: DesignTokens.spaceSM),
        ],
        // Regular posts section
        if (_posts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMD,
              vertical: DesignTokens.spaceSM,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.grid_view_outlined,
                  size: DesignTokens.iconMD,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                Text(
                  'Posts (${_posts.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: DesignTokens.fontSizeMD,
                      ),
                ),
              ],
            ),
          ),
          ..._posts.map((post) => PostCard(
                item: PostFeedItem(
                  post: post,
                  displayType: PostDisplayType.organic,
                ),
              )),
        ],
      ],
    );
  }
}

/// Modern profile header with professional UX and card-based layout
class _ModernProfileHeader extends StatelessWidget {
  final UserModel user;
  final bool isCurrentUserProfile;
  final VoidCallback onStartChat;

  const _ModernProfileHeader({
    required this.user,
    required this.isCurrentUserProfile,
    required this.onStartChat,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Hero Section - Avatar and Name
        _buildHeroSection(context),

        const SizedBox(height: DesignTokens.spaceXL),

        // Action Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
          child: isCurrentUserProfile
              ? _buildCurrentUserActions(context)
              : _buildOtherUserActions(context),
        ),

        const SizedBox(height: DesignTokens.spaceXL),

        // Stats Card
        _buildStatsCard(context),

        const SizedBox(height: DesignTokens.spaceMD),

        // Mutual Friends/Interests Card (for other users)
        if (!isCurrentUserProfile)
          BlocBuilder<FriendsBloc, FriendsState>(
            builder: (context, state) {
              if (state is FriendsLoaded) {
                return _buildMutualConnectionsCard(context, state.user);
              }
              return const SizedBox.shrink();
            },
          ),

        if (!isCurrentUserProfile) const SizedBox(height: DesignTokens.spaceMD),

        // Bio Card (if available)
        if (user.bio.isNotEmpty) ...[
          _buildBioCard(context),
          const SizedBox(height: DesignTokens.spaceMD),
        ],

        // Interests Card (if available)
        if (user.interests.isNotEmpty) ...[
          _buildInterestsCard(context),
          const SizedBox(height: DesignTokens.spaceMD),
        ],

        // Gift Showcase
        GiftShowcase(
          userId: user.id,
          isOwnProfile: isCurrentUserProfile,
        ),

        const SizedBox(height: DesignTokens.spaceXL),
      ],
    );
  }

  /// Hero section with centered avatar and username
  Widget _buildHeroSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceXL),
      child: Column(
        children: [
          // Profile Avatar
          Hero(
            tag: 'profile_${user.id}',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 60,
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
                        style: const TextStyle(
                          fontSize: DesignTokens.fontSizeHero,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ),

          const SizedBox(height: DesignTokens.spaceMD),

          // Username
          Text(
            user.username,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
            textAlign: TextAlign.center,
          ),

          if (user.country.isNotEmpty) ...[
            const SizedBox(height: DesignTokens.spaceSM),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: DesignTokens.spaceXS),
                Text(
                  user.country,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Action buttons for current user (Edit Profile)
  Widget _buildCurrentUserActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              locator<NavigationService>().navigateTo(
                EditProfileScreen(currentUserData: user.toMap()),
                transition: PageTransition.slide,
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: DesignTokens.spaceMD,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
            ),
            child: const Icon(Icons.edit_outlined, size: 20),
          ),
        ),
        const SizedBox(width: DesignTokens.spaceSM),
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              locator<NavigationService>().navigateTo(
                const AnalyticsDashboardScreen(),
                transition: PageTransition.slide,
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: DesignTokens.spaceMD,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
            ),
            child: const Icon(Icons.analytics_outlined, size: 20),
          ),
        ),
        const SizedBox(width: DesignTokens.spaceSM),
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              locator<NavigationService>().navigateTo(
                const AchievementsScreen(),
                transition: PageTransition.slide,
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: DesignTokens.spaceMD,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
            ),
            child: const Icon(Icons.emoji_events_outlined, size: 20),
          ),
        ),
      ],
    );
  }

  /// Action buttons for other users (Add Friend, Message, etc.)
  Widget _buildOtherUserActions(BuildContext context) {
    // ⭐ FIX: Use BlocConsumer to handle transient states without showing spinner
    return BlocConsumer<FriendsBloc, FriendsState>(
      listener: (context, state) {
        // Handle transient success/error states with snackbars
        if (state is FriendsActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
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
        // Only rebuild for loaded states, ignore transient states
        return current is FriendsLoaded ||
            current is FriendsInitial ||
            current is FriendsLoading ||
            current is FriendsError;
      },
      builder: (context, state) {
        if (state is FriendsLoaded) {
          final currentUser = state.user;
          bool isFriend = currentUser.friends.contains(user.id);
          bool requestSent = currentUser.friendRequestsSent.contains(user.id);
          bool requestReceived =
              currentUser.friendRequestsReceived.contains(user.id);
          bool isBlocked = currentUser.blockedUsers.contains(user.id);

          if (isBlocked) {
            return OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.read<FriendsBloc>().add(UnblockUser(user.id));
              },
              icon: const Icon(Icons.block_outlined, size: 20),
              label: const Text('Unblock'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceLG,
                  vertical: DesignTokens.spaceMD,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                ),
              ),
            );
          }

          if (requestReceived) {
            return ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.read<FriendsBloc>().add(AcceptFriendRequest(user.id));
              },
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Accept Friend Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceLG,
                  vertical: DesignTokens.spaceMD,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                ),
              ),
            );
          }

          return Row(
            children: [
              Expanded(
                child: isFriend || requestSent
                    ? OutlinedButton.icon(
                        onPressed: isFriend
                            ? () {
                                HapticFeedback.lightImpact();
                                _confirmRemoveFriend(context);
                              }
                            : null,
                        icon: Icon(
                          isFriend ? Icons.check : Icons.schedule,
                          size: 20,
                        ),
                        label: Text(isFriend ? 'Friends' : 'Pending'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceMD,
                            vertical: DesignTokens.spaceMD,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusMD),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context
                              .read<FriendsBloc>()
                              .add(SendFriendRequest(user.id));
                        },
                        icon: const Icon(Icons.person_add_outlined, size: 20),
                        label: const Text('Add Friend'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceMD,
                            vertical: DesignTokens.spaceMD,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusMD),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: DesignTokens.spaceMD),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onStartChat();
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceMD,
                      vertical: DesignTokens.spaceMD,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMD),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spaceMD),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(
                      context,
                      '/giftSendSelection',
                      arguments: {'recipient': user},
                    );
                  },
                  icon: const Icon(Icons.card_giftcard, size: 20),
                  label: const Text('Send Gift'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceMD,
                      vertical: DesignTokens.spaceMD,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMD),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Only show loading spinner for initial load or actual loading state
        if (state is FriendsLoading || state is FriendsInitial) {
          return const Center(child: AppProgressIndicator(strokeWidth: 2));
        }

        // For error state, show a simplified button layout
        return ElevatedButton.icon(
          onPressed: null, // Disabled
          icon: const Icon(Icons.error_outline, size: 20),
          label: const Text('Unable to load'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceLG,
              vertical: DesignTokens.spaceMD,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            ),
          ),
        );
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
              child: Text(
                'Remove',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldRemove == true) {
      context.read<FriendsBloc>().add(RemoveFriend(user.id));
    }
  }

  /// Stats card with friends count
  Widget _buildStatsCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
      padding: const EdgeInsets.all(DesignTokens.spaceLG),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            icon: Icons.people_outline,
            label: 'Friends',
            value: user.friends.length.toString(),
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).dividerColor,
          ),
          _buildStatItem(
            context,
            icon: Icons.cake_outlined,
            label: 'Age',
            value: user.age > 0 ? user.age.toString() : 'N/A',
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).dividerColor,
          ),
          _buildStatItem(
            context,
            icon: user.gender.toLowerCase() == 'male'
                ? Icons.man_outlined
                : user.gender.toLowerCase() == 'female'
                    ? Icons.woman_outlined
                    : Icons.person_outline,
            label: 'Gender',
            value: user.gender.isNotEmpty ? user.gender : 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 28,
          color: SonarPulseTheme.primaryAccent,
        ),
        const SizedBox(height: DesignTokens.spaceXS),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: DesignTokens.spaceXS),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
        ),
      ],
    );
  }

  /// Bio card
  Widget _buildBioCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
      padding: const EdgeInsets.all(DesignTokens.spaceLG),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 20,
                color: SonarPulseTheme.primaryAccent,
              ),
              const SizedBox(width: DesignTokens.spaceSM),
              Text(
                'About',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          Text(
            user.bio,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// Mutual friends and interests card
  Widget _buildMutualConnectionsCard(
      BuildContext context, UserModel currentUser) {
    final mutualFriendsCount = MutualFriendsHelper.getMutualFriendsCount(
        currentUser.friends, user.friends);
    final mutualInterests = MutualFriendsHelper.getMutualInterests(
        currentUser.interests, user.interests);

    if (mutualFriendsCount == 0 && mutualInterests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
      padding: const EdgeInsets.all(DesignTokens.spaceLG),
      decoration: BoxDecoration(
        color: SonarPulseTheme.primaryAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        border: Border.all(
          color: SonarPulseTheme.primaryAccent.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.favorite,
                size: 20,
                color: SonarPulseTheme.primaryAccent,
              ),
              const SizedBox(width: DesignTokens.spaceSM),
              Text(
                'You Have in Common',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: SonarPulseTheme.primaryAccent,
                    ),
              ),
            ],
          ),

          const SizedBox(height: DesignTokens.spaceMD),

          // Mutual friends
          if (mutualFriendsCount > 0) ...[
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                Text(
                  MutualFriendsHelper.formatMutualFriendsText(
                      mutualFriendsCount),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ],

          // Mutual interests
          if (mutualInterests.isNotEmpty) ...[
            if (mutualFriendsCount > 0)
              const SizedBox(height: DesignTokens.spaceMD),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.interests,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        MutualFriendsHelper.formatMutualInterestsText(
                            mutualInterests),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: DesignTokens.spaceSM),
                      Wrap(
                        spacing: DesignTokens.spaceSM,
                        runSpacing: DesignTokens.spaceSM,
                        children: mutualInterests.take(5).map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceMD,
                              vertical: DesignTokens.spaceXS,
                            ),
                            decoration: BoxDecoration(
                              color: SonarPulseTheme.primaryAccent
                                  .withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusSM),
                            ),
                            child: Text(
                              interest,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: SonarPulseTheme.primaryAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (mutualInterests.length > 5) ...[
                        const SizedBox(height: DesignTokens.spaceXS),
                        Text(
                          '+${mutualInterests.length - 5} more',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Interests card
  Widget _buildInterestsCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
      padding: const EdgeInsets.all(DesignTokens.spaceLG),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.favorite_outline,
                size: 20,
                color: SonarPulseTheme.primaryAccent,
              ),
              const SizedBox(width: DesignTokens.spaceSM),
              Text(
                'Interests',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          Wrap(
            spacing: DesignTokens.spaceSM,
            runSpacing: DesignTokens.spaceSM,
            children: user.interests.map((interest) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMD,
                  vertical: DesignTokens.spaceSM,
                ),
                decoration: BoxDecoration(
                  color: SonarPulseTheme.primaryAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                  border: Border.all(
                    color: SonarPulseTheme.primaryAccent.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  interest,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SonarPulseTheme.primaryAccent,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Delegate for SliverPersistentHeader to show TabBar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
