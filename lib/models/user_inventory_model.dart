import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class OwnedGift extends Equatable {
  final String id; // Unique ownership ID
  final String giftId; // Reference to GiftModel
  final String ownerId; // Current owner

  final DateTime receivedAt;
  final String? receivedFrom; // User ID who sent it
  final String? giftMessage; // Personal message

  final bool isDisplayed; // Show on profile?
  final int displayOrder; // Order on profile

  final bool isFavorite; // Marked as favorite for quick access

  final bool isUpgraded; // Enhanced version?
  final int upgradeLevel; // 0-3

  final int purchasePrice; // Original cost
  final int currentMarketValue; // Estimated value

  final bool isLocked; // Prevent accidental sale (e.g. when listed)

  const OwnedGift({
    required this.id,
    required this.giftId,
    required this.ownerId,
    required this.receivedAt,
    this.receivedFrom,
    this.giftMessage,
    this.isDisplayed = false,
    this.displayOrder = 0,
    this.isFavorite = false,
    this.isUpgraded = false,
    this.upgradeLevel = 0,
    required this.purchasePrice,
    required this.currentMarketValue,
    this.isLocked = false,
  });

  factory OwnedGift.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return OwnedGift.fromMap(doc.id, data);
  }

  factory OwnedGift.fromMap(String id, Map<String, dynamic> data) {
    return OwnedGift(
      id: id,
      giftId: data['giftId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      receivedAt:
          (data['receivedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      receivedFrom: data['receivedFrom'],
      giftMessage: data['giftMessage'],
      isDisplayed: data['isDisplayed'] ?? false,
      displayOrder: data['displayOrder'] ?? 0,
      isFavorite: data['isFavorite'] ?? false,
      isUpgraded: data['isUpgraded'] ?? false,
      upgradeLevel: data['upgradeLevel'] ?? 0,
      purchasePrice: data['purchasePrice'] ?? 0,
      currentMarketValue: data['currentMarketValue'] ?? 0,
      isLocked: data['isLocked'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'giftId': giftId,
      'ownerId': ownerId,
      'receivedAt': receivedAt,
      'receivedFrom': receivedFrom,
      'giftMessage': giftMessage,
      'isDisplayed': isDisplayed,
      'displayOrder': displayOrder,
      'isFavorite': isFavorite,
      'isUpgraded': isUpgraded,
      'upgradeLevel': upgradeLevel,
      'purchasePrice': purchasePrice,
      'currentMarketValue': currentMarketValue,
      'isLocked': isLocked,
    };
  }

  OwnedGift copyWith({
    String? id,
    String? giftId,
    String? ownerId,
    DateTime? receivedAt,
    String? receivedFrom,
    String? giftMessage,
    bool? isDisplayed,
    int? displayOrder,
    bool? isUpgraded,
    int? upgradeLevel,
    int? purchasePrice,
    int? currentMarketValue,
    bool? isLocked,
  }) {
    return OwnedGift(
      id: id ?? this.id,
      giftId: giftId ?? this.giftId,
      ownerId: ownerId ?? this.ownerId,
      receivedAt: receivedAt ?? this.receivedAt,
      receivedFrom: receivedFrom ?? this.receivedFrom,
      giftMessage: giftMessage ?? this.giftMessage,
      isDisplayed: isDisplayed ?? this.isDisplayed,
      displayOrder: displayOrder ?? this.displayOrder,
      isUpgraded: isUpgraded ?? this.isUpgraded,
      upgradeLevel: upgradeLevel ?? this.upgradeLevel,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      currentMarketValue: currentMarketValue ?? this.currentMarketValue,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  @override
  List<Object?> get props => [
        id,
        giftId,
        ownerId,
        receivedAt,
        receivedFrom,
        giftMessage,
        isDisplayed,
        displayOrder,
        isUpgraded,
        upgradeLevel,
        purchasePrice,
        currentMarketValue,
        isLocked
      ];
}
