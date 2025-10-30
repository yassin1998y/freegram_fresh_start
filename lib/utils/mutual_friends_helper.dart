// lib/utils/mutual_friends_helper.dart
// Bug #27 fix: Helper for calculating mutual friends

class MutualFriendsHelper {
  /// Count mutual friends between two users, excluding blocked users
  static int countMutualFriends(
    List<String> friends1,
    List<String> friends2,
    List<String> blockedUsers,
  ) {
    if (friends1.isEmpty || friends2.isEmpty) return 0;

    // Find intersection, excluding blocked users
    return friends1
        .where((id) => friends2.contains(id) && !blockedUsers.contains(id))
        .length;
  }

  /// Get list of mutual friend IDs
  static List<String> getMutualFriendIds(
    List<String> friends1,
    List<String> friends2,
    List<String> blockedUsers,
  ) {
    if (friends1.isEmpty || friends2.isEmpty) return [];

    return friends1
        .where((id) => friends2.contains(id) && !blockedUsers.contains(id))
        .toList();
  }

  /// Get mutual friends count with simplified signature
  static int getMutualFriendsCount(
    List<String> currentUserFriends,
    List<String> otherUserFriends,
  ) {
    return countMutualFriends(currentUserFriends, otherUserFriends, []);
  }

  /// Get mutual interests
  static List<String> getMutualInterests(
    List<String> interests1,
    List<String> interests2,
  ) {
    if (interests1.isEmpty || interests2.isEmpty) return [];
    return interests1.where((i) => interests2.contains(i)).toList();
  }

  /// Format mutual friends text
  static String formatMutualFriendsText(int count) {
    if (count == 0) return '';
    if (count == 1) return '1 mutual friend';
    return '$count mutual friends';
  }

  /// Format mutual interests text
  static String formatMutualInterestsText(List<String> interests) {
    if (interests.isEmpty) return '';
    if (interests.length == 1) return interests[0];
    if (interests.length == 2) return '${interests[0]} & ${interests[1]}';
    return '${interests[0]}, ${interests[1]} & ${interests.length - 2} more';
  }
}
