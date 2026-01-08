import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/marketplace_listing_model.dart';
import 'package:freegram/repositories/marketplace_repository.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/screens/gift_detail_screen.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MarketplaceTab extends StatelessWidget {
  const MarketplaceTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final marketplaceRepository = locator<MarketplaceRepository>();
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Center(
          child: Text("Please log in to access the marketplace."));
    }

    return StreamBuilder<List<MarketplaceListingModel>>(
      stream: marketplaceRepository.getActiveListings(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text("Error loading listings: ${snapshot.error}"));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final listings = snapshot.data!;

        if (listings.isEmpty) {
          return const Center(
              child: Text("No active listings. Be the first to sell!"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: listings.length,
          itemBuilder: (context, index) {
            final listing = listings[index];
            return _ListingCard(listing: listing, currentUserId: userId);
          },
        );
      },
    );
  }
}

class _ListingCard extends StatelessWidget {
  final MarketplaceListingModel listing;
  final String currentUserId;

  const _ListingCard({
    Key? key,
    required this.listing,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMyListing = listing.sellerId == currentUserId;

    return FutureBuilder<GiftModel?>(
      future: locator<GiftRepository>().getGiftById(listing.giftId),
      builder: (context, snapshot) {
        final gift = snapshot.data;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: gift != null
                ? () {
                    HapticHelper.light();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GiftDetailScreen(gift: gift),
                      ),
                    );
                  }
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Thumbnail (placeholder or fetch from giftId)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: gift != null && gift.thumbnailUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              gift.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.card_giftcard, size: 32),
                            ),
                          )
                        : const Icon(Icons.card_giftcard, size: 32),
                  ),
                  const SizedBox(width: 16),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gift?.name ?? "Loading...",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Seller: ${listing.sellerUsername}",
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Price & Action
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.monetization_on,
                              size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            "${listing.priceInCoins}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                                fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: isMyListing
                            ? () => _cancelListing(context)
                            : () => _purchaseListing(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMyListing
                              ? Colors.grey
                              : Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          minimumSize: const Size(80, 36),
                        ),
                        child: Text(isMyListing ? "Cancel" : "Buy"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _purchaseListing(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Purchase"),
        content: Text("Buy this item for ${listing.priceInCoins} coins?"),
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
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        await locator<MarketplaceRepository>()
            .purchaseListing(currentUserId, listing.id);

        Navigator.pop(context); // Hide loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Purchase successful!")),
        );
      } catch (e) {
        Navigator.pop(context); // Hide loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Purchase failed: $e")),
        );
      }
    }
  }

  Future<void> _cancelListing(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Listing"),
        content: const Text("Remove this item from the marketplace?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await locator<MarketplaceRepository>()
            .cancelListing(currentUserId, listing.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Listing cancelled.")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to cancel: $e")),
        );
      }
    }
  }
}
