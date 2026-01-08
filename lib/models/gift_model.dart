import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum GiftRarity { common, rare, epic, legendary }

enum GiftCategory { love, celebration, funny, seasonal, special }

class GiftModel extends Equatable {
  final String id;
  final String name;
  final String description;
  final String animationUrl; // Lottie or GIF
  final String thumbnailUrl; // Static preview

  final int priceInCoins;
  final GiftRarity rarity;
  final GiftCategory category;

  final bool isLimited;
  final int? maxQuantity;
  final int soldCount;
  final DateTime? availableUntil;

  final bool isTradeable;
  final bool canBeUpgraded;

  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const GiftModel({
    required this.id,
    required this.name,
    required this.description,
    required this.animationUrl,
    required this.thumbnailUrl,
    required this.priceInCoins,
    required this.rarity,
    required this.category,
    this.isLimited = false,
    this.maxQuantity,
    this.soldCount = 0,
    this.availableUntil,
    this.isTradeable = true,
    this.canBeUpgraded = false,
    required this.createdAt,
    this.metadata = const {},
  });

  factory GiftModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GiftModel.fromMap(doc.id, data);
  }

  factory GiftModel.fromMap(String id, Map<String, dynamic> data) {
    return GiftModel(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      animationUrl: data['animationUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      priceInCoins: data['priceInCoins'] ?? 0,
      rarity: GiftRarity.values.firstWhere(
        (e) => e.name == (data['rarity'] ?? 'common'),
        orElse: () => GiftRarity.common,
      ),
      category: GiftCategory.values.firstWhere(
        (e) => e.name == (data['category'] ?? 'special'),
        orElse: () => GiftCategory.special,
      ),
      isLimited: data['isLimited'] ?? false,
      maxQuantity: data['maxQuantity'],
      soldCount: data['soldCount'] ?? 0,
      availableUntil: data['availableUntil'] != null
          ? (data['availableUntil'] as Timestamp).toDate()
          : null,
      isTradeable: data['isTradeable'] ?? true,
      canBeUpgraded: data['canBeUpgraded'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'animationUrl': animationUrl,
      'thumbnailUrl': thumbnailUrl,
      'priceInCoins': priceInCoins,
      'rarity': rarity.name,
      'category': category.name,
      'isLimited': isLimited,
      'maxQuantity': maxQuantity,
      'soldCount': soldCount,
      'availableUntil': availableUntil,
      'isTradeable': isTradeable,
      'canBeUpgraded': canBeUpgraded,
      'createdAt': createdAt,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        animationUrl,
        thumbnailUrl,
        priceInCoins,
        rarity,
        category,
        isLimited,
        maxQuantity,
        soldCount,
        availableUntil,
        isTradeable,
        canBeUpgraded,
        createdAt,
        metadata
      ];
}
