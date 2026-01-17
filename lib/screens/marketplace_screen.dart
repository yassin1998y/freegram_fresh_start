import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:freegram/utils/rarity_helper.dart';
import 'package:freegram/utils/gift_extensions.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/screens/leaderboard_screen.dart';

/// Marketplace home screen for browsing gifts
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _giftRepo = locator<GiftRepository>();
  final _userRepo = locator<UserRepository>();
  final _searchController = TextEditingController();

  int _userCoins = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUserCoins();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserCoins() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final user = await _userRepo.getUser(currentUser.uid);
      if (mounted) {
        setState(() => _userCoins = user.coins);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gift Marketplace'),
        centerTitle: true,
        actions: [
          // Leaderboard button
          IconButton(
            icon: const Icon(Icons.leaderboard, color: Colors.purple),
            onPressed: () {
              HapticHelper.medium();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LeaderboardScreen(),
                ),
              );
            },
          ),
          // Coin balance
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.amber.shade700),
                const SizedBox(width: 4),
                Text(
                  '$_userCoins',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUserCoins();
          setState(() {});
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              _buildSearchBar(),

              // Hero banner
              _buildHeroBanner(),

              // Category grid
              _buildCategoryGrid(),

              // Trending section
              _buildTrendingSection(),

              // New arrivals section
              _buildNewArrivalsSection(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search gifts...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.5),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
          if (value.isNotEmpty) {
            _navigateToSearch(value);
          }
        },
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                Icons.card_giftcard,
                size: 150,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Send Perfect Gifts',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse our collection of amazing gifts',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      HapticHelper.medium();
                      Navigator.pushNamed(context, '/gift-send-friend-picker');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Send a Gift'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Browse by Category',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: GiftCategory.values.map((category) {
              return _buildCategoryCard(category);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(GiftCategory category) {
    final icon = _getCategoryIcon(category);
    final color = _getCategoryColor(category);

    return GestureDetector(
      onTap: () {
        HapticHelper.light();
        Navigator.pushNamed(
          context,
          '/category-browse',
          arguments: category,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 4),
            Text(
              category.displayName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Trending Gifts',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to full trending list
                  },
                  child: const Text('See All'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<GiftModel>>(
            future: _giftRepo.getTrendingGifts(limit: 10),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: AppProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final gifts = snapshot.data!;
              if (gifts.isEmpty) return const SizedBox.shrink();

              return SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: gifts.length,
                  itemBuilder: (context, index) {
                    return _buildHorizontalGiftCard(gifts[index]);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNewArrivalsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.new_releases, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'New Arrivals',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to full new arrivals list
                  },
                  child: const Text('See All'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<GiftModel>>(
            future: _giftRepo.getNewArrivals(limit: 10),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: AppProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final gifts = snapshot.data!;
              if (gifts.isEmpty) return const SizedBox.shrink();

              return SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: gifts.length,
                  itemBuilder: (context, index) {
                    return _buildHorizontalGiftCard(gifts[index]);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalGiftCard(GiftModel gift) {
    final rarityColor = RarityHelper.getColor(gift.rarity);
    final canAfford = _userCoins >= gift.priceInCoins;

    return GestureDetector(
      onTap: () {
        HapticHelper.light();
        Navigator.pushNamed(
          context,
          '/gift-detail',
          arguments: gift,
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gift icon
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: rarityColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.card_giftcard,
                          size: 48,
                          color: rarityColor,
                        ),
                      ),
                      // Rarity badge
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: rarityColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            gift.rarity.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Gift info
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gift.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.monetization_on,
                          size: 12,
                          color:
                              canAfford ? Colors.amber.shade700 : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${gift.priceInCoins}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                canAfford ? Colors.amber.shade700 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(GiftCategory category) {
    switch (category) {
      case GiftCategory.love:
        return Icons.favorite;
      case GiftCategory.celebration:
        return Icons.celebration;
      case GiftCategory.funny:
        return Icons.emoji_emotions;
      case GiftCategory.seasonal:
        return Icons.ac_unit;
      case GiftCategory.special:
        return Icons.star;
    }
  }

  Color _getCategoryColor(GiftCategory category) {
    switch (category) {
      case GiftCategory.love:
        return Colors.pink;
      case GiftCategory.celebration:
        return Colors.orange;
      case GiftCategory.funny:
        return Colors.teal;
      case GiftCategory.seasonal:
        return Colors.blue;
      case GiftCategory.special:
        return Colors.purple;
    }
  }

  void _navigateToSearch(String query) {
    // TODO: Navigate to search results screen
  }
}
