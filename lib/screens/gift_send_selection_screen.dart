import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:freegram/utils/rarity_helper.dart';
import 'package:freegram/utils/gift_extensions.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/screens/gift_detail_screen.dart';
import 'package:freegram/widgets/gifting/gift_visual.dart';

/// Gift selection screen for sending
class GiftSendSelectionScreen extends StatefulWidget {
  final UserModel recipient;

  const GiftSendSelectionScreen({
    super.key,
    required this.recipient,
  });

  @override
  State<GiftSendSelectionScreen> createState() =>
      _GiftSendSelectionScreenState();
}

class _GiftSendSelectionScreenState extends State<GiftSendSelectionScreen>
    with SingleTickerProviderStateMixin {
  final _giftRepo = locator<GiftRepository>();
  final _userRepo = locator<UserRepository>();

  late TabController _tabController;
  GiftModel? _selectedGift;
  int _userCoins = 0;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: GiftCategory.values.length, vsync: this);
    _loadUserCoins();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Send Gift to ${widget.recipient.username}'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Coin balance
              _buildCoinBalance(),
              // Category tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: GiftCategory.values
                    .map((category) => Tab(text: category.displayName))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: GiftCategory.values
            .map((category) => _buildGiftGrid(category))
            .toList(),
      ),
      bottomNavigationBar:
          _selectedGift != null ? _buildContinueButton() : null,
    );
  }

  Widget _buildCoinBalance() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.monetization_on, color: Colors.amber.shade700, size: 24),
          const SizedBox(width: 8),
          Text(
            '$_userCoins coins',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftGrid(GiftCategory category) {
    return StreamBuilder<List<GiftModel>>(
      stream: _giftRepo.getAvailableGifts(category: category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final gifts = snapshot.data ?? [];

        if (gifts.isEmpty) {
          return _buildEmptyState(category);
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: gifts.length,
          itemBuilder: (context, index) {
            return _buildGiftCard(gifts[index]);
          },
        );
      },
    );
  }

  Widget _buildGiftCard(GiftModel gift) {
    final isSelected = _selectedGift?.id == gift.id;
    final canAfford = _userCoins >= gift.priceInCoins;

    return GestureDetector(
      onTap: () {
        if (!canAfford) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not enough coins!'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        HapticHelper.light();
        setState(() {
          _selectedGift = isSelected ? null : gift;
        });
      },
      onLongPress: () => _showGiftPreview(gift),
      child: Stack(
        children: [
          Card(
            elevation: isSelected ? 8 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isSelected
                  ? const BorderSide(color: Colors.purple, width: 3)
                  : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gift Visual (Animation/Image)
                  Expanded(
                    child: Center(
                      child: GiftVisual(
                        gift: gift,
                        size: 100,
                        showRarityBackground: false,
                        animate: true,
                      ),
                    ),
                  ),

                  // Gift info
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gift.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.monetization_on,
                              size: 14,
                              color: canAfford
                                  ? Colors.amber.shade700
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${gift.priceInCoins}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: canAfford
                                    ? Colors.amber.shade700
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Selection indicator
          if (isSelected)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.purple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

          // Can't afford overlay
          if (!canAfford)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(GiftCategory category) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_giftcard, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No ${category.displayName} gifts',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check other categories',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _showGiftPreview(GiftModel gift) {
    HapticHelper.medium();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final rarityColor = RarityHelper.getColor(gift.rarity);
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: rarityColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    gift.rarity.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  gift.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.monetization_on, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Text(
                      '${gift.priceInCoins} coins',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      HapticHelper.light();
                      Navigator.pop(context); // Close sheet
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GiftDetailScreen(gift: gift),
                        ),
                      );
                    },
                    child: const Text("View Full Details"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              HapticHelper.medium();
              Navigator.pushNamed(
                context,
                '/gift-send-composer',
                arguments: {
                  'recipient': widget.recipient,
                  'gift': _selectedGift,
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue to Message',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
