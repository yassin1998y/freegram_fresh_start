import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum ListingStatus { active, sold, cancelled, expired }

class MarketplaceListingModel extends Equatable {
  final String id;
  final String sellerId;
  final String sellerUsername;

  final String giftId; // What's being sold (GiftModel ID)
  final String ownedGiftId; // Specific instance (OwnedGift ID)

  final int priceInCoins;
  final ListingStatus status;

  final DateTime listedAt;
  final DateTime? expiresAt;
  final DateTime? soldAt;
  final String? buyerId;

  final int views;
  final int favorites;

  const MarketplaceListingModel({
    required this.id,
    required this.sellerId,
    required this.sellerUsername,
    required this.giftId,
    required this.ownedGiftId,
    required this.priceInCoins,
    required this.status,
    required this.listedAt,
    this.expiresAt,
    this.soldAt,
    this.buyerId,
    this.views = 0,
    this.favorites = 0,
  });

  factory MarketplaceListingModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MarketplaceListingModel.fromMap(doc.id, data);
  }

  factory MarketplaceListingModel.fromMap(
      String id, Map<String, dynamic> data) {
    return MarketplaceListingModel(
      id: id,
      sellerId: data['sellerId'] ?? '',
      sellerUsername: data['sellerUsername'] ?? '',
      giftId: data['giftId'] ?? '',
      ownedGiftId: data['ownedGiftId'] ?? '',
      priceInCoins: data['priceInCoins'] ?? 0,
      status: ListingStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'active'),
        orElse: () => ListingStatus.active,
      ),
      listedAt: (data['listedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      soldAt: (data['soldAt'] as Timestamp?)?.toDate(),
      buyerId: data['buyerId'],
      views: data['views'] ?? 0,
      favorites: data['favorites'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'sellerUsername': sellerUsername,
      'giftId': giftId,
      'ownedGiftId': ownedGiftId,
      'priceInCoins': priceInCoins,
      'status': status.name,
      'listedAt': listedAt,
      'expiresAt': expiresAt,
      'soldAt': soldAt,
      'buyerId': buyerId,
      'views': views,
      'favorites': favorites,
    };
  }

  @override
  List<Object?> get props => [
        id,
        sellerId,
        sellerUsername,
        giftId,
        ownedGiftId,
        priceInCoins,
        status,
        listedAt,
        expiresAt,
        soldAt,
        buyerId,
        views,
        favorites
      ];
}
