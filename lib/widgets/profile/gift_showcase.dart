import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/models/user_inventory_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/utils/rarity_helper.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:freegram/screens/inventory_screen.dart';
import 'package:freegram/widgets/gifting/upgrade_dialog.dart';
import 'package:freegram/widgets/gifting/owned_gift_visual.dart';
import 'package:freegram/widgets/gifting/gift_visual.dart';
import 'package:freegram/screens/gift_detail_screen.dart';

/// Widget to display user's gift showcase on their profile
/// Shows max 3 displayed gifts with option to expand to see all
class GiftShowcase extends StatelessWidget {
  final String userId;
  final bool isOwnProfile;

  const GiftShowcase({
    super.key,
    required this.userId,
    this.isOwnProfile = false,
  });

  @override
  Widget build(BuildContext context) {
    final giftRepo = locator<GiftRepository>();

    return StreamBuilder<List<OwnedGift>>(
      stream: giftRepo.getUserInventory(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        // Filter only displayed gifts
        final displayedGifts =
            snapshot.data!.where((gift) => gift.isDisplayed).toList();

        if (displayedGifts.isEmpty) {
          return isOwnProfile
              ? _buildEmptyState(context)
              : const SizedBox.shrink();
        }

        // Show max 3 gifts
        final visibleGifts = displayedGifts.take(3).toList();
        final hasMore = displayedGifts.length > 3;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.card_giftcard,
                          size: 20, color: Colors.pink),
                      const SizedBox(width: 8),
                      Text(
                        "Gift Collection",
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${displayedGifts.length}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isOwnProfile)
                    TextButton.icon(
                      onPressed: () {
                        HapticHelper.light();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InventoryScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text("Manage"),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ...visibleGifts.map((gift) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _GiftShowcaseCard(
                            ownedGift: gift,
                            onTap: () => _showGiftDetail(context, gift),
                          ),
                        ),
                      )),
                  if (hasMore)
                    Expanded(
                      child: _ViewAllCard(
                        totalCount: displayedGifts.length,
                        onTap: () {
                          HapticHelper.medium();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const InventoryScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.card_giftcard, size: 32, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "No gifts displayed",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  "Display gifts to showcase your collection",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              HapticHelper.medium();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InventoryScreen(),
                ),
              );
            },
            child: const Text("Manage"),
          ),
        ],
      ),
    );
  }

  void _showGiftDetail(BuildContext context, OwnedGift gift) {
    HapticHelper.light();
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  HapticHelper.light();
                  // Fetch gift model
                  final giftRepo = locator<GiftRepository>();
                  final giftModel = await giftRepo.getGiftById(gift.giftId);

                  if (context.mounted && giftModel != null) {
                    Navigator.pop(context); // Close sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GiftDetailScreen(gift: giftModel),
                      ),
                    );
                  }
                },
                child: _buildGiftIcon(gift),
              ),
              const SizedBox(height: 8),
              const Text(
                "Tap to view details",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Gift Details",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              if (gift.receivedFrom != null)
                Text(
                  "From: ${gift.receivedFrom}",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              if (gift.giftMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  "\"${gift.giftMessage}\"",
                  style: const TextStyle(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                "Value: ${gift.currentMarketValue} coins",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (isOwnProfile) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showUpgradeDialog(context, gift),
                    icon: const Icon(Icons.arrow_upward),
                    label: const Text('Upgrade Gift'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiftIcon(OwnedGift gift) {
    // TODO: Use actual gift icon based on ID
    return Stack(
      alignment: Alignment.center,
      children: [
        OwnedGiftVisual(
          ownedGift: gift,
          size: 64,
          showRarityBackground:
              false, // Background handled by container if needed, or let visual handle it
        ),
        if (gift.isUpgraded)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '${gift.upgradeLevel}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showUpgradeDialog(BuildContext context, OwnedGift gift) {
    // Close detail sheet first
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<int>(
        future: locator<GiftRepository>().getUserCoins(gift.ownerId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userCoins = snapshot.data!;

          return UpgradeDialog(
            ownedGift: gift,
            userCoins: userCoins,
            onUpgrade: () async {
              try {
                Navigator.pop(context); // Close dialog

                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Upgrading gift...')),
                );

                await locator<GiftRepository>()
                    .upgradeGift(gift.ownerId, gift.id);

                HapticHelper.success();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Gift upgraded successfully! ⭐'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                HapticHelper.error();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Upgrade failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

/// Individual gift card in showcase
class _GiftShowcaseCard extends StatelessWidget {
  final OwnedGift ownedGift;
  final VoidCallback onTap;

  const _GiftShowcaseCard({
    required this.ownedGift,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GiftModel?>(
      future: locator<GiftRepository>().getGiftById(ownedGift.giftId),
      builder: (context, snapshot) {
        final gift = snapshot.data;
        final rarity = gift?.rarity ?? GiftRarity.common;

        return GestureDetector(
          onTap: () {
            HapticHelper.light();
            onTap();
          },
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: RarityHelper.getGradient(rarity),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: RarityHelper.getColor(rarity),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: gift != null
                      ? GiftVisual(
                          gift: gift,
                          size: 60,
                          showRarityBackground: false,
                          animate: true,
                        )
                      : Icon(
                          Icons.card_giftcard,
                          size: 40,
                          color: Colors.white.withOpacity(0.9),
                        ),
                ),
                if (rarity == GiftRarity.legendary)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '⭐',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      gift?.name ?? 'Gift',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "View All" card shown when there are more than 3 gifts
class _ViewAllCard extends StatelessWidget {
  final int totalCount;
  final VoidCallback onTap;

  const _ViewAllCard({
    required this.totalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_view, size: 32, color: Colors.grey.shade600),
            const SizedBox(height: 4),
            Text(
              "+${totalCount - 3}",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              "View All",
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
