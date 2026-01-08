import 'package:freegram/models/gift_model.dart';

/// Extension for GiftRarity enum to provide display names
extension GiftRarityExtension on GiftRarity {
  String get displayName {
    switch (this) {
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
}

/// Extension for GiftCategory enum to provide display names
extension GiftCategoryExtension on GiftCategory {
  String get displayName {
    switch (this) {
      case GiftCategory.love:
        return 'Love';
      case GiftCategory.celebration:
        return 'Celebration';
      case GiftCategory.funny:
        return 'Funny';
      case GiftCategory.seasonal:
        return 'Seasonal';
      case GiftCategory.special:
        return 'Special';
    }
  }
}
