import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/screens/gift_detail_screen.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/widgets/gifting/gift_visual.dart';

class GiftsTab extends StatelessWidget {
  const GiftsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final giftRepository = locator<GiftRepository>();
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Center(child: Text("Please log in to view gifts."));
    }

    return StreamBuilder<List<GiftModel>>(
      stream: giftRepository.getAvailableGifts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error loading gifts: ${snapshot.error}"));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final gifts = snapshot.data!;

        if (gifts.isEmpty) {
          return const Center(child: Text("No gifts available at the moment."));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: gifts.length,
          itemBuilder: (context, index) {
            final gift = gifts[index];
            return _GiftCard(gift: gift, userId: userId);
          },
        );
      },
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
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      color: Colors.grey.shade100,
                      child: Center(
                        child: GiftVisual(
                          gift: gift,
                          size: 120,
                          showRarityBackground: false,
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
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gift.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on,
                          size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        "${gift.priceInCoins}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          soldOut ? null : () => _purchaseGift(context, gift),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: soldOut
                            ? Colors.grey
                            : Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(soldOut ? "SOLD OUT" : "Buy"),
                    ),
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
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        await locator<GiftRepository>().purchaseGift(userId, gift.id);

        if (!context.mounted) return;
        // Hide loading
        Navigator.pop(context);

        if (!context.mounted) return;
        // Show success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Successfully purchased ${gift.name}!")),
        );
      } catch (e) {
        if (!context.mounted) return;
        // Hide loading
        Navigator.pop(context);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Purchase failed: $e")),
        );
      }
    }
  }
}
