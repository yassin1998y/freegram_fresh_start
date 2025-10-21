import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/inventory_item.dart';
import 'package:freegram/models/item_definition.dart';

/// A repository for all inventory-related Firestore operations.
class InventoryRepository {
  final FirebaseFirestore _db;

  InventoryRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Fetches a stream of a user's entire inventory subcollection.
  Stream<List<InventoryItem>> getUserInventoryStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => InventoryItem.fromDoc(doc)).toList());
  }

  /// Fetches the master definition for a single item from the root collection.
  Future<ItemDefinition> getItemDefinition(String itemId) async {
    final doc = await _db.collection('item_definitions').doc(itemId).get();
    if (!doc.exists) {
      throw Exception('Item definition not found for ID: $itemId');
    }
    return ItemDefinition.fromDoc(doc);
  }

  /// Adds an item to a user's inventory. If the item already exists, it
  /// increments the quantity.
  Future<void> addItemToInventory({
    required String userId,
    required String itemId,
    int quantity = 1,
    Map<String, dynamic>? metadata,
  }) {
    final inventoryRef =
    _db.collection('users').doc(userId).collection('inventory').doc(itemId);

    return _db.runTransaction((transaction) async {
      final doc = await transaction.get(inventoryRef);

      if (doc.exists) {
        // If the item exists, just increment the quantity
        transaction.update(inventoryRef, {
          'quantity': FieldValue.increment(quantity),
        });
      } else {
        // If it's a new item, create the document
        transaction.set(inventoryRef, {
          'itemId': itemId,
          'quantity': quantity,
          'metadata': metadata ?? {},
        });
      }
    });
  }

  /// Sets an item as the user's currently equipped profile frame or badge.
  Future<void> equipItem(String userId, ItemDefinition item) async {
    String? fieldToUpdate;
    if (item.type == ItemType.cosmetic && item.effects.containsKey('profile_frame')) {
      fieldToUpdate = 'equippedProfileFrameId';
    } else if (item.type == ItemType.cosmetic && item.effects.containsKey('profile_badge')) {
      fieldToUpdate = 'equippedBadgeId';
    }

    if (fieldToUpdate != null) {
      await _db
          .collection('users')
          .doc(userId)
          .update({fieldToUpdate: item.id});
    }
  }

  /// Unequips an item by removing the corresponding field from the user document.
  Future<void> unequipItem(String userId, ItemDefinition item) async {
    String? fieldToUpdate;
    if (item.type == ItemType.cosmetic && item.effects.containsKey('profile_frame')) {
      fieldToUpdate = 'equippedProfileFrameId';
    } else if (item.type == ItemType.cosmetic && item.effects.containsKey('profile_badge')) {
      fieldToUpdate = 'equippedBadgeId';
    }

    if (fieldToUpdate != null) {
      await _db
          .collection('users')
          .doc(userId)
          .update({fieldToUpdate: FieldValue.delete()});
    }
  }

  /// Atomically transfers one quantity of an item from a sender to a recipient.
  Future<void> transferItem({
    required String senderId,
    required String recipientId,
    required String itemId,
  }) async {
    final senderItemRef = _db.collection('users').doc(senderId).collection('inventory').doc(itemId);
    final recipientItemRef = _db.collection('users').doc(recipientId).collection('inventory').doc(itemId);

    return _db.runTransaction((transaction) async {
      final senderDoc = await transaction.get(senderItemRef);

      if (!senderDoc.exists || (senderDoc.data()?['quantity'] ?? 0) < 1) {
        throw Exception("Sender does not have this item or has insufficient quantity.");
      }

      // Decrement sender's quantity
      final newSenderQuantity = (senderDoc.data()!['quantity'] as int) - 1;
      if (newSenderQuantity > 0) {
        transaction.update(senderItemRef, {'quantity': newSenderQuantity});
      } else {
        // If quantity is zero, remove the item from their inventory
        transaction.delete(senderItemRef);
      }

      // Increment recipient's quantity
      final recipientDoc = await transaction.get(recipientItemRef);
      if (recipientDoc.exists) {
        transaction.update(recipientItemRef, {'quantity': FieldValue.increment(1)});
      } else {
        // If recipient doesn't have the item, create it for them
        transaction.set(recipientItemRef, {
          'itemId': itemId,
          'quantity': 1,
          'metadata': {},
        });
      }
    });
  }
}
