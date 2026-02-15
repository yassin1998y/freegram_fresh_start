import 'package:flutter/material.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/utils/rarity_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GiftVisual extends StatelessWidget {
  final GiftModel gift;
  final double size;
  final bool showRarityBackground;
  final bool animate; // Future proofing for Lottie

  const GiftVisual({
    super.key,
    required this.gift,
    this.size = 100,
    this.showRarityBackground = true,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final rarityColor = RarityHelper.getColor(gift.rarity);

    Widget content;

    // 1. Show animation if requested and available
    if (animate && gift.animationUrl.isNotEmpty) {
      // Check if it's a Lottie file (basic check)
      if (gift.animationUrl.endsWith('.json')) {
        // TODO: Implement Lottie rendering
        // For now, fall back to thumbnail or placeholder
        content = _buildThumbnailOrPlaceholder(rarityColor);
      } else {
        // Assume GIF or WebP (supported by CachedNetworkImage)
        content = CachedNetworkImage(
          imageUrl: gift.animationUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholder: (context, url) =>
              _buildThumbnailOrPlaceholder(rarityColor),
          errorWidget: (context, url, error) =>
              _buildThumbnailOrPlaceholder(rarityColor),
        );
      }
    } else {
      // 2. Show thumbnail (static)
      content = _buildThumbnailOrPlaceholder(rarityColor);
    }

    // 3. Wrap with rarity background if requested
    if (showRarityBackground) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              rarityColor.withValues(alpha: 0.3),
              rarityColor.withValues(alpha: 0.1),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(
              size * 0.2), // Rounded corners based on size
          border: Border.all(
            color: rarityColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Center(child: content),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Center(child: content),
    );
  }

  Widget _buildThumbnailOrPlaceholder(Color rarityColor) {
    if (gift.thumbnailUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: gift.thumbnailUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholder: (context, url) => _buildPlaceholderIcon(rarityColor),
        errorWidget: (context, url, error) =>
            _buildPlaceholderIcon(rarityColor),
      );
    }
    return _buildPlaceholderIcon(rarityColor);
  }

  Widget _buildPlaceholderIcon(Color color) {
    return Icon(
      Icons.card_giftcard,
      size: size * 0.6,
      color: showRarityBackground ? color : Colors.white,
    );
  }
}
