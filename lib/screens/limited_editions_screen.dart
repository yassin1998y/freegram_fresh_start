import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/models/profile_item_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/repositories/profile_repository.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class LimitedEditionsScreen extends StatelessWidget {
  const LimitedEditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Limited Editions"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, "🔥 Hot Right Now", Icons.whatshot),
            const SizedBox(height: 16),
            _LimitedGiftsSection(),
            const SizedBox(height: 24),
            _buildSectionHeader(context, "💎 Exclusive Skins", Icons.diamond),
            const SizedBox(height: 16),
            _LimitedProfileItemsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _LimitedGiftsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GiftModel>>(
      stream: locator<GiftRepository>().getAvailableGifts(limitedOnly: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppProgressIndicator());
        }

        if (snapshot.hasError) {
          return Container(
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "Failed to load limited gifts",
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const _EmptyState(
              message: "No limited edition gifts available.");
        }

        final gifts = snapshot.data!;
        return SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: gifts.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final gift = gifts[index];
              return _LimitedItemCard(
                name: gift.name,
                price: gift.priceInCoins,
                imageUrl: gift.thumbnailUrl,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Purchase feature coming soon!"),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _LimitedProfileItemsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProfileItemModel>>(
      stream: locator<ProfileRepository>().getProfileItems(limitedOnly: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppProgressIndicator());
        }

        if (snapshot.hasError) {
          return Container(
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "Failed to load limited skins",
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const _EmptyState(
              message: "No limited edition skins available.");
        }

        final items = snapshot.data!;
        return SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return _LimitedItemCard(
                name: item.name,
                price: item.priceInCoins,
                imageUrl: item.assetUrl,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Purchase feature coming soon!"),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _LimitedItemCard extends StatelessWidget {
  final String name;
  final int price;
  final String imageUrl;
  final VoidCallback onTap;

  const _LimitedItemCard({
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: const Icon(Icons.star,
                    size: 48, color: Colors.orange), // Placeholder
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        price.toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }
}
