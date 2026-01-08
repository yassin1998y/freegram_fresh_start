import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Model for a gift wishlist item
class WishlistItem extends Equatable {
  final String id;
  final String userId;
  final String giftId;
  final String giftName;
  final String? giftImageUrl;
  final int giftPrice;
  final int priority; // 1 = highest, 5 = lowest
  final String? note;
  final DateTime addedAt;
  final bool isReceived;

  const WishlistItem({
    required this.id,
    required this.userId,
    required this.giftId,
    required this.giftName,
    this.giftImageUrl,
    required this.giftPrice,
    this.priority = 3,
    this.note,
    required this.addedAt,
    this.isReceived = false,
  });

  factory WishlistItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return WishlistItem.fromMap(doc.id, data);
  }

  factory WishlistItem.fromMap(String id, Map<String, dynamic> data) {
    return WishlistItem(
      id: id,
      userId: data['userId'] ?? '',
      giftId: data['giftId'] ?? '',
      giftName: data['giftName'] ?? '',
      giftImageUrl: data['giftImageUrl'],
      giftPrice: data['giftPrice'] ?? 0,
      priority: data['priority'] ?? 3,
      note: data['note'],
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isReceived: data['isReceived'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'giftId': giftId,
      'giftName': giftName,
      'giftImageUrl': giftImageUrl,
      'giftPrice': giftPrice,
      'priority': priority,
      'note': note,
      'addedAt': Timestamp.fromDate(addedAt),
      'isReceived': isReceived,
    };
  }

  WishlistItem copyWith({
    String? id,
    String? userId,
    String? giftId,
    String? giftName,
    String? giftImageUrl,
    int? giftPrice,
    int? priority,
    String? note,
    DateTime? addedAt,
    bool? isReceived,
  }) {
    return WishlistItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      giftId: giftId ?? this.giftId,
      giftName: giftName ?? this.giftName,
      giftImageUrl: giftImageUrl ?? this.giftImageUrl,
      giftPrice: giftPrice ?? this.giftPrice,
      priority: priority ?? this.priority,
      note: note ?? this.note,
      addedAt: addedAt ?? this.addedAt,
      isReceived: isReceived ?? this.isReceived,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        giftId,
        giftName,
        giftImageUrl,
        giftPrice,
        priority,
        note,
        addedAt,
        isReceived,
      ];
}
