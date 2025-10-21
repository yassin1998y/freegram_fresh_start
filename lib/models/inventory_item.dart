import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a single item instance within a user's inventory.
/// This data is stored in the `users/{userId}/inventory` subcollection.
class InventoryItem extends Equatable {
  final String id; // The document ID in the subcollection
  final String itemId; // The ID of the item definition
  final int quantity;
  final Map<String, dynamic> metadata; // For NFT info, unique data, etc.

  const InventoryItem({
    required this.id,
    required this.itemId,
    required this.quantity,
    this.metadata = const {},
  });

  factory InventoryItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return InventoryItem(
      id: doc.id,
      itemId: data['itemId'] ?? '',
      quantity: data['quantity'] ?? 0,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  @override
  List<Object?> get props => [id, itemId, quantity, metadata];
}
