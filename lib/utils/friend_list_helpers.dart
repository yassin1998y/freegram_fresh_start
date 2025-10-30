// lib/utils/friend_list_helpers.dart
// Helper utilities for friend list sorting, filtering, and display

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/user_model.dart';

/// Enum for sorting options
enum FriendSortOption {
  alphabetical,
  mostActive,
  recentlyAdded,
}

/// Helper class for friend list operations
class FriendListHelpers {
  /// Sort friends by selected option
  static List<UserModel> sortFriends(
    List<UserModel> friends,
    FriendSortOption option,
  ) {
    final sortedList = List<UserModel>.from(friends);

    switch (option) {
      case FriendSortOption.alphabetical:
        sortedList.sort((a, b) =>
            a.username.toLowerCase().compareTo(b.username.toLowerCase()));
        break;

      case FriendSortOption.mostActive:
        sortedList.sort((a, b) {
          // Online users first
          if (a.presence && !b.presence) return -1;
          if (!a.presence && b.presence) return 1;
          // Then by last seen
          return b.lastSeen.compareTo(a.lastSeen);
        });
        break;

      case FriendSortOption.recentlyAdded:
        sortedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return sortedList;
  }

  /// Filter friends by search query
  static List<UserModel> filterFriends(
    List<UserModel> friends,
    String query,
  ) {
    if (query.isEmpty) return friends;

    // Bug #36 fix: Use toLowerCase for case-insensitive search
    // Special regex characters are handled by contains() which does literal matching
    final lowerQuery = query.toLowerCase();

    return friends.where((user) {
      return user.username.toLowerCase().contains(lowerQuery) ||
          user.bio.toLowerCase().contains(lowerQuery) ||
          user.interests
              .any((interest) => interest.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Get sort option display name
  static String getSortOptionName(FriendSortOption option) {
    switch (option) {
      case FriendSortOption.alphabetical:
        return 'A-Z';
      case FriendSortOption.mostActive:
        return 'Most Active';
      case FriendSortOption.recentlyAdded:
        return 'Recently Added';
    }
  }
}

/// Debouncer for search input
class Debouncer {
  final Duration delay;
  Timer? _timer;
  bool _disposed = false;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  void run(VoidCallback action) {
    // Bug #24 fix: Check if disposed before running
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  // Bug #24 fix: Add cancel method
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
