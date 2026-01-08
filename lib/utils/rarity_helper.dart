import 'package:flutter/material.dart';
import 'package:freegram/models/gift_model.dart';

/// Helper class for gift rarity-based styling
class RarityHelper {
  /// Get color for a given rarity
  static Color getColor(GiftRarity rarity) {
    switch (rarity) {
      case GiftRarity.common:
        return Colors.grey.shade600;
      case GiftRarity.rare:
        return Colors.blue.shade600;
      case GiftRarity.epic:
        return Colors.purple.shade600;
      case GiftRarity.legendary:
        return Colors.amber.shade600;
    }
  }

  /// Get gradient colors for a given rarity
  static List<Color> getGradient(GiftRarity rarity) {
    switch (rarity) {
      case GiftRarity.common:
        return [Colors.grey.shade400, Colors.grey.shade600];
      case GiftRarity.rare:
        return [Colors.blue.shade400, Colors.blue.shade700];
      case GiftRarity.epic:
        return [Colors.purple.shade400, Colors.purple.shade700];
      case GiftRarity.legendary:
        return [Colors.amber.shade400, Colors.orange.shade600];
    }
  }

  /// Get glow color for a given rarity (for shadows/effects)
  static Color getGlowColor(GiftRarity rarity) {
    return getColor(rarity).withOpacity(0.4);
  }

  /// Get display name for rarity
  static String getDisplayName(GiftRarity rarity) {
    switch (rarity) {
      case GiftRarity.common:
        return 'Common';
      case GiftRarity.rare:
        return 'Rare';
      case GiftRarity.epic:
        return 'Epic';
      case GiftRarity.legendary:
        return 'Legendary';
    }
  }

  /// Get icon for rarity
  static IconData getIcon(GiftRarity rarity) {
    switch (rarity) {
      case GiftRarity.common:
        return Icons.circle;
      case GiftRarity.rare:
        return Icons.star_border;
      case GiftRarity.epic:
        return Icons.star_half;
      case GiftRarity.legendary:
        return Icons.star;
    }
  }

  /// Get box decoration with rarity styling
  static BoxDecoration getCardDecoration(GiftRarity rarity) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: getGradient(rarity),
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: getGlowColor(rarity),
          blurRadius: rarity == GiftRarity.legendary ? 12 : 8,
          spreadRadius: rarity == GiftRarity.legendary ? 2 : 0,
        ),
      ],
    );
  }

  /// Get border decoration for rarity
  static BoxDecoration getBorderDecoration(GiftRarity rarity) {
    return BoxDecoration(
      border: Border.all(
        color: getColor(rarity),
        width: rarity == GiftRarity.legendary ? 3 : 2,
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow: rarity == GiftRarity.legendary || rarity == GiftRarity.epic
          ? [
              BoxShadow(
                color: getGlowColor(rarity),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ]
          : null,
    );
  }
}
