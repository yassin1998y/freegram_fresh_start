import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum ProfileItemType { border, badge, theme, animation }

enum ItemRarity { common, rare, epic, legendary }

class ProfileItemModel extends Equatable {
  final String id;
  final ProfileItemType type;
  final String name;
  final String description;

  final String assetUrl;
  final Map<String, dynamic> config; // Type-specific config

  final int priceInCoins;
  final ItemRarity rarity;

  final bool isLimited;
  final DateTime? availableUntil;

  final int levelRequired;
  final List<String> achievementRequired;

  const ProfileItemModel({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.assetUrl,
    this.config = const {},
    required this.priceInCoins,
    required this.rarity,
    this.isLimited = false,
    this.availableUntil,
    this.levelRequired = 0,
    this.achievementRequired = const [],
  });

  factory ProfileItemModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProfileItemModel.fromMap(doc.id, data);
  }

  factory ProfileItemModel.fromMap(String id, Map<String, dynamic> data) {
    return ProfileItemModel(
      id: id,
      type: ProfileItemType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'border'),
        orElse: () => ProfileItemType.border,
      ),
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      assetUrl: data['assetUrl'] ?? '',
      config: data['config'] ?? {},
      priceInCoins: data['priceInCoins'] ?? 0,
      rarity: ItemRarity.values.firstWhere(
        (e) => e.name == (data['rarity'] ?? 'common'),
        orElse: () => ItemRarity.common,
      ),
      isLimited: data['isLimited'] ?? false,
      availableUntil: data['availableUntil'] != null
          ? (data['availableUntil'] as Timestamp).toDate()
          : null,
      levelRequired: data['levelRequired'] ?? 0,
      achievementRequired: List<String>.from(data['achievementRequired'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'name': name,
      'description': description,
      'assetUrl': assetUrl,
      'config': config,
      'priceInCoins': priceInCoins,
      'rarity': rarity.name,
      'isLimited': isLimited,
      'availableUntil': availableUntil,
      'levelRequired': levelRequired,
      'achievementRequired': achievementRequired,
    };
  }

  @override
  List<Object?> get props => [
        id,
        type,
        name,
        description,
        assetUrl,
        config,
        priceInCoins,
        rarity,
        isLimited,
        availableUntil,
        levelRequired,
        achievementRequired
      ];
}
