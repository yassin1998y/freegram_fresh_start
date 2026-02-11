import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:freegram/widgets/freegram_app_bar.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/screens/store_tabs/coins_tab.dart';
import 'package:freegram/screens/store_tabs/boosts_tab.dart';
import 'package:freegram/screens/store_tabs/gifts_tab.dart';
import 'package:freegram/screens/store_tabs/profile_tab.dart';
import 'package:freegram/screens/store_tabs/marketplace_tab.dart';
import 'package:freegram/screens/limited_editions_screen.dart';

import 'package:freegram/locator.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/repositories/profile_repository.dart';

import 'package:freegram/services/daily_reward_service.dart';
import 'package:freegram/widgets/gamification/daily_reward_dialog.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/achievements_screen.dart';
import 'package:freegram/screens/referral_screen.dart';
import 'package:freegram/screens/inventory_screen.dart';
import 'package:freegram/models/user_model.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger seeding of catalogs
    _seedCatalogs();
    // Check for daily reward
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDailyReward());
  }

  Future<void> _seedCatalogs() async {
    await locator<GiftRepository>().seedGifts();
    await locator<ProfileRepository>().seedProfileItems();
  }

  Future<void> _checkDailyReward() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final service = locator<DailyRewardService>();
      final status = await service.checkRewardStatus(currentUser.uid);

      if (status == DailyRewardStatus.available && mounted) {
        _showDailyRewardDialog(currentUser.uid);
      }
    } catch (e) {
      // Silently fail - don't interrupt user experience
      debugPrint('Error checking daily reward: $e');
    }
  }

  void _showDailyRewardDialog(String userId) async {
    // Fetch current streak first
    final user = await locator<UserRepository>().getUser(userId);
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => DailyRewardDialog(
          userId: userId,
          currentStreak: user.dailyLoginStreak,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 SCREEN: store_screen.dart');
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to access the store.")),
      );
    }

    return Scaffold(
      appBar: FreegramAppBar(
        title: 'Store',
        showBackButton: true,
        actions: [
          // Coin balance display
          StreamBuilder<UserModel>(
            stream: locator<UserRepository>().getUserStream(currentUser.uid),
            builder: (context, snapshot) {
              // Handle error state
              if (snapshot.hasError) {
                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: const Icon(Icons.error, color: Colors.red),
                );
              }

              // Show loading or current balance
              final coins = snapshot.data?.coins ?? 0;
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: Containers.iconBox(Colors.amber),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on,
                        color: Colors.amber, size: 20),
                    const SizedBox(width: 6),
                    isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.amber),
                            ),
                          )
                        : Text(
                            coins.toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                  ],
                ),
              );
            },
          ),
          // Daily reward button
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.amber),
            onPressed: () => _showDailyRewardDialog(currentUser.uid),
            tooltip: "Daily Reward",
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance & Stats Card
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<UserModel>(
                stream:
                    locator<UserRepository>().getUserStream(currentUser.uid),
                builder: (context, snapshot) {
                  final coins = snapshot.data?.coins ?? 0;
                  final level = snapshot.data?.userLevel ?? 1;
                  final streak = snapshot.data?.dailyLoginStreak ?? 0;

                  return Row(
                    children: [
                      // Coin Balance
                      Expanded(
                        child: _BalanceItem(
                          icon: Icons.monetization_on,
                          label: "Coins",
                          value: coins.toString(),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Theme.of(context).dividerColor,
                      ),
                      // Level
                      Expanded(
                        child: _BalanceItem(
                          icon: Icons.star,
                          label: "Level",
                          value: level.toString(),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Theme.of(context).dividerColor,
                      ),
                      // Streak
                      Expanded(
                        child: _BalanceItem(
                          icon: Icons.local_fire_department,
                          label: "Streak",
                          value: "${streak}d",
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Store Grid
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: [
                _CompactStoreCard(
                  title: "Get Coins",
                  icon: Icons.monetization_on,
                  iconColor: Colors.amber,
                  onTap: () => _navigateTo(
                      context, "Get Coins", CoinsTab(userId: currentUser.uid)),
                ),
                _CompactStoreCard(
                  title: "Boosts",
                  icon: Icons.rocket_launch,
                  iconColor: Colors.orange,
                  onTap: () => _navigateTo(
                      context, "Boosts", BoostsTab(userId: currentUser.uid)),
                ),
                _CompactStoreCard(
                  title: "Collectibles",
                  icon: Icons.card_giftcard,
                  iconColor: Colors.pink,
                  onTap: () =>
                      _navigateTo(context, "Collectibles", const GiftsTab()),
                ),
                _CompactStoreCard(
                  title: "Skins",
                  icon: Icons.palette,
                  iconColor: Colors.purple,
                  onTap: () =>
                      _navigateTo(context, "Skins", const ProfileTab()),
                ),
                _CompactStoreCard(
                  title: "Trade Market",
                  icon: Icons.storefront,
                  iconColor: Colors.green,
                  onTap: () => _navigateTo(
                      context, "Trade Market", const MarketplaceTab()),
                ),
                _CompactStoreCard(
                  title: "Limited",
                  icon: Icons.timer,
                  iconColor: Colors.deepOrange,
                  badge: "HOT",
                  onTap: () => _navigateTo(context, "Limited Editions",
                      const LimitedEditionsScreen()),
                ),
                _CompactStoreCard(
                  title: "Achievements",
                  icon: Icons.emoji_events,
                  iconColor: Colors.amber.shade700,
                  onTap: () => _navigateTo(
                      context, "Achievements", const AchievementsScreen()),
                ),
                _CompactStoreCard(
                  title: "Referrals",
                  icon: Icons.people,
                  iconColor: Colors.blue,
                  onTap: () =>
                      _navigateTo(context, "Referrals", const ReferralScreen()),
                ),
                _CompactStoreCard(
                  title: "My Items",
                  icon: Icons.inventory_2,
                  iconColor: Colors.indigo,
                  onTap: () => _navigateTo(
                      context, "My Inventory", const InventoryScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, String title, Widget content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: FreegramAppBar(
            title: title,
            showBackButton: true,
          ),
          body: content,
        ),
      ),
    );
  }
}

// Balance Item Widget
class _BalanceItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _BalanceItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withOpacity( 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// Compact Store Card Widget
class _CompactStoreCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String? badge;
  final VoidCallback onTap;

  const _CompactStoreCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 28, color: iconColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
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
