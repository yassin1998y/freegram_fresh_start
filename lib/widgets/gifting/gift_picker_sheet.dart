import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/gifting/gift_visual.dart';

class GiftPickerSheet extends StatefulWidget {
  final String targetUserId;
  final Function(GiftModel) onGiftSent;

  const GiftPickerSheet({
    super.key,
    required this.targetUserId,
    required this.onGiftSent,
  });

  @override
  State<GiftPickerSheet> createState() => _GiftPickerSheetState();
}

class _GiftPickerSheetState extends State<GiftPickerSheet>
    with SingleTickerProviderStateMixin {
  final _giftRepo = locator<GiftRepository>();
  final _userRepo = locator<UserRepository>();

  late TabController _tabController;
  int _userCoins = 0;
  bool _isLoadingCoins = true;
  bool _isSending = false;

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
      try {
        final user = await _userRepo.getUser(currentUser.uid);
        if (mounted) {
          setState(() {
            _userCoins = user.coins;
            _isLoadingCoins = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading coins: $e');
        if (mounted) setState(() => _isLoadingCoins = false);
      }
    }
  }

  Future<void> _sendGift(GiftModel gift) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (_userCoins < gift.priceInCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough coins!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await _giftRepo.buyAndSendGift(
        senderId: currentUser.uid,
        recipientId: widget.targetUserId,
        giftId: gift.id,
        message: 'Shared from profile!',
      );

      HapticHelper.success();
      if (mounted) {
        Navigator.pop(context); // Close sheet
        widget.onGiftSent(gift);
      }
    } catch (e) {
      HapticHelper.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send gift: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _confirmSendGift(GiftModel gift) {
    HapticHelper.medium();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Gift?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GiftVisual(
              gift: gift,
              size: 80,
              animate: true,
              showRarityBackground: false,
            ),
            const SizedBox(height: 16),
            Text(
              'Send ${gift.name} for ${gift.priceInCoins} coins?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendGift(gift);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SonarPulseTheme.primaryAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Gift'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSending) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppProgressIndicator(),
              SizedBox(height: 16),
              Text('Sending gift...'),
            ],
          ),
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Send a Gift',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.amber.shade700.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.monetization_on,
                          size: 16, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      _isLoadingCoins
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              '$_userCoins',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade700,
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Categories
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: SonarPulseTheme.primaryAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: SonarPulseTheme.primaryAccent,
            tabs: GiftCategory.values
                .map((c) => Tab(text: c.displayName))
                .toList(),
          ),

          // Grid
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: GiftCategory.values
                  .map((category) => _GiftGrid(
                        category: category,
                        userCoins: _userCoins,
                        onGiftTap: _confirmSendGift,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftGrid extends StatelessWidget {
  final GiftCategory category;
  final int userCoins;
  final Function(GiftModel) onGiftTap;

  const _GiftGrid({
    required this.category,
    required this.userCoins,
    required this.onGiftTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GiftModel>>(
      stream: locator<GiftRepository>().getAvailableGifts(category: category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final gifts = snapshot.data ?? [];
        if (gifts.isEmpty) {
          return const Center(child: Text('No gifts available'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: gifts.length,
          itemBuilder: (context, index) {
            final gift = gifts[index];
            final canAfford = userCoins >= gift.priceInCoins;

            return GestureDetector(
              onTap: () {
                HapticHelper.light();
                onGiftTap(gift);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GiftVisual(
                          gift: gift,
                          size: 60,
                          animate: false,
                          showRarityBackground: false,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text(
                            gift.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.monetization_on,
                                size: 12,
                                color: canAfford
                                    ? Colors.amber.shade700
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${gift.priceInCoins}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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
            );
          },
        );
      },
    );
  }
}

extension GiftCategoryDisplay on GiftCategory {
  String get displayName {
    switch (this) {
      case GiftCategory.love:
        return 'Love';
      case GiftCategory.celebration:
        return 'Party';
      case GiftCategory.funny:
        return 'Funny';
      case GiftCategory.seasonal:
        return 'Seasonal';
      case GiftCategory.special:
        return 'Special';
    }
  }
}
