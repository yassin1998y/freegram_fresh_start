import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/skeletons/profile_skeleton.dart';
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
// Duplicate import removed
import 'package:freegram/widgets/core/user_avatar.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/widgets/feed_widgets/post_card.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/widgets/reels/user_reels_tab.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/screens/analytics_dashboard_screen.dart';
import 'package:freegram/screens/achievements_screen.dart';
import 'package:freegram/models/user_inventory_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/widgets/gifting/owned_gift_visual.dart';
import 'package:freegram/widgets/achievements/achievement_progress_bar.dart';
import 'package:freegram/widgets/gifting/gift_picker_sheet.dart';
import 'package:freegram/widgets/island_popup.dart';
import 'package:freegram/repositories/leaderboard_repository.dart';

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
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: DesignTokens.opacityMedium,
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
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
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
      if (context.mounted) {
        context.read<FriendsBloc>().add(BlockUser(user.id));
      }

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
              body: const ProfileSkeleton(),
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

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 320.0,
                  pinned: true,
                  stretch: true,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leading: const BackButton(),
                  flexibleSpace: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      final top = constraints.biggest.height;
                      final isCollapsed = top <=
                          MediaQuery.of(context).padding.top +
                              kToolbarHeight +
                              20;
                      final expandRatio =
                          (top - kToolbarHeight) / (320.0 - kToolbarHeight);

                      return FlexibleSpaceBar(
                        collapseMode: CollapseMode.pin,
                        centerTitle: true,
                        title: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: isCollapsed ? 1.0 : 0.0,
                          child: Text(
                            user.username,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                        ),
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Subtle Gradient Background
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    SonarPulseTheme.primaryAccent
                                        .withValues(alpha: 0.15),
                                    Theme.of(context).scaffoldBackgroundColor,
                                  ],
                                  stops: const [0.0, 0.8],
                                ),
                              ),
                            ),

                            // 2. Avatar & Info (Parallax Scaling)
                            Align(
                              alignment: Alignment.center,
                              child: Opacity(
                                opacity: (expandRatio).clamp(0.0, 1.0),
                                child: Transform.scale(
                                  scale:
                                      0.8 + (0.2 * expandRatio), // Subtle zoom
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                          height: 40), // Space for AppBar
                                      // Avatar with Pulse/Level Ring
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: SonarPulseTheme.primaryAccent
                                                .withValues(alpha: 0.3),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: SonarPulseTheme
                                                  .primaryAccent
                                                  .withValues(alpha: 0.2),
                                              blurRadius: 20,
                                              spreadRadius: 2,
                                            )
                                          ],
                                        ),
                                        child: UserAvatarLarge(
                                          url: user.photoUrl,
                                          badgeUrl: user.equippedBadgeUrl,
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // Name & Flag
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            user.username,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.5,
                                                ),
                                          ),
                                          const SizedBox(width: 8),
                                          _RankBadge(user: user),
                                        ],
                                      ),

                                      const SizedBox(height: 8),
                                      AchievementProgressBar(
                                        progress: user.nextLevelExperience > 0
                                            ? user.experience /
                                                user.nextLevelExperience
                                            : 0.0,
                                      ),

                                      if (user.country.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          user.country,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  actions: [
                    if (!isCurrentUserProfile)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context)
                                .scaffoldBackgroundColor
                                .withValues(alpha: 0.5),
                            border: Border.all(
                                color: SonarPulseTheme.primaryAccent
                                    .withValues(alpha: 0.3),
                                width: 1),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.more_vert_rounded),
                            color: Theme.of(context).colorScheme.onSurface,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _showProfileOptions(context, user);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: _ProfileContent(
                    user: user,
                    isCurrentUserProfile: isCurrentUserProfile,
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      tabs: const [
                        Tab(text: 'Posts'),
                        Tab(text: 'Reels'),
                      ],
                      indicatorColor: SonarPulseTheme.primaryAccent,
                      indicatorWeight: 3,
                      labelColor: SonarPulseTheme.primaryAccent,
                      unselectedLabelColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      dividerColor: Colors.transparent,
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _UserPostsSection(userId: widget.userId),
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

class _ProfileContent extends StatelessWidget {
  final UserModel user;
  final bool isCurrentUserProfile;

  const _ProfileContent({
    required this.user,
    required this.isCurrentUserProfile,
  });

  Future<void> _startChat(BuildContext context) async {
    final chatId = await locator<ChatRepository>().startOrGetChat(
      user.id,
      user.username,
    );
    if (context.mounted) {
      locator<NavigationService>().navigateTo(
        ImprovedChatScreen(
          chatId: chatId,
          otherUsername: user.username,
        ),
        transition: PageTransition.slide,
      );
    }
  }

  Future<void> _confirmRemoveFriend(BuildContext context) async {
    final bool? shouldRemove = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Remove Friend?'),
          content: Text(
              'Are you sure you want to remove ${user.username} as a friend?',
              style: Theme.of(context).textTheme.bodyMedium),
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
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldRemove == true && context.mounted) {
      context.read<FriendsBloc>().add(RemoveFriend(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: DesignTokens.spaceMD),

        // Action Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
          child: isCurrentUserProfile
              ? _buildCurrentUserActions(context)
              : _buildOtherUserActions(context),
        ),

        const SizedBox(height: DesignTokens.spaceXL),

        // Stats Row (Flat, Tactile Design)
        _buildStatsRow(context),

        const SizedBox(height: DesignTokens.spaceXL),

        // Bio Section
        if (user.bio.isNotEmpty) ...[
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
            child: Text(
              user.bio,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                    height: 1.5,
                  ),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLG),
        ],

        // 3D Gift Showcase Carousel
        _build3DGiftShowcase(context),

        const SizedBox(height: DesignTokens.spaceLG),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(context, 'Post', '120'),
            _buildVerticalDivider(context),
            _buildStatItem(
                context, 'Followers', user.followersCount.toString()),
            _buildVerticalDivider(context),
            _buildStatItem(
                context, 'Following', user.followingCount.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider(BuildContext context) {
    return Container(
      height: 24,
      width: 1,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentUserActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCircularAction(context, Icons.edit_outlined, () {
          HapticFeedback.lightImpact();
          locator<NavigationService>().navigateTo(
            EditProfileScreen(currentUserData: user.toMap()),
            transition: PageTransition.slide,
          );
        }),
        const SizedBox(width: 24),
        _buildCircularAction(context, Icons.analytics_outlined, () {
          HapticFeedback.lightImpact();
          locator<NavigationService>().navigateTo(
            const AnalyticsDashboardScreen(),
            transition: PageTransition.slide,
          );
        }),
        const SizedBox(width: 24),
        _buildCircularAction(context, Icons.emoji_events_outlined, () {
          HapticFeedback.lightImpact();
          locator<NavigationService>().navigateTo(
            const AchievementsScreen(),
            transition: PageTransition.slide,
          );
        }),
      ],
    );
  }

  Widget _buildCircularAction(
      BuildContext context, IconData icon, VoidCallback onTap,
      {Color? backgroundColor, Color? borderColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
          border: Border.all(
            color: borderColor ??
                SonarPulseTheme.primaryAccent.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Icon(icon, color: SonarPulseTheme.primaryAccent, size: 22),
      ),
    );
  }

  Widget _buildOtherUserActions(BuildContext context) {
    return BlocConsumer<FriendsBloc, FriendsState>(
      listener: (context, state) {
        if (state is FriendsActionSuccess) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        if (state is FriendsLoaded) {
          final currentUser = state.user;
          bool isFriend = currentUser.friends.contains(user.id);
          bool requestSent = currentUser.friendRequestsSent.contains(user.id);
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            );
          }

          if (isFriend) {
            return Row(children: [
              Expanded(
                child: _buildPrimaryButton(
                    context, "Message", Icons.chat_bubble_outline, () {
                  _startChat(context);
                }),
              ),
              const SizedBox(width: 8),
              // Gift Button (Standardized Flow)
              _buildCircularAction(
                context,
                Icons.card_giftcard_rounded,
                () => _onSendGiftPressed(context, user),
                borderColor: SonarPulseTheme.primaryAccent,
                backgroundColor:
                    SonarPulseTheme.primaryAccent.withValues(alpha: 0.1),
              ),
              const SizedBox(width: 8),
              _buildCircularAction(context, Icons.person_remove_outlined, () {
                _confirmRemoveFriend(context);
              }),
            ]);
          }

          if (requestSent) {
            return _buildOutlinedButton(
                context, "Request Sent", Icons.check, null);
          }

          return Row(
            children: [
              Expanded(
                child: _buildPrimaryButton(
                    context, "Connect", Icons.person_add_outlined, () {
                  HapticFeedback.mediumImpact();
                  context.read<FriendsBloc>().add(SendFriendRequest(user.id));
                }),
              ),
              const SizedBox(width: 8),
              // Gift Button for non-friends too
              _buildCircularAction(
                context,
                Icons.card_giftcard_rounded,
                () => _onSendGiftPressed(context, user),
                borderColor: SonarPulseTheme.primaryAccent,
                backgroundColor:
                    SonarPulseTheme.primaryAccent.withValues(alpha: 0.1),
              ),
            ],
          );
        }
        return const Center(child: AppProgressIndicator());
      },
    );
  }

  void _onSendGiftPressed(BuildContext context, UserModel user) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftPickerSheet(
        targetUserId: user.id,
        onGiftSent: (gift) {
          // Trigger the success loop
          // IslandPopup might not be available in context if not installed/imported
          // Using ScaffoldMessenger as fallback if IslandPopup is not found
          // But prompt specifically asked for IslandPopup
          try {
            IslandPopup.show(context,
                message: "Gift delivered to ${user.username}! 🎁");
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Gift delivered to ${user.username}! 🎁")),
            );
          }
        },
      ),
    );
  }

  Widget _buildPrimaryButton(
      BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: SonarPulseTheme.primaryAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(
      BuildContext context, String label, IconData icon, VoidCallback? onTap) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(color: Theme.of(context).dividerColor),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _build3DGiftShowcase(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
          child: Row(
            children: [
              const Icon(Icons.card_giftcard, size: 20, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                "Gift Showcase",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: StreamBuilder<List<OwnedGift>>(
            stream: locator<GiftRepository>().getUserInventory(user.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: AppProgressIndicator(
                  size: DesignTokens.iconMD,
                  strokeWidth: 2,
                ));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyGifts(context);
              }

              final displayedGifts =
                  snapshot.data!.where((g) => g.isDisplayed).toList();
              if (displayedGifts.isEmpty) return _buildEmptyGifts(context);

              return _GiftCarousel3D(gifts: displayedGifts);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyGifts(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: 0.5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 32),
            const SizedBox(height: 8),
            Text("No gifts showcased yet",
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _GiftCarousel3D extends StatefulWidget {
  final List<OwnedGift> gifts;
  const _GiftCarousel3D({required this.gifts});

  @override
  State<_GiftCarousel3D> createState() => _GiftCarousel3DState();
}

class _GiftCarousel3DState extends State<_GiftCarousel3D> {
  late PageController _pageController;
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.6);
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page!;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.gifts.length,
      itemBuilder: (context, index) {
        final double relativePosition = index - _currentPage;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..scaleByDouble(
                1.0 - (relativePosition.abs() * 0.2),
                1.0 - (relativePosition.abs() * 0.2),
                1.0,
                1.0) // Scale down on edges
            ..rotateY(relativePosition * 0.5), // Rotate based on scroll
          alignment: Alignment.center,
          child: _GiftCard(gift: widget.gifts[index]),
        );
      },
    );
  }
}

class _GiftCard extends StatelessWidget {
  final OwnedGift gift;
  const _GiftCard({required this.gift});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: SonarPulseTheme.primaryAccent.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Center(
              child: OwnedGiftVisual(
                ownedGift: gift,
                size: 80,
                animate: true,
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "LVL ${gift.upgradeLevel + 1}",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _RankBadge extends StatelessWidget {
  final UserModel user;
  const _RankBadge({required this.user});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: locator<LeaderboardRepository>()
          .getUserRank(user.id, user.socialPoints),
      builder: (context, snapshot) {
        final rank = snapshot.data ?? 0;
        if (rank <= 0 || rank > 100) return const SizedBox.shrink();

        Color badgeColor = const Color(0xFF00BFA5); // Brand Green
        if (rank == 1) {
          badgeColor = const Color(0xFFFFD700); // Gold
        } else if (rank == 2) {
          badgeColor = const Color(0xFFC0C0C0); // Silver
        } else if (rank == 3) {
          badgeColor = const Color(0xFFCD7F32); // Bronze
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
            border: Border.all(color: badgeColor, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, color: badgeColor, size: 12),
              const SizedBox(width: 4),
              Text(
                'Top $rank',
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
