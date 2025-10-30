// lib/models/friend_request_limit.dart
// Model for tracking friend request rate limiting

class FriendRequestLimit {
  final DateTime date;
  final int count;
  final DateTime? resetTime;

  FriendRequestLimit({
    required this.date,
    required this.count,
    this.resetTime,
  });

  bool canSendRequest({int maxPerDay = 50}) {
    final now = DateTime.now();

    // Bug #29 fix: Use UTC to ensure consistent timezone handling
    final today = DateTime.utc(now.year, now.month, now.day);
    final limitDate = DateTime.utc(date.year, date.month, date.day);

    if (today.isAfter(limitDate)) {
      return true; // New day, limit reset
    }

    // Same day, check count
    return count < maxPerDay;
  }

  int remainingRequests({int maxPerDay = 50}) {
    if (!canSendRequest(maxPerDay: maxPerDay)) return 0;

    final now = DateTime.now();
    // Bug #29 fix: Use UTC for consistency
    final today = DateTime.utc(now.year, now.month, now.day);
    final limitDate = DateTime.utc(date.year, date.month, date.day);

    if (today.isAfter(limitDate)) {
      return maxPerDay; // New day
    }

    return maxPerDay - count;
  }

  FriendRequestLimit increment() {
    return FriendRequestLimit(
      date: DateTime.now(),
      count: count + 1,
      resetTime: _getResetTime(),
    );
  }

  FriendRequestLimit reset() {
    return FriendRequestLimit(
      date: DateTime.now(),
      count: 0,
      resetTime: _getResetTime(),
    );
  }

  DateTime _getResetTime() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow;
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'count': count,
      'resetTime': resetTime?.toIso8601String(),
    };
  }

  factory FriendRequestLimit.fromMap(Map<String, dynamic> map) {
    return FriendRequestLimit(
      date: DateTime.parse(map['date'] as String),
      count: map['count'] as int,
      resetTime: map['resetTime'] != null
          ? DateTime.parse(map['resetTime'] as String)
          : null,
    );
  }

  factory FriendRequestLimit.initial() {
    return FriendRequestLimit(
      date: DateTime.now(),
      count: 0,
      resetTime: null,
    );
  }
}
