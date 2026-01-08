import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _giftRepo = locator<GiftRepository>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
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
          tabs: const [
            Tab(text: 'Senders'),
            Tab(text: 'Receivers'),
            Tab(text: 'Collectors'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboardList(
              _giftRepo.getTopSenders, 'totalGiftsSent', 'Gifts Sent'),
          _buildLeaderboardList(_giftRepo.getTopReceivers, 'totalGiftsReceived',
              'Gifts Received'),
          _buildLeaderboardList(_giftRepo.getTopCollectors,
              'uniqueGiftsCollected', 'Unique Gifts'),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(
    Future<List<UserModel>> Function() fetchMethod,
    String statKey,
    String statLabel,
  ) {
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

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final rank = index + 1;

            // Determine stat value dynamically based on key
            // This is a bit hacky, ideally we'd pass a selector function
            int statValue = 0;
            if (statKey == 'totalGiftsSent')
              statValue = user.totalGiftsSent;
            else if (statKey == 'totalGiftsReceived')
              statValue = user.totalGiftsReceived;
            else if (statKey == 'uniqueGiftsCollected')
              statValue = user.uniqueGiftsCollected;

            return ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: rank <= 3 ? Colors.amber.shade700 : Colors.grey,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    backgroundImage: user.photoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl)
                        : null,
                    child: user.photoUrl.isEmpty
                        ? Text(user.username[0].toUpperCase())
                        : null,
                  ),
                ],
              ),
              title: Text(user.username),
              subtitle: Text('Level ${user.userLevel}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$statValue',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    statLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
