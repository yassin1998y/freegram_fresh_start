import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/profile_item_model.dart';
import 'package:freegram/repositories/profile_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final profileRepository = locator<ProfileRepository>();
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Center(child: Text("Please log in to view profile items."));
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "Borders"),
              Tab(text: "Badges"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ProfileItemGrid(type: ProfileItemType.border, userId: userId),
                _ProfileItemGrid(type: ProfileItemType.badge, userId: userId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileItemGrid extends StatelessWidget {
  final ProfileItemType type;
  final String userId;

  const _ProfileItemGrid({
    Key? key,
    required this.type,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final profileRepository = locator<ProfileRepository>();

    return StreamBuilder<List<ProfileItemModel>>(
      stream: profileRepository.getProfileItems(type: type),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error loading items: ${snapshot.error}"));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!;

        if (items.isEmpty) {
          return Center(child: Text("No ${type.name}s available yet."));
        }

        return StreamBuilder<List<String>>(
          stream: profileRepository.getUserOwnedItemIds(userId),
          builder: (context, ownedSnapshot) {
            final ownedIds = ownedSnapshot.data ?? [];

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isOwned = ownedIds.contains(item.id);
                return _ProfileItemCard(
                  item: item,
                  isOwned: isOwned,
                  userId: userId,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ProfileItemCard extends StatelessWidget {
  final ProfileItemModel item;
  final bool isOwned;
  final String userId;

  const _ProfileItemCard({
    Key? key,
    required this.item,
    required this.isOwned,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: item.assetUrl.isNotEmpty
                    ? Image.network(
                        item.assetUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported, size: 48),
                      )
                    : const Icon(Icons.image, size: 48),
              ),
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isOwned) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on,
                          size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        "${item.priceInCoins}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleAction(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOwned
                          ? Colors.green
                          : Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(isOwned ? "Equip" : "Buy"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context) async {
    if (isOwned) {
      // Equip logic
      try {
        await locator<ProfileRepository>()
            .equipProfileItem(userId, item.id, item.type);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Equipped ${item.name}!")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to equip: $e")),
        );
      }
    } else {
      // Purchase logic
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Purchase ${item.name}?"),
          content: Text("This will cost ${item.priceInCoins} coins."),
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
          // Show loading
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );

          await locator<ProfileRepository>()
              .purchaseProfileItem(userId, item.id);

          // Hide loading
          Navigator.pop(context);

          // Show success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Successfully purchased ${item.name}!")),
          );
        } catch (e) {
          // Hide loading
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Purchase failed: $e")),
          );
        }
      }
    }
  }
}
