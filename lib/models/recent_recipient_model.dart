/// Recent recipient model for tracking gift sending history
class RecentRecipient {
  final String userId;
  final String username;
  final String? photoUrl;
  final DateTime lastSentAt;
  final int giftCount;
  final String? lastGiftId;

  const RecentRecipient({
    required this.userId,
    required this.username,
    this.photoUrl,
    required this.lastSentAt,
    this.giftCount = 1,
    this.lastGiftId,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'photoUrl': photoUrl,
      'lastSentAt': lastSentAt.toIso8601String(),
      'giftCount': giftCount,
      'lastGiftId': lastGiftId,
    };
  }

  factory RecentRecipient.fromMap(Map<String, dynamic> map) {
    return RecentRecipient(
      userId: map['userId'] as String,
      username: map['username'] as String,
      photoUrl: map['photoUrl'] as String?,
      lastSentAt: DateTime.parse(map['lastSentAt'] as String),
      giftCount: map['giftCount'] as int? ?? 1,
      lastGiftId: map['lastGiftId'] as String?,
    );
  }

  RecentRecipient copyWith({
    String? userId,
    String? username,
    String? photoUrl,
    DateTime? lastSentAt,
    int? giftCount,
    String? lastGiftId,
  }) {
    return RecentRecipient(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      lastSentAt: lastSentAt ?? this.lastSentAt,
      giftCount: giftCount ?? this.giftCount,
      lastGiftId: lastGiftId ?? this.lastGiftId,
    );
  }
}
