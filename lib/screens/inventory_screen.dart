import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
import 'package:freegram/blocs/inventory_bloc/inventory_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/item_definition.dart';
import 'package:freegram/repositories/inventory_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/friends_list_screen.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => InventoryBloc(
        inventoryRepository: locator<InventoryRepository>(),
      )..add(LoadInventory()),
      child: const _InventoryView(),
    );
  }
}

class _InventoryView extends StatelessWidget {
  const _InventoryView();

  Color _getRarityColor(BuildContext context, ItemRarity rarity) {
    switch (rarity) {
      case ItemRarity.common:
        return Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
      case ItemRarity.uncommon:
        return Colors.green;
      case ItemRarity.rare:
        return Theme.of(context).colorScheme.primary;
      case ItemRarity.epic:
        return Colors.purple;
      case ItemRarity.legendary:
        return Colors.orange;
    }
  }

  void _giftItem(BuildContext context, BuildContext modalContext, ItemDefinition itemDef) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (context) => FriendsBloc(
            userRepository: locator<UserRepository>(),
          )..add(LoadFriends()),
          child: FriendsListScreen(
            onFriendSelected: (selectedFriendId) async {
              Navigator.of(modalContext).pop();

              try {
                await locator<InventoryRepository>().transferItem(
                  senderId: currentUser.uid,
                  recipientId: selectedFriendId,
                  itemId: itemDef.id,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Successfully gifted ${itemDef.name}!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to send gift: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  void _showItemDetailSheet(
      BuildContext context, ItemDefinition itemDef, int quantity) {
    final inventoryRepo = locator<InventoryRepository>();
    final currentUser = FirebaseAuth.instance.currentUser;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CachedNetworkImage(
                imageUrl: itemDef.imageUrl,
                height: 100,
                width: 100,
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) =>
                const Icon(Icons.error, size: 50),
              ),
              const SizedBox(height: 16),
              Text(
                itemDef.name,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                itemDef.rarity.name.toUpperCase(),
                style: TextStyle(
                  color: _getRarityColor(context, itemDef.rarity),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                itemDef.description,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (itemDef.type == ItemType.cosmetic && currentUser != null)
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await inventoryRepo.equipItem(
                              currentUser.uid, itemDef);
                          Navigator.pop(modalContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${itemDef.name} equipped!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to equip item: $e'),
                              backgroundColor: Theme.of(context).colorScheme.error,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Equip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: () {
                      _giftItem(context, modalContext, itemDef);
                    },
                    icon: const Icon(Icons.card_giftcard),
                    label: const Text('Gift'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryGrid(
      BuildContext context, ItemType type, InventoryLoaded state) {
    final itemsOfType = state.inventoryItems
        .where((item) => state.itemDefinitions[item.itemId]?.type == type)
        .toList();

    if (itemsOfType.isEmpty) {
      return Center(
        child: Text(
          "No ${type.name} items found.",
          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: itemsOfType.length,
      itemBuilder: (context, index) {
        final item = itemsOfType[index];
        final itemDef = state.itemDefinitions[item.itemId];
        if (itemDef == null) {
          return const Card(child: Center(child: Icon(Icons.error)));
        }

        return GestureDetector(
          onTap: () => _showItemDetailSheet(context, itemDef, item.quantity),
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            child: GridTile(
              footer: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 4.0, horizontal: 8.0),
                color: Colors.black.withOpacity(0.6),
                child: Text(
                  itemDef.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: itemDef.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                        Container(color: Theme.of(context).dividerColor),
                    errorWidget: (context, url, error) =>
                        Icon(Icons.inventory_2_outlined,
                            size: 40, color: Theme.of(context).iconTheme.color),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'x${item.quantity}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getRarityColor(context, itemDef.rarity),
                        width: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Inventory'),
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).iconTheme.color,
            tabs: const [
              Tab(text: 'Cosmetics'),
              Tab(text: 'Collectibles'),
              Tab(text: 'Boosters'),
            ],
          ),
        ),
        body: BlocBuilder<InventoryBloc, InventoryState>(
          builder: (context, state) {
            if (state is InventoryLoading || state is InventoryInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is InventoryError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error: ${state.message}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              );
            }
            if (state is InventoryLoaded) {
              return TabBarView(
                children: [
                  _buildCategoryGrid(context, ItemType.cosmetic, state),
                  _buildCategoryGrid(context, ItemType.permanent, state),
                  _buildCategoryGrid(context, ItemType.booster, state),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}