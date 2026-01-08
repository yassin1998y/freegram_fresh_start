import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/action_queue_repository.dart';
import 'package:freegram/repositories/friend_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/services/friend_cache_service.dart';
import 'package:freegram/services/friend_request_rate_limiter.dart';

part 'friends_event.dart';
part 'friends_state.dart';

class FriendsBloc extends Bloc<FriendsEvent, FriendsState> {
  final UserRepository _userRepository;
  final FriendRepository _friendRepository;
  final FirebaseAuth _firebaseAuth;
  final ActionQueueRepository _actionQueue;
  final Connectivity _connectivity;
  StreamSubscription<UserModel>? _friendshipSubscription;
  final Set<String> _pendingRequests = {}; // Bug #9 fix: Track pending requests

  FriendsBloc({
    required UserRepository userRepository,
    required FriendRepository friendRepository,
    FirebaseAuth? firebaseAuth,
    ActionQueueRepository? actionQueue,
    Connectivity? connectivity,
  })  : _userRepository = userRepository,
        _friendRepository = friendRepository,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _actionQueue = actionQueue ?? locator<ActionQueueRepository>(),
        _connectivity = connectivity ?? Connectivity(),
        super(FriendsInitial()) {
    on<LoadFriends>(_onLoadFriends);
    on<_FriendsUpdated>(_onFriendsUpdated);
    on<SendFriendRequest>(_onSendFriendRequest);
    on<CancelFriendRequest>(_onCancelFriendRequest);
    on<AcceptFriendRequest>(_onAcceptFriendRequest);
    on<DeclineFriendRequest>(_onDeclineFriendRequest);
    on<RemoveFriend>(_onRemoveFriend);
    on<BlockUser>(_onBlockUser);
    on<UnblockUser>(_onUnblockUser);
    on<ToggleFavoriteFriend>(_onToggleFavoriteFriend);
  }

  void _onLoadFriends(LoadFriends event, Emitter<FriendsState> emit) {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      emit(const FriendsError("User not authenticated."));
      return;
    }

    emit(FriendsLoading());

    // Bug #2 fix: Properly cancel existing subscription
    _friendshipSubscription?.cancel();
    _friendshipSubscription = null;

