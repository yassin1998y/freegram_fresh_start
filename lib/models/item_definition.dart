import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum ItemType { consumable, permanent, cosmetic, booster, gift }
enum ItemRarity { common, uncommon, rare, epic, legendary }

/// Represents the master definition of an item that can exist in the app.
/// This data is stored in the root `item_definitions` collection.
class ItemDefinition extends Equatable {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final ItemType type;
  final ItemRarity rarity;
  final Map<String, dynamic> effects; // e.g., {'xp_boost': 1.5, 'duration_hours': 1}

  const ItemDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.type,
    required this.rarity,
    this.effects = const {},
  });

  factory ItemDefinition.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ItemDefinition(
      id: doc.id,
      name: data['name'] ?? 'Unknown Item',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      type: ItemType.values.byName(data['type'] ?? 'consumable'),
      rarity: ItemRarity.values.byName(data['rarity'] ?? 'common'),
      effects: Map<String, dynamic>.from(data['effects'] ?? {}),
    );
  }

  @override
  List<Object?> get props => [id, name, description, imageUrl, type, rarity, effects];
}
