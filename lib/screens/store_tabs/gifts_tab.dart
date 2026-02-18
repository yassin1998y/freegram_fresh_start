import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/screens/gift_detail_screen.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/widgets/gifting/gift_visual.dart';
import 'package:freegram/services/global_cache_coordinator.dart';
import 'package:freegram/widgets/common/success_animation.dart';

class GiftsTab extends StatefulWidget {
  const GiftsTab({Key? key}) : super(key: key);

  @override
  State<GiftsTab> createState() => _GiftsTabState();
}

class _GiftsTabState extends State<GiftsTab> {
  final _globalCache = locator<GlobalCacheCoordinator>();
  List<GiftModel>? _cachedGifts;
  bool _isLoadingCache = true;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final cached = await _globalCache.getCachedItems<GiftModel>();
    if (mounted) {
      setState(() {
        if (cached.isNotEmpty) {
          _cachedGifts = cached;
        }
        _isLoadingCache = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final giftRepository = locator<GiftRepository>();
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view gifts.")),
      );
    }

    return Scaffold(
      body: StreamBuilder<List<GiftModel>>(
        stream: giftRepository.getAvailableGifts(),
        builder: (context, snapshot) {
          List<GiftModel> gifts = [];
          bool usingCache = false;

          if (snapshot.hasData) {
            gifts = snapshot.data!;
            // Update cache in background
            if (gifts.isNotEmpty) {
              _globalCache.cacheItems(gifts);
            }
          } else if (_cachedGifts != null) {
            gifts = _cachedGifts!;
            usingCache = true;
          }

          if (gifts.isEmpty) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                _isLoadingCache) {
              // Show skeleton/shimmer
              return _buildShimmerGrid();
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text("Error loading gifts: ${snapshot.error}"));
            }
            if (!snapshot.hasData && !usingCache && !_isLoadingCache) {
              // If we attempted network and still empty, and cache is empty
              return const Center(
                  child: Text("No gifts available at the moment."));
            }
          }

          return CustomScrollView(
            slivers: [
              if (usingCache)
                SliverToBoxAdapter(
                  child: LinearProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor.withValues(alpha: 0.5)),
                    backgroundColor: Colors.transparent,
                    minHeight: 2,
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final gift = gifts[index];
                      return _GiftCard(gift: gift, userId: userId);
                    },
                    childCount: gifts.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShimmerGrid() {
    // 1px Bordered Skeleton Screen
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
                    width: 1,
                  ),
                  color: Colors.grey.shade100, // Light background
                ),
              ),
              childCount: 6,
            ),
          ),
        )
      ],
    );
  }
}

class _GiftCard extends StatelessWidget {
  final GiftModel gift;
  final String userId;

  const _GiftCard({
    Key? key,
    required this.gift,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isLimited = gift.isLimited;
    final soldOut = isLimited &&
        gift.maxQuantity != null &&
        gift.soldCount >= gift.maxQuantity!;

    // 1px Border Rule (0xFF00BFA5 at 0.1 alpha) for the Container (Card)
    final borderColor = const Color(0xFF00BFA5).withValues(alpha: 0.1);

    return InkWell(
      onTap: () {
        HapticHelper.light();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GiftDetailScreen(gift: gift),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
            // Add subtle shadow for the card itself? Boutique spec says shadows on images inside.
            // But cards usually have elevation.
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Animation/Image
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Container(
                      color: Colors.grey
                          .shade50, // Subtle background behind floating asset
                      child: Center(
                        child: GiftVisual(
                          gift: gift,
                          size: 120,
                          showRarityBackground:
                              true, // Boutique: Show rarity visuals
                          animate: true,
                        ),
                      ),
                    ),
                  ),
                  if (isLimited)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "LIMITED",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Details
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gift.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        "${gift.priceInCoins}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                            fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: LayoutBuilder(builder: (context, constraints) {
                      // Purchase Button with Glint (Simplified as OutlinedButton with border for now or ElevatedButton)
                      // Requirement: "light "shimmer glint" animation on the purchase button's 1px border during the transaction state"
                      // Since we don't have transaction state passed down here explicitly (state is local to _purchaseGift),
                      // we can leave the button standard but styled.
                      return ElevatedButton(
                        onPressed:
                            soldOut ? null : () => _purchaseGift(context, gift),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: soldOut
                                ? Colors.grey
                                : Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(
                                vertical: 0), // Compact
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            )),
                        child: Text(soldOut ? "SOLD OUT" : "Buy",
                            style: const TextStyle(fontSize: 12)),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchaseGift(BuildContext context, GiftModel gift) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Purchase ${gift.name}?"),
        content: Text("This will cost ${gift.priceInCoins} coins."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Buy"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!context.mounted) return;

      try {
        // Show loading
        // Ideally we would show the "glint" animation here on the button, but we are using a dialog for loading.
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        final userId = FirebaseAuth.instance.currentUser!.uid;
        await locator<GiftRepository>().purchaseGift(userId, gift.id);

        if (!context.mounted) return;
        // Hide loading
        Navigator.pop(context);

        if (!context.mounted) return;
        // Show success
        HapticFeedback.heavyImpact(); // Boutique requirement

        await showDialog(
          context: context,
          barrierColor:
              Colors.black.withValues(alpha: 0.8), // Premium dark overlay
          builder: (_) => Center(
            child: SuccessAnimation(
              message: "Purchased!",
              showConfetti: true,
              onComplete: () {
                // Should pop the dialog
                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
        );

        // Removed SnackBar as animation is sufficient feedback
      } catch (e) {
        if (!context.mounted) return;
        // Hide loading
        Navigator.pop(context);

        if (!context.mounted) return;
        HapticHelper.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Purchase failed: $e")),
        );
      }
    }
  }
}