    // Bug #3 fix: Use Set comparison for better performance
    _friendshipSubscription =
        _userRepository.getUserStream(user.uid).distinct((prev, next) {
      final bool allDataUnchanged = _setsEqual(prev.friends, next.friends) &&
          _setsEqual(prev.friendRequestsSent, next.friendRequestsSent) &&
          _setsEqual(
              prev.friendRequestsReceived, next.friendRequestsReceived) &&
          _setsEqual(prev.blockedUsers, next.blockedUsers);

      if (!allDataUnchanged && kDebugMode) {
        debugPrint('[FriendsBloc] Friend data changed! Emitting update...');
      }

      return allDataUnchanged;
    }).listen(
      (userModel) {
        add(_FriendsUpdated(userModel));
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('[FriendsBloc] Stream error: $error');
        }
        emit(FriendsError(error.toString()));
      },
      cancelOnError: false,
    );
  }

  void _onFriendsUpdated(_FriendsUpdated event, Emitter<FriendsState> emit) {
    emit(FriendsLoaded(user: event.user));
  }

  Future<void> _onSendFriendRequest(
      SendFriendRequest event, Emitter<FriendsState> emit) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      emit(
          const FriendsError("You must be logged in to send friend requests."));
      return;
    }

    if (state is! FriendsLoaded) return;

    // Bug #9 fix: Prevent rapid-fire duplicate requests
    if (_pendingRequests.contains(event.toUserId)) {
      emit(const FriendsActionError(
          'Request already in progress. Please wait.'));
      return;
    }

    final currentState = state as FriendsLoaded;

    try {
      _pendingRequests.add(event.toUserId);

      final rateLimiter = locator<FriendRequestRateLimiter>();
      final canSend = await rateLimiter.canSendRequest(user.uid);

      if (!canSend) {
        final remaining = await rateLimiter.getRemainingRequests(user.uid);
        emit(FriendsActionError(
          'Daily limit reached! You can send $remaining more requests tomorrow.',
        ));
        _pendingRequests.remove(event.toUserId);
        return;
      }

      if (kDebugMode) {
        debugPrint('[FriendsBloc] Sending friend request to ${event.toUserId}');
      }

      // ⭐ PHASE 5: OFFLINE QUEUE - Check connectivity
      final isOnline = await _isOnline();
      if (!isOnline) {
        await _queueAction(
          type: 'sendFriendRequest',
          payload: {
            'currentUserId': user.uid,
            'targetUserId': event.toUserId,
            'message': event.message,
          },
        );
        emit(const FriendsActionSuccess(
          'You\'re offline. Friend request will be sent when you reconnect.',
        ));
        return;
      }

      // Optimistic UI update
      final optimisticUser = UserModel(
        id: currentState.user.id,
        username: currentState.user.username,
        email: currentState.user.email,
        photoUrl: currentState.user.photoUrl,
        bio: currentState.user.bio,
        fcmToken: currentState.user.fcmToken,
        presence: currentState.user.presence,
        lastSeen: currentState.user.lastSeen,
        country: currentState.user.country,
        age: currentState.user.age,
        gender: currentState.user.gender,
        interests: currentState.user.interests,
        createdAt: currentState.user.createdAt,
        friends: currentState.user.friends,
        friendRequestsSent: [
          ...currentState.user.friendRequestsSent,
          event.toUserId
        ],
        friendRequestsReceived: currentState.user.friendRequestsReceived,
        blockedUsers: currentState.user.blockedUsers,
        coins: currentState.user.coins,
        superLikes: currentState.user.superLikes,
        lastFreeSuperLike: currentState.user.lastFreeSuperLike,
        lastNearbyDiscoveryDate: currentState.user.lastNearbyDiscoveryDate,
        nearbyDataVersion: currentState.user.nearbyDataVersion,
        nearbyDiscoveryStreak: currentState.user.nearbyDiscoveryStreak,
        nearbyStatusEmoji: currentState.user.nearbyStatusEmoji,
        nearbyStatusMessage: currentState.user.nearbyStatusMessage,
        sharedMusicTrack: currentState.user.sharedMusicTrack,
        // Gamification fields
        lifetimeCoinsSpent: currentState.user.lifetimeCoinsSpent,
        userLevel: currentState.user.userLevel,
        equippedBorderId: currentState.user.equippedBorderId,
        equippedBadgeId: currentState.user.equippedBadgeId,
        totalGiftsReceived: currentState.user.totalGiftsReceived,
        totalGiftsSent: currentState.user.totalGiftsSent,
        uniqueGiftsCollected: currentState.user.uniqueGiftsCollected,
        lastDailyRewardClaim: currentState.user.lastDailyRewardClaim,
        dailyLoginStreak: currentState.user.dailyLoginStreak,
      );

      emit(FriendsRequestSent(user: optimisticUser));

      // Send request with optional message (handles offline queuing)
      await _friendRepository.sendFriendRequest(
        user.uid,
        event.toUserId,
        message: event.message,
      );

      // Record request for rate limiting
      await rateLimiter.recordRequest(user.uid);

      emit(const FriendsActionSuccess('Friend request sent successfully!'));
      if (kDebugMode) {
        debugPrint('[FriendsBloc] Friend request sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FriendsBloc] Error sending friend request: $e');
      }
      emit(FriendsActionError(_getFriendlyErrorMessage(e.toString())));
      emit(FriendsLoaded(user: currentState.user));
    } finally {
      _pendingRequests.remove(event.toUserId);
    }
  }

  Future<void> _onCancelFriendRequest(
      CancelFriendRequest event, Emitter<FriendsState> emit) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      emit(const FriendsError(
          "You must be logged in to cancel friend requests."));
      return;
    }

    if (state is! FriendsLoaded) return;

    final currentState = state as FriendsLoaded;

    try {
      if (kDebugMode) {
        debugPrint(
            '[FriendsBloc] Canceling friend request to ${event.toUserId}');
      }

      // Optimistic UI update - remove from sent requests
      final optimisticUser = UserModel(
        id: currentState.user.id,
        username: currentState.user.username,
        email: currentState.user.email,
        photoUrl: currentState.user.photoUrl,
        bio: currentState.user.bio,
        fcmToken: currentState.user.fcmToken,
        presence: currentState.user.presence,
        lastSeen: currentState.user.lastSeen,
        country: currentState.user.country,
        age: currentState.user.age,
        gender: currentState.user.gender,
        interests: currentState.user.interests,
        createdAt: currentState.user.createdAt,
        friends: currentState.user.friends,
        friendRequestsSent: currentState.user.friendRequestsSent
            .where((id) => id != event.toUserId)
            .toList(),
        friendRequestsReceived: currentState.user.friendRequestsReceived,
        blockedUsers: currentState.user.blockedUsers,
        coins: currentState.user.coins,
        superLikes: currentState.user.superLikes,
        lastFreeSuperLike: currentState.user.lastFreeSuperLike,
        lastNearbyDiscoveryDate: currentState.user.lastNearbyDiscoveryDate,
        nearbyDataVersion: currentState.user.nearbyDataVersion,
        nearbyDiscoveryStreak: currentState.user.nearbyDiscoveryStreak,
        nearbyStatusEmoji: currentState.user.nearbyStatusEmoji,
        nearbyStatusMessage: currentState.user.nearbyStatusMessage,
        sharedMusicTrack: currentState.user.sharedMusicTrack,
        // Gamification fields
        lifetimeCoinsSpent: currentState.user.lifetimeCoinsSpent,
        userLevel: currentState.user.userLevel,
        equippedBorderId: currentState.user.equippedBorderId,
        equippedBadgeId: currentState.user.equippedBadgeId,
        totalGiftsReceived: currentState.user.totalGiftsReceived,
        totalGiftsSent: currentState.user.totalGiftsSent,
        uniqueGiftsCollected: currentState.user.uniqueGiftsCollected,
        lastDailyRewardClaim: currentState.user.lastDailyRewardClaim,
        dailyLoginStreak: currentState.user.dailyLoginStreak,
      );

      emit(FriendsLoaded(user: optimisticUser));

      // Cancel request in repository
      await _friendRepository.cancelFriendRequest(user.uid, event.toUserId);

      emit(const FriendsActionSuccess('Friend request canceled.'));
      if (kDebugMode) {
        debugPrint('[FriendsBloc] Friend request canceled successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FriendsBloc] Error canceling friend request: $e');
      }
      emit(FriendsActionError(_getFriendlyErrorMessage(e.toString())));
      emit(FriendsLoaded(user: currentState.user));
    }
  }

  Future<void> _onAcceptFriendRequest(
      AcceptFriendRequest event, Emitter<FriendsState> emit) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      emit(const FriendsError(
          "You must be logged in to accept friend requests."));
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint(
            '[FriendsBloc] Accepting friend request from ${event.fromUserId}');
      }
      await _friendRepository.acceptFriendRequest(user.uid, event.fromUserId);

      // Invalidate cache for both users
      try {
        final cacheService = locator<FriendCacheService>();
        await cacheService.invalidateUser(user.uid);
        await cacheService.invalidateUser(event.fromUserId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              '[FriendsBloc] Cache invalidation error (non-critical): $e');
        }
      }

      emit(const FriendsActionSuccess(
          'Friend request accepted! You are now friends.'));
      if (kDebugMode) {
        debugPrint('[FriendsBloc] Friend request accepted successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FriendsBloc] Error accepting friend request: $e');
      }
      emit(FriendsActionError(_getFriendlyErrorMessage(e.toString())));
    }
  }

  Future<void> _onDeclineFriendRequest(
      DeclineFriendRequest event, Emitter<FriendsState> emit) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      emit(const FriendsError(
          "You must be logged in to decline friend requests."));
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint(
            '[FriendsBloc] Declining friend request from ${event.fromUserId}');
      }
      await _friendRepository.declineFriendRequest(user.uid, event.fromUserId);
      emit(const FriendsActionSuccess('Friend request declined.'));
      if (kDebugMode) {
        debugPrint('[FriendsBloc] Friend request declined successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FriendsBloc] Error declining friend request: $e');
      }
      emit(FriendsActionError(_getFriendlyErrorMessage(e.toString())));
    }
  }

  Future<void> _onRemoveFriend(
      RemoveFriend event, Emitter<FriendsState> emit) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      emit(const FriendsError("You must be logged in to remove friends."));
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[FriendsBloc] Removing friend ${event.friendId}');
      }
      await _friendRepository.removeFriend(user.uid, event.friendId);
      emit(const FriendsActionSuccess('Friend removed successfully.'));
      if (kDebugMode) {
        debugPrint('[FriendsBloc] Friend removed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FriendsBloc] Error removing friend: $e');
      }
      emit(FriendsActionError(_getFriendlyErrorMessage(e.toString())));
    }
  }

  Future<void> _onBlockUser(BlockUser event, Emitter<FriendsState> emit) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      emit(const FriendsError("You must be logged in to block users."));
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[FriendsBloc] Blocking user ${event.userIdToBlock}');
      }
      await _friendRepository.blockUser(user.uid, event.userIdToBlock);

      try {
        final cacheService = locator<FriendCacheService>();
        await cacheService.invalidateUser(user.uid);
        await cacheService.invalidateUser(event.userIdToBlock);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              '[FriendsBloc] Cache invalidation error (non-critical): $e');
        }
      }

      emit(const FriendsActionSuccess('User blocked successfully.'));
      if (kDebugMode) {
        debugPrint('[FriendsBloc] User blocked successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FriendsBloc] Error blocking user: $e');
      }
      emit(FriendsActionError(_getFriendlyErrorMessage(e.toString())));
    }
  }

  Future<void> _onUnblockUser(
      UnblockUser event, Emitter<FriendsState> emit) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      emit(const FriendsError("You must be logged in to unblock users."));
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[FriendsBloc] Unblocking user ${event.userIdToUnblock}');
      }
      await _friendRepository.unblockUser(user.uid, event.userIdToUnblock);
      emit(const FriendsActionSuccess('User unblocked successfully.'));
      if (kDebugMode) {
        debugPrint('[FriendsBloc] User unblocked successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FriendsBloc] Error unblocking user: $e');
      }
      emit(FriendsActionError(_getFriendlyErrorMessage(e.toString())));
    }
  }

  /// Convert technical errors to user-friendly messages
  // ⭐ PHASE 5: OFFLINE QUEUE - Check connectivity and queue actions when offline
  Future<bool> _isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _queueAction({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    if (kDebugMode) {
      debugPrint('[FriendsBloc] Queuing action (offline): $type');
    }
    await _actionQueue.addAction(type: type, payload: payload);
  }

  String _getFriendlyErrorMessage(String error) {
    if (error.contains('Already friends')) {
      return 'You are already friends with this user.';
    }
    if (error.contains('Request already sent')) {
      return 'You already sent a friend request to this user.';
    }
    if (error.contains('already sent you a request')) {
      return 'This user has already sent you a friend request! Check your Requests tab.';
    }
    if (error.contains('blocked this user')) {
      return 'You have blocked this user. Unblock them first.';
    }
    if (error.contains('blocked you')) {
      return 'This user has restricted friend requests.';
    }
    if (error.contains('not found')) {
      return 'User not found. They may have deleted their account.';
    }
    if (error.contains('network') || error.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    }
    // Default message
    return 'An error occurred. Please try again.';
  }

  /// Bug #3 fix: Use Set comparison for O(n) performance instead of O(n log n)
  bool _setsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    final set1 = Set<String>.from(list1);
    final set2 = Set<String>.from(list2);
    return set1.difference(set2).isEmpty && set2.difference(set1).isEmpty;
  }

  Future<void> _onToggleFavoriteFriend(
      ToggleFavoriteFriend event, Emitter<FriendsState> emit) async {
    debugPrint(
        "Toggling favorite status is not implemented in the current data model.");
  }

  @override
  Future<void> close() {
    // Bug #2 fix: Ensure subscription is fully cleaned up
    _friendshipSubscription?.cancel();
    _friendshipSubscription = null;
    _pendingRequests.clear();
    return super.close();
  }
}
