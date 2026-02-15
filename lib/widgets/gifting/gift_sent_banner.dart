import 'package:flutter/material.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/utils/rarity_helper.dart';
import 'package:intl/intl.dart';
import 'dart:math';

/// A celebratory banner shown when a gift is successfully sent
class GiftSentBanner extends StatefulWidget {
  final GiftModel gift;
  final DateTime timestamp;

  const GiftSentBanner({
    super.key,
    required this.gift,
    required this.timestamp,
  });

  @override
  State<GiftSentBanner> createState() => _GiftSentBannerState();
}

class _GiftSentBannerState extends State<GiftSentBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
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
    final formattedTime = DateFormat.jm().format(widget.timestamp);
    final rarityColor = RarityHelper.getColor(widget.gift.rarity);
    final gradientColors = RarityHelper.getGradient(widget.gift.rarity);

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: sin(_rotationAnimation.value * pi) * 0.05,
              child: Container(
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
                margin: const EdgeInsets.symmetric(
                  vertical: DesignTokens.spaceLG,
                  horizontal: DesignTokens.spaceLG,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
                  boxShadow: [
                    BoxShadow(
                      color: rarityColor.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gift Image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.network(
                          widget.gift.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.card_giftcard,
                                  color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceMD),

                    // Text Details
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gift Sent!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: DesignTokens.fontSizeLG,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 2),
                                blurRadius: 4,
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
                                color: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                RarityHelper.getDisplayName(widget.gift.rarity),
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
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: DesignTokens.fontSizeXS,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: DesignTokens.spaceMD),

                    // Trailing Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
