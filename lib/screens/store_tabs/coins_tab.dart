import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/services/in_app_purchase_service.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class CoinsTab extends StatefulWidget {
  final String userId;
  const CoinsTab({Key? key, required this.userId}) : super(key: key);

  @override
  State<CoinsTab> createState() => _CoinsTabState();
}

class _CoinsTabState extends State<CoinsTab> {
  late InAppPurchaseService _iapService;
  bool _iapLoading = true;

  @override
  void initState() {
    super.initState();
    _iapService = InAppPurchaseService(onPurchaseSuccess: (int amount) {
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
    if (_iapLoading) {
      return const Center(child: AppProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _CoinPackCard(
          title: "100 Coins",
          subtitle: "A starter pack of coins.",
          icon: Icons.monetization_on,
          iconColor: Colors.amber,
          buttonText: "\$0.99",
          onPressed: () {
            _iapService.buyProduct('com.freegram.coins100');
          },
        ),
        const SizedBox(height: 12),
        _CoinPackCard(
          title: "550 Coins",
          subtitle: "Great value!",
          icon: Icons.monetization_on,
          iconColor: Colors.amber,
          buttonText: "\$4.99",
          onPressed: () {
            _iapService.buyProduct('com.freegram.coins550');
          },
        ),
        const SizedBox(height: 12),
        _CoinPackCard(
          title: "1200 Coins",
          subtitle: "Most Popular!",
          icon: Icons.monetization_on,
          iconColor: Colors.amber,
          buttonText: "\$9.99",
          badge: "POPULAR",
          badgeColor: Colors.blue,
          onPressed: () {
            _iapService.buyProduct('com.freegram.coins1200');
          },
        ),
        const SizedBox(height: 12),
        _CoinPackCard(
          title: "2500 Coins",
          subtitle: "Stock up and save.",
          icon: Icons.monetization_on,
          iconColor: Colors.amber,
          buttonText: "\$19.99",
          onPressed: () {
            _iapService.buyProduct('com.freegram.coins2500');
          },
        ),
        const SizedBox(height: 12),
        _CoinPackCard(
          title: "6500 Coins",
          subtitle: "Best Value Pack!",
          icon: Icons.monetization_on,
          iconColor: Colors.amber,
          buttonText: "\$49.99",
          badge: "BEST VALUE",
          badgeColor: Colors.red,
          onPressed: () {
            _iapService.buyProduct('com.freegram.coins6500');
          },
        ),
      ],
    );
  }
}

class _CoinPackCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String buttonText;
  final VoidCallback onPressed;
  final String? badge;
  final Color? badgeColor;

  const _CoinPackCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.buttonText,
    required this.onPressed,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12)),
                  child: Text(buttonText),
                ),
              ],
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor ?? Colors.red,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
