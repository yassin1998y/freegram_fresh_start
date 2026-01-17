import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/marketplace_listing_model.dart';
import 'package:freegram/models/user_inventory_model.dart';
import 'package:freegram/models/user_model.dart';

class MarketplaceRepository {
  final FirebaseFirestore _db;

  MarketplaceRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Create a new listing
  Future<void> createListing({
    required String userId,
    required String username,
    required String giftId,
    required String ownedGiftId,
    required int priceInCoins,
  }) async {
    return await _db.runTransaction((transaction) async {
      // 1. Verify ownership and lock item
      final ownedGiftRef = _db
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .doc(ownedGiftId);

      final ownedGiftDoc = await transaction.get(ownedGiftRef);
      if (!ownedGiftDoc.exists) throw Exception('Item not found');

      final ownedGift = OwnedGift.fromDoc(ownedGiftDoc);
      if (ownedGift.ownerId != userId) throw Exception('Not owner');
      if (ownedGift.isLocked) throw Exception('Item already listed or locked');

      // 2. Create listing
      final listingRef = _db.collection('marketplaceListings').doc();
      final listing = MarketplaceListingModel(
        id: listingRef.id,
        sellerId: userId,
        sellerUsername: username,
        giftId: giftId,
        ownedGiftId: ownedGiftId,
        priceInCoins: priceInCoins,
        status: ListingStatus.active,
        listedAt: DateTime.now(),
      );

      transaction.set(listingRef, listing.toMap());

      // 3. Lock item in inventory
      transaction.update(ownedGiftRef, {'isLocked': true});
    });
  }

  /// Purchase a listing
  Future<void> purchaseListing(String buyerId, String listingId) async {
    return await _db.runTransaction((transaction) async {
      // 1. Get listing
      final listingRef = _db.collection('marketplaceListings').doc(listingId);
      final listingDoc = await transaction.get(listingRef);
      if (!listingDoc.exists) throw Exception('Listing not found');

      final listing = MarketplaceListingModel.fromDoc(listingDoc);
      if (listing.status != ListingStatus.active) {
        throw Exception('Listing not active');
      }
      if (listing.sellerId == buyerId) {
        throw Exception('Cannot buy own listing');
      }

      // 2. Get buyer
      final buyerRef = _db.collection('users').doc(buyerId);
      final buyerDoc = await transaction.get(buyerRef);
      if (!buyerDoc.exists) throw Exception('Buyer not found');
      final buyer = UserModel.fromDoc(buyerDoc);

      // 3. Validate balance
      if (buyer.coins < listing.priceInCoins) {
        throw Exception('Insufficient coins');
      }

      // 4. Get seller
      final sellerRef = _db.collection('users').doc(listing.sellerId);
      final sellerDoc = await transaction.get(sellerRef);
      if (!sellerDoc.exists) throw Exception('Seller not found');

      // 5. Get owned item (from seller's inventory)
      final ownedGiftRef = _db
          .collection('users')
          .doc(listing.sellerId)
          .collection('inventory')
          .doc(listing.ownedGiftId);

      final ownedGiftDoc = await transaction.get(ownedGiftRef);
      if (!ownedGiftDoc.exists) {
        throw Exception('Item not found in seller inventory');
      }
      final ownedGift = OwnedGift.fromDoc(ownedGiftDoc);

      // 6. Transfer item (delete from seller, add to buyer)
      // Ideally we move the document, but Firestore doesn't support move.
      // So we create new and delete old.

      final newOwnedGiftRef = _db
          .collection('users')
          .doc(buyerId)
          .collection('inventory')
          .doc(); // New ID for buyer

      final newOwnedGift = ownedGift.copyWith(
        id: newOwnedGiftRef.id,
        ownerId: buyerId,
        receivedAt: DateTime
            .now(), // Reset received date? Or keep original? Let's reset for "purchase date"
        receivedFrom: listing.sellerId, // Bought from seller
        isLocked: false, // Unlock
        purchasePrice: listing.priceInCoins,
        currentMarketValue: listing.priceInCoins,
      );

      transaction.set(newOwnedGiftRef, newOwnedGift.toMap());
      transaction.delete(ownedGiftRef);

      // 7. Transfer coins (Buyer -> Seller)
      // Platform fee? Let's say 0% for now.
      transaction.update(buyerRef, {
        'coins': FieldValue.increment(-listing.priceInCoins),
        'lifetimeCoinsSpent': FieldValue.increment(listing.priceInCoins),
        // Recalculate level? Maybe later.
      });

      transaction.update(sellerRef, {
        'coins': FieldValue.increment(listing.priceInCoins),
      });

      // 8. Update listing status
      transaction.update(listingRef, {
        'status': ListingStatus.sold.name,
        'buyerId': buyerId,
        'soldAt': FieldValue.serverTimestamp(),
      });

      // 9. Log transaction
      final transactionRef = _db.collection('coinTransactions').doc();
      transaction.set(transactionRef, {
        'userId': buyerId,
        'type': 'marketplace_buy',
        'amount': -listing.priceInCoins,
        'description': 'Bought item from ${listing.sellerUsername}',
        'category': 'marketplace',
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {'listingId': listingId, 'itemId': listing.giftId},
      });

      // Log for seller too
      final sellerTransactionRef = _db.collection('coinTransactions').doc();
      transaction.set(sellerTransactionRef, {
        'userId': listing.sellerId,
        'type': 'marketplace_sell',
        'amount': listing.priceInCoins,
        'description': 'Sold item to user',
        'category': 'marketplace',
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {'listingId': listingId, 'itemId': listing.giftId},
      });
    });
  }

  /// Cancel a listing
  Future<void> cancelListing(String userId, String listingId) async {
    return await _db.runTransaction((transaction) async {
      final listingRef = _db.collection('marketplaceListings').doc(listingId);
      final listingDoc = await transaction.get(listingRef);
      if (!listingDoc.exists) throw Exception('Listing not found');

      final listing = MarketplaceListingModel.fromDoc(listingDoc);
      if (listing.sellerId != userId) throw Exception('Not owner');
      if (listing.status != ListingStatus.active) {
        throw Exception('Listing not active');
      }

      // Unlock item
      final ownedGiftRef = _db
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .doc(listing.ownedGiftId);

      transaction.update(ownedGiftRef, {'isLocked': false});

      // Update listing
      transaction.update(listingRef, {
        'status': ListingStatus.cancelled.name,
      });
    });
  }

  /// Get active listings
  Stream<List<MarketplaceListingModel>> getActiveListings() {
    return _db
        .collection('marketplaceListings')
        .where('status', isEqualTo: ListingStatus.active.name)
        .orderBy('listedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MarketplaceListingModel.fromDoc(doc))
            .toList());
  }
}
