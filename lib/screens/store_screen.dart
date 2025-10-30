import 'package:cloud_firestore/cloud_firestore.dart'; // Keep for FieldValue if UserRepository uses it
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/store_repository.dart'; // Keep
import 'package:freegram/repositories/user_repository.dart'; // Keep
import 'package:freegram/services/ad_helper.dart'; // Keep
import 'package:freegram/services/in_app_purchase_service.dart'; // Keep
import 'package:freegram/widgets/freegram_app_bar.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Handle not logged in state
      return const Scaffold(
        //appBar: AppBar(title: Text("Store")),
        body: Center(child: Text("Please log in to access the store.")),
      );
    }

    // Keep DefaultTabController and Scaffold structure
    return DefaultTabController(
      length: 2, // "Get Items" and "Get Coins"
      child: Scaffold(
        appBar: FreegramAppBar(
          title: 'Store',
          showBackButton: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: "Get Items"),
              Tab(text: "Get Coins"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _GetItemsTab(userId: currentUser.uid),
            _GetCoinsTab(userId: currentUser.uid),
          ],
        ),
      ),
    );
  }
}

// _GetItemsTab remains the same
class _GetItemsTab extends StatefulWidget {
  final String userId;
  const _GetItemsTab({required this.userId});

  @override
  State<_GetItemsTab> createState() => _GetItemsTabState();
}

class _GetItemsTabState extends State<_GetItemsTab> {
  final AdHelper _adHelper = AdHelper();
  bool _isAdButtonLoading = false;
  bool _isCoinButtonLoading = false;

  @override
  void initState() {
    super.initState();
    // Preload ad
    _adHelper.loadRewardedAd();
  }

  // _showAd remains the same (uses StoreRepository.grantAdReward)
  void _showAd() {
    setState(() => _isAdButtonLoading = true);
    try {
      _adHelper.showRewardedAd(() {
        // Grant reward using StoreRepository
        locator<StoreRepository>().grantAdReward(widget.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                backgroundColor: Colors.green,
                content: Text("Success! 1 Super Like has been added.")),
          );
        }
        // Reload ad for next time
        _adHelper.loadRewardedAd();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.red,
              content: Text("Failed to show ad: $e")),
        );
      }
      _adHelper.loadRewardedAd(); // Try reloading even on failure
    } finally {
      // AdHelper callbacks handle disposal and state internally,
      // but we reset button loading state here.
      if (mounted) {
        // Add a small delay to allow ad overlay to dismiss if needed
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _isAdButtonLoading = false);
        });
      }
    }
  }

  // _purchaseWithCoins remains the same (uses StoreRepository.purchaseWithCoins)
  void _purchaseWithCoins() async {
    setState(() => _isCoinButtonLoading = true);
    try {
      // Use StoreRepository to handle coin purchase logic
      await locator<StoreRepository>().purchaseWithCoins(widget.userId,
          coinCost: 50, superLikeAmount: 5); // Example values
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              backgroundColor: Colors.green,
              content: Text("Purchase successful! 5 Super Likes added.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.red,
              content: Text("Purchase failed: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCoinButtonLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep ListView structure
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          // Keep "Earn for Free" section
          "Earn for Free",
          style: Theme.of(context).textTheme.titleLarge, // Use theme
        ),
        const SizedBox(height: 8),
        _StoreItemCard(
          // Keep Free Super Like card
          title: "Free Super Like",
          subtitle: "Watch a short ad to get one free Super Like.",
          icon: Icons.star,
          iconColor: Colors.blue,
          buttonText: "Watch Ad",
          isLoading: _isAdButtonLoading,
          onPressed: _showAd,
        ),
        const Divider(height: 32),
        Text(
          // Keep "Spend Coins" section
          "Spend Coins",
          style: Theme.of(context).textTheme.titleLarge, // Use theme
        ),
        const SizedBox(height: 8),
        _StoreItemCard(
          // Keep Super Like purchase card
          title: "5 Super Likes",
          subtitle: "Get a pack of five Super Likes to stand out.",
          icon: Icons.star,
          iconColor: Colors.blue,
          buttonText: "50 Coins", // Example price
          isLoading: _isCoinButtonLoading,
          onPressed: _purchaseWithCoins,
        ),
        // Add more items here if needed
      ],
    );
  }
}

// _GetCoinsTab remains the same (uses InAppPurchaseService and UserRepository)
class _GetCoinsTab extends StatefulWidget {
  final String userId;
  const _GetCoinsTab({required this.userId});

  @override
  State<_GetCoinsTab> createState() => _GetCoinsTabState();
}

class _GetCoinsTabState extends State<_GetCoinsTab> {
  late InAppPurchaseService _iapService;
  bool _iapLoading = true; // Track loading state for IAP

  @override
  void initState() {
    super.initState();
    _iapService = InAppPurchaseService(onPurchaseSuccess: (int amount) {
      // Use UserRepository to update coin balance
      locator<UserRepository>()
          .updateUser(widget.userId, {'coins': FieldValue.increment(amount)});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.green,
              content: Text("Success! $amount coins have been added.")),
        );
      }
    });
    // Initialize IAP and update loading state
    _iapService.initialize().then((_) {
      if (mounted) setState(() => _iapLoading = false);
    });
  }

  @override
  void dispose() {
    _iapService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while IAP service initializes
    if (_iapLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Keep ListView structure for coin packs
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _StoreItemCard(
          // Keep 100 Coins card
          title: "100 Coins",
          subtitle: "A starter pack of coins.",
          icon: Icons.monetization_on,
          iconColor: Colors.amber,
          buttonText: "\$0.99", // Example price
          onPressed: () {
            _iapService.buyProduct('com.freegram.coins100'); // Use Product ID
          },
        ),
        const SizedBox(height: 12),
        _StoreItemCard(
          // Keep 550 Coins card
          title: "550 Coins",
          subtitle: "Best value pack!",
          icon: Icons.monetization_on,
          iconColor: Colors.amber,
          buttonText: "\$4.99", // Example price
          onPressed: () {
            _iapService.buyProduct('com.freegram.coins550'); // Use Product ID
          },
        ),
        // Add more coin packs here if needed
      ],
    );
  }
}

// _StoreItemCard remains the same
class _StoreItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String buttonText;
  final VoidCallback onPressed;
  final bool isLoading;

  const _StoreItemCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.buttonText,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              child: isLoading
                  ? const SizedBox(
                      // Show spinner inside button
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
