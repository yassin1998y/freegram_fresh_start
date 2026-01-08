import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/store_repository.dart';
import 'package:freegram/services/ad_helper.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class BoostsTab extends StatefulWidget {
  final String userId;
  const BoostsTab({Key? key, required this.userId}) : super(key: key);

  @override
  State<BoostsTab> createState() => _BoostsTabState();
}

class _BoostsTabState extends State<BoostsTab> {
  final AdHelper _adHelper = AdHelper();
  bool _isAdButtonLoading = false;
  bool _isCoinButtonLoading = false;

  @override
  void initState() {
    super.initState();
    _adHelper.loadRewardedAd();
  }

  void _showAd() {
    setState(() => _isAdButtonLoading = true);
    try {
      _adHelper.showRewardedAd(() {
        locator<StoreRepository>().grantAdReward(widget.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                backgroundColor: Colors.green,
                content: Text("Success! 1 Super Like has been added.")),
          );
        }
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
      _adHelper.loadRewardedAd();
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _isAdButtonLoading = false);
        });
      }
    }
  }

  void _purchaseWithCoins() async {
    setState(() => _isCoinButtonLoading = true);
    try {
      await locator<StoreRepository>()
          .purchaseWithCoins(widget.userId, coinCost: 50, superLikeAmount: 5);
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
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          "Earn for Free",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        _BoostItemCard(
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
          "Spend Coins",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        _BoostItemCard(
          title: "5 Super Likes",
          subtitle: "Get a pack of five Super Likes to stand out.",
          icon: Icons.star,
          iconColor: Colors.blue,
          buttonText: "50 Coins",
          isLoading: _isCoinButtonLoading,
          onPressed: _purchaseWithCoins,
        ),
      ],
    );
  }
}

class _BoostItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String buttonText;
  final VoidCallback onPressed;
  final bool isLoading;

  const _BoostItemCard({
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
                  ? AppProgressIndicator(
                      size: 20,
                      strokeWidth: 2,
                      color: Colors.white,
                    )
                  : Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
