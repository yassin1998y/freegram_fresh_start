import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/models/user_inventory_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/utils/rarity_helper.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/navigation/app_routes.dart';
import 'package:freegram/screens/gift_detail_screen.dart';
import 'package:freegram/scripts/gift_seeder.dart'; // Temporary import for seeding
import 'package:freegram/widgets/gifting/gift_visual.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _giftRepo = locator<GiftRepository>();
  bool _isAdmin = false;

  _SortOption _sortBy = _SortOption.dateDesc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          final isAdmin =
              userData?['isAdmin'] == true || userData?['role'] == 'admin';
          if (mounted) {
            setState(() {
              _isAdmin = isAdmin;
            });
          }
        }
      } catch (e) {
        print('Error checking admin status: $e');
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Inventory"),
        actions: [
          // Temporary Seeding Button (Admin Only)
          if (_isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.cloud_upload, color: Colors.red),
              tooltip: 'Seed Gifts',
              onSelected: (value) async {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Seeding $value...')),
                  );

                  final seeder = GiftSeeder();
                  if (value == 'Red Rose') {
                    await seeder.seedRedRose();
                  } else if (value == 'Heart Balloon') {
                    await seeder.seedHeartBalloon();
                  } else if (value == 'Teddy Bear') {
                    await seeder.seedTeddyBear();
                  } else if (value == 'Diamond Ring') {
                    await seeder.seedDiamondRing();
                  } else if (value == 'Party Popper') {
                    await seeder.seedPartyPopper();
                  }

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$value seeded successfully! ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'Red Rose',
                  child: Text('Seed Red Rose'),
                ),
                const PopupMenuItem(
                  value: 'Heart Balloon',
                  child: Text('Seed Heart Balloon'),
                ),
                const PopupMenuItem(
                  value: 'Teddy Bear',
                  child: Text('Seed Teddy Bear'),
                ),
                const PopupMenuItem(
                  value: 'Diamond Ring',
                  child: Text('Seed Diamond Ring ⭐'),
                ),
                const PopupMenuItem(
                  value: 'Party Popper',
                  child: Text('Seed Party Popper 🎉'),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Gifts", icon: Icon(Icons.card_giftcard, size: 20)),
            Tab(text: "Skins", icon: Icon(Icons.palette, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGiftsTab(currentUser.uid),
          _buildSkinsTab(currentUser.uid),
        ],
      ),
    );
  }

  Widget _buildGiftsTab(String userId) {
    return StreamBuilder<List<OwnedGift>>(
      stream: _giftRepo.getUserInventory(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text("Failed to load inventory"),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticHelper.medium();
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inventory_2,
            title: "No gifts yet",
            subtitle: "Purchase gifts from the store to get started!",
          );
        }

        final gifts = _applyFiltersAndSort(snapshot.data!);

        return Column(
          children: [
            _buildStatsCard(gifts),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
                itemCount: gifts.length,
                itemBuilder: (context, index) {
                  return _GiftInventoryCard(
                    ownedGift: gifts[index],
                    onTap: () => _showGiftDetail(gifts[index]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkinsTab(String userId) {
    return _buildEmptyState(
      icon: Icons.palette,
      title: "Skins coming soon",
      subtitle: "Profile customization items will appear here",
    );
  }

  Widget _buildStatsCard(List<OwnedGift> gifts) {
    final totalValue = gifts.fold<int>(
      0,
      (acc, gift) => acc + gift.currentMarketValue,
    );

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.inventory_2,
              label: "Items",
              value: gifts.length.toString(),
            ),
            Container(
              width: 1,
              height: 40,
              color: Theme.of(context).dividerColor,
            ),
            _StatItem(
              icon: Icons.monetization_on,
              label: "Value",
              value: totalValue.toString(),
            ),
            Container(
              width: 1,
              height: 40,
              color: Theme.of(context).dividerColor,
            ),
            _StatItem(
              icon: Icons.star,
              label: "Displayed",
              value: gifts.where((g) => g.isDisplayed).length.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              HapticHelper.medium();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.shopping_bag),
            label: const Text("Browse Gifts"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  List<OwnedGift> _applyFiltersAndSort(List<OwnedGift> gifts) {
    var filtered = gifts;

    switch (_sortBy) {
      case _SortOption.dateDesc:
        filtered.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
        break;
      case _SortOption.dateAsc:
        filtered.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
        break;
      case _SortOption.valueDesc:
        filtered.sort(
            (a, b) => b.currentMarketValue.compareTo(a.currentMarketValue));
        break;
      case _SortOption.valueAsc:
        filtered.sort(
            (a, b) => a.currentMarketValue.compareTo(b.currentMarketValue));
        break;
    }

    return filtered;
  }

  void _showFilterSheet() {
    HapticHelper.light();
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Sort & Filter",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            const Text("Sort by:",
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _SortOption.values.map((option) {
                return ChoiceChip(
                  label: Text(option.label),
                  selected: _sortBy == option,
                  onSelected: (selected) {
                    HapticHelper.selection();
                    setState(() => _sortBy = option);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showGiftDetail(OwnedGift ownedGift) {
    HapticHelper.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _GiftDetailSheet(ownedGift: ownedGift),
    );
  }
}

// Stats Item Widget
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
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
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// Gift Inventory Card with Rarity Styling
class _GiftInventoryCard extends StatelessWidget {
  final OwnedGift ownedGift;
  final VoidCallback onTap;

  const _GiftInventoryCard({
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
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: RarityHelper.getColor(rarity).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: RarityHelper.getGradient(rarity),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Center(
                          child: gift != null
                              ? GiftVisual(
                                  gift: gift,
                                  size: 80,
                                  showRarityBackground: false,
                                  animate: true,
                                )
                              : const Icon(
                                  Icons.card_giftcard,
                                  size: 48,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gift?.name ?? 'Gift',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                RarityHelper.getIcon(rarity),
                                size: 10,
                                color: RarityHelper.getColor(rarity),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                RarityHelper.getDisplayName(rarity),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: RarityHelper.getColor(rarity),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.monetization_on,
                                  size: 10, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                ownedGift.currentMarketValue.toString(),
                                style: const TextStyle(fontSize: 9),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (ownedGift.isDisplayed)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.visibility,
                          size: 12, color: Colors.white),
                    ),
                  ),
                if (rarity == GiftRarity.legendary)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '⭐',
                        style: TextStyle(fontSize: 10),
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

// Gift Detail Sheet with Toggle Functionality
class _GiftDetailSheet extends StatefulWidget {
  final OwnedGift ownedGift;

  const _GiftDetailSheet({required this.ownedGift});

  @override
  State<_GiftDetailSheet> createState() => _GiftDetailSheetState();
}

class _GiftDetailSheetState extends State<_GiftDetailSheet> {
  bool _isTogglingDisplay = false;

  Future<void> _toggleDisplay() async {
    if (_isTogglingDisplay) return;

    setState(() => _isTogglingDisplay = true);
    HapticHelper.medium();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final giftRepo = locator<GiftRepository>();

      // Toggle display
      await giftRepo.toggleGiftDisplay(
        userId: currentUser.uid,
        giftId: widget.ownedGift.id,
        isDisplayed: widget.ownedGift.isDisplayed,
      );

      if (mounted) {
        HapticHelper.success();

        // Check if reward was earned (only when enabling display)
        // Check if reward was earned (only when enabling display)
        if (!widget.ownedGift.isDisplayed) {
          // Give a moment for the reward check to complete
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;

          // Check if reward was just earned
          final rewardResult =
              await giftRepo.checkAndAwardDisplayReward(currentUser.uid);
          if (!mounted) return;

          if (rewardResult != null && rewardResult['awarded'] == true) {
            // Show reward notification
            HapticHelper.heavy();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.emoji_events,
                        color: Colors.amber, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🎉 ${rewardResult['achievement']}!',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Earned ${rewardResult['amount']} coins for displaying 3 gifts!',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Nice!',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
              ),
            );
          } else {
            // Regular success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gift now displayed on profile'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          // Hide message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gift hidden from profile'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        HapticHelper.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update display: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isTogglingDisplay = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasReceivedFrom = widget.ownedGift.receivedFrom != null &&
        widget.ownedGift.receivedFrom != 'daily_reward';

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              HapticHelper.light();
              // Fetch gift model
              final giftRepo = locator<GiftRepository>();
              final gift = await giftRepo.getGiftById(widget.ownedGift.giftId);

              if (!context.mounted) return;
              if (gift != null) {
                Navigator.pop(context); // Close sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GiftDetailScreen(gift: gift),
                  ),
                );
              }
            },
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.pink.shade100,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.card_giftcard, size: 50, color: Colors.pink),
            ),
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
          _DetailRow(label: "ID", value: widget.ownedGift.giftId),
          _DetailRow(
            label: "Received",
            value:
                "${widget.ownedGift.receivedAt.day}/${widget.ownedGift.receivedAt.month}/${widget.ownedGift.receivedAt.year}",
          ),
          if (widget.ownedGift.receivedFrom != null)
            _DetailRow(label: "From", value: widget.ownedGift.receivedFrom!),
          if (widget.ownedGift.giftMessage != null)
            _DetailRow(label: "Message", value: widget.ownedGift.giftMessage!),
          _DetailRow(
            label: "Value",
            value: "${widget.ownedGift.currentMarketValue} coins",
          ),

          // Thank you button for received gifts
          if (hasReceivedFrom) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  HapticHelper.success();
                  final giftRepo = locator<GiftRepository>();
                  final currentUser = FirebaseAuth.instance.currentUser;

                  if (currentUser != null &&
                      widget.ownedGift.receivedFrom != null) {
                    try {
                      await giftRepo.thankSender(
                        recipientId: currentUser.uid,
                        senderId: widget.ownedGift.receivedFrom!,
                        giftId: widget.ownedGift.id,
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Thank you sent! ❤️'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.favorite, color: Colors.pink),
                label: const Text('Say Thanks'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.pink),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isTogglingDisplay ? null : _toggleDisplay,
                  icon: _isTogglingDisplay
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          widget.ownedGift.isDisplayed
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                  label: Text(
                    widget.ownedGift.isDisplayed ? "Hide" : "Display",
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticHelper.medium();

                    // Fetch gift model first
                    final giftRepo = locator<GiftRepository>();
                    final gift =
                        await giftRepo.getGiftById(widget.ownedGift.giftId);

                    if (context.mounted && gift != null) {
                      Navigator.pop(context); // Close sheet
                      Navigator.pushNamed(
                        context,
                        AppRoutes.giftSendFriendPicker,
                        arguments: {
                          'gift': gift,
                          'ownedGiftId': widget.ownedGift.id,
                        },
                      );
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Could not load gift details')),
                      );
                    }
                  },
                  icon: const Icon(Icons.send),
                  label: const Text("Send"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

enum _SortOption {
  dateDesc("Newest First"),
  dateAsc("Oldest First"),
  valueDesc("Highest Value"),
  valueAsc("Lowest Value");

  final String label;
  const _SortOption(this.label);
}
