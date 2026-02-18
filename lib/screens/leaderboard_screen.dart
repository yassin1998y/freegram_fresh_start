import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/leaderboard_repository.dart';
import 'package:freegram/repositories/auth_repository.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/screens/profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _leaderboardRepo = locator<LeaderboardRepository>();
  final _authRepo = locator<AuthRepository>();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadCurrentUser();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = _authRepo.currentUser;
    if (mounted && user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboards'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Social Points'),
            Tab(text: 'Top Senders'),
            Tab(text: 'Top Receivers'),
            Tab(text: 'Collectors'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboardTab(
            fetchMethod: () => _leaderboardRepo.getTopUsersBySocialPoints(),
            statSelector: (u) => u.socialPoints,
            statLabel: 'Social Points',
          ),
          _buildLeaderboardTab(
            fetchMethod: () => _leaderboardRepo.getTopSenders(),
            statSelector: (u) => u.totalGiftsSent,
            statLabel: 'Gifts Sent',
          ),
          _buildLeaderboardTab(
            fetchMethod: () => _leaderboardRepo.getTopReceivers(),
            statSelector: (u) => u.totalGiftsReceived,
            statLabel: 'Gifts Received',
          ),
          _buildLeaderboardTab(
            fetchMethod: () => _leaderboardRepo.getTopCollectors(),
            statSelector: (u) => u.uniqueGiftsCollected,
            statLabel: 'Unique Gifts',
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab({
    required Future<List<UserModel>> Function() fetchMethod,
    required int Function(UserModel) statSelector,
    required String statLabel,
  }) {
    return FutureBuilder<List<UserModel>>(
      future: fetchMethod(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Center(child: Text('No data available'));
        }

        // Find current user rank
        int? currentUserRank;
        UserModel? currentUserData;

        if (_currentUserId != null) {
          final index = users.indexWhere((u) => u.id == _currentUserId);
          if (index != -1) {
            currentUserRank = index + 1;
            currentUserData = users[index];
          }
        }

        return Stack(
          children: [
            ListView.builder(
              padding:
                  const EdgeInsets.only(bottom: 100), // Space for sticky bar
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final rank = index + 1;
                return _buildUserListItem(
                    context, user, rank, statSelector, statLabel);
              },
            ),
            if (currentUserData != null && currentUserRank != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _buildStickyUserBar(
                    currentUserData, currentUserRank, statSelector, statLabel),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUserListItem(
    BuildContext context,
    UserModel user,
    int rank,
    int Function(UserModel) statSelector,
    String statLabel,
  ) {
    Color borderColor =
        const Color(0xFF00BFA5).withValues(alpha: 0.3); // Brand Green default
    double borderWidth = 1.0;

    if (rank == 1) {
      borderColor = const Color(0xFFFFD700); // Gold
      borderWidth = 3.0;
    } else if (rank == 2) {
      borderColor = const Color(0xFFC0C0C0); // Silver
      borderWidth = 2.5;
    } else if (rank == 3) {
      borderColor = const Color(0xFFCD7F32); // Bronze
      borderWidth = 2.0;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: Containers.glassCard(context).copyWith(
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ListTile(
        onTap: () {
          if (rank <= 3) HapticFeedback.mediumImpact();
          locator<NavigationService>().navigateTo(
            ProfileScreen(userId: user.id),
            transition: PageTransition.slide,
          );
        },
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: rank <= 3
                      ? borderColor
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2),
              ),
              child: CircleAvatar(
                backgroundImage: user.photoUrl.isNotEmpty
                    ? CachedNetworkImageProvider(user.photoUrl)
                    : null,
                child: user.photoUrl.isEmpty
                    ? Text(user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : '?')
                    : null,
              ),
            ),
          ],
        ),
        title: Text(
          user.username,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Level ${user.userLevel}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${statSelector(user)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Text(
              statLabel,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyUserBar(
    UserModel user,
    int rank,
    int Function(UserModel) statSelector,
    String statLabel,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        locator<NavigationService>().navigateTo(
          ProfileScreen(userId: user.id),
          transition: PageTransition.slide,
        );
      },
      borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
      child: Container(
        decoration: Containers.glassCard(context).copyWith(
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.8),
          border: Border.all(
              color: Theme.of(context).colorScheme.primary, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(
              '#$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 18,
              backgroundImage: user.photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(user.photoUrl)
                  : null,
              child: user.photoUrl.isEmpty
                  ? Text(user.username.isNotEmpty
                      ? user.username[0].toUpperCase()
                      : '?')
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your Rank',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  // Could add "Next rank in X points" here if we had the next user's data handy
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${statSelector(user)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  statLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
