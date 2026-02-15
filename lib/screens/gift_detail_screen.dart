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
import 'package:freegram/widgets/common/like_button.dart';
import 'package:freegram/widgets/gifting/gift_visual.dart';

/// Gift detail page
class GiftDetailScreen extends StatefulWidget {
  final GiftModel gift;

  const GiftDetailScreen({
    super.key,
    required this.gift,
  });

  @override
  State<GiftDetailScreen> createState() => _GiftDetailScreenState();
}

class _GiftDetailScreenState extends State<GiftDetailScreen> {
  final _giftRepo = locator<GiftRepository>();
  final _userRepo = locator<UserRepository>();

  int _userCoins = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserCoins();
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
    final rarityColor = RarityHelper.getColor(widget.gift.rarity);
    final canAfford = _userCoins >= widget.gift.priceInCoins;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with gift preview
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [rarityColor.withValues(alpha: 0.3), rarityColor],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: GiftVisual(
                    gift: widget.gift,
                    size: 150,
                    showRarityBackground:
                        false, // Background handled by container
                    animate: true,
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gift info
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and rarity
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.gift.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          StreamBuilder<List<String>>(
                            stream: FirebaseAuth.instance.currentUser != null
                                ? _giftRepo.getLikedGiftIds(
                                    FirebaseAuth.instance.currentUser!.uid)
                                : const Stream.empty(),
                            builder: (context, snapshot) {
                              final likedIds = snapshot.data ?? [];
                              final isLiked = likedIds.contains(widget.gift.id);

                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: LikeButton(
                                  isLiked: isLiked,
                                  size: 28,
                                  onLike: () async {
                                    final user =
                                        FirebaseAuth.instance.currentUser;
                                    if (user != null) {
                                      await _giftRepo.toggleLike(
                                          user.uid, widget.gift.id);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: rarityColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              widget.gift.rarity.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Description
                      Text(
                        widget.gift.description,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Price
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.monetization_on,
                                    color: Colors.amber.shade700, size: 32),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Price',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      '${widget.gift.priceInCoins} coins',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (!canAfford)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Not enough coins',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Stats
                      _buildStatsRow(),
                    ],
                  ),
                ),

                // Similar gifts
                _buildSimilarGifts(),

                const SizedBox(height: 100), // Space for buttons
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildActionButtons(canAfford),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Category',
            widget.gift.category.displayName,
            Icons.category,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Sold',
            '${widget.gift.soldCount}',
            Icons.shopping_bag,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey.shade600),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarGifts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Similar Gifts',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<GiftModel>>(
          stream: _giftRepo.getAvailableGifts(category: widget.gift.category),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: AppProgressIndicator(),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final gifts = snapshot.data!
                .where((g) => g.id != widget.gift.id)
                .take(5)
                .toList();

            return SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: gifts.length,
                itemBuilder: (context, index) {
                  return _buildSimilarGiftCard(gifts[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSimilarGiftCard(GiftModel gift) {
    final rarityColor = RarityHelper.getColor(gift.rarity);

    return GestureDetector(
      onTap: () {
        HapticHelper.light();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GiftDetailScreen(gift: gift),
          ),
        );
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        child: Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: rarityColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Icon(
                    Icons.card_giftcard,
                    size: 40,
                    color: rarityColor,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gift.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${gift.priceInCoins} coins',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildActionButtons(bool canAfford) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canAfford && !_isLoading
                    ? () {
                        HapticHelper.medium();
                        _purchaseForSelf();
                      }
                    : null,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shopping_cart),
                label: const Text('Buy for Self'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canAfford && !_isLoading
                    ? () {
                        HapticHelper.medium();
                        Navigator.pushNamed(
                          context,
                          '/gift-send-friend-picker',
                          arguments: widget.gift,
                        );
                      }
                    : null,
                icon: const Icon(Icons.send),
                label: const Text('Send as Gift'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchaseForSelf() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _giftRepo.purchaseGift(
          currentUser.uid,
          widget.gift.id,
        );

        if (mounted) {
          HapticHelper.success();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gift purchased! Check your inventory 🎁'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
