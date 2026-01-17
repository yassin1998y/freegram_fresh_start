import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/utils/rarity_helper.dart';
import 'package:freegram/screens/gift_detail_screen.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:intl/intl.dart';
import 'package:freegram/widgets/gifting/gift_visual.dart';

/// A banner displayed in the chat for gift messages
class GiftMessageBanner extends StatefulWidget {
  final String giftId;
  final DateTime timestamp;
  final bool isMe;

  const GiftMessageBanner({
    super.key,
    required this.giftId,
    required this.timestamp,
    required this.isMe,
  });

  @override
  State<GiftMessageBanner> createState() => _GiftMessageBannerState();
}

class _GiftMessageBannerState extends State<GiftMessageBanner>
    with SingleTickerProviderStateMixin {
  late Future<GiftModel?> _giftFuture;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _giftFuture = locator<GiftRepository>().getGiftById(widget.giftId);

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GiftModel?>(
      future: _giftFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink(); // Hide until loaded
        }

        final gift = snapshot.data!;
        final formattedTime = DateFormat.jm().format(widget.timestamp);
        final rarityColor = RarityHelper.getColor(gift.rarity);
        final gradientColors = RarityHelper.getGradient(gift.rarity);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
            child: GestureDetector(
              onTap: () {
                HapticHelper.light();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GiftDetailScreen(gift: gift),
                  ),
                );
              },
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(DesignTokens.spaceMD),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
                    boxShadow: [
                      BoxShadow(
                        color: rarityColor.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Gift Visual
                      GiftVisual(
                        gift: gift,
                        size: 50,
                        showRarityBackground: true,
                        animate: true,
                      ),
                      const SizedBox(width: DesignTokens.spaceMD),

                      // Text Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.isMe
                                  ? 'You sent a gift!'
                                  : 'Sent you a gift!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: DesignTokens.fontSizeMD,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    RarityHelper.getDisplayName(gift.rarity),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formattedTime,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: DesignTokens.fontSizeXS,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.card_giftcard,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
