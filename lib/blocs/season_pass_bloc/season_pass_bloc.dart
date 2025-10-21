import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/season_model.dart';
import 'package:freegram/models/season_pass_reward.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/gamification_repository.dart';
import 'package:freegram/repositories/inventory_repository.dart'; // Import new repository
import 'package:freegram/repositories/user_repository.dart';
import 'package:meta/meta.dart';

part 'season_pass_event.dart';
part 'season_pass_state.dart';

class SeasonPassBloc extends Bloc<SeasonPassEvent, SeasonPassState> {
  final GamificationRepository _gamificationRepository;
  final UserRepository _userRepository;
  final InventoryRepository _inventoryRepository; // Add new dependency
  final FirebaseAuth _firebaseAuth;
  StreamSubscription<UserModel>? _userSubscription;

  Season? _currentSeason;
  List<SeasonPassReward> _rewards = [];

  SeasonPassBloc({
    required GamificationRepository gamificationRepository,
    required UserRepository userRepository,
    required InventoryRepository inventoryRepository, // Inject new dependency
    FirebaseAuth? firebaseAuth,
  })  : _gamificationRepository = gamificationRepository,
        _userRepository = userRepository,
        _inventoryRepository = inventoryRepository, // Assign new dependency
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        super(SeasonPassInitial()) {
    on<LoadSeasonPass>(_onLoadSeasonPass);
    on<ClaimReward>(_onClaimReward);
    on<_SeasonPassUpdated>(_onSeasonPassUpdated);
  }

  Future<void> _onLoadSeasonPass(
      LoadSeasonPass event, Emitter<SeasonPassState> emit) async {
    emit(SeasonPassLoading());
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      emit(const SeasonPassError("User not authenticated."));
      return;
    }

    try {
      _currentSeason = await _gamificationRepository.getCurrentSeason();
      if (_currentSeason == null) {
        emit(const SeasonPassError("No active season found."));
        return;
      }

      await _gamificationRepository.checkAndResetSeason(user.uid, _currentSeason!);
      _rewards = await _gamificationRepository.getRewardsForSeason(_currentSeason!.id);

      _userSubscription?.cancel();
      _userSubscription =
          _userRepository.getUserStream(user.uid).listen((userModel) {
            add(_SeasonPassUpdated(
              currentSeason: _currentSeason!,
              rewards: _rewards,
              user: userModel,
            ));
          });
    } catch (e) {
      emit(SeasonPassError(e.toString()));
    }
  }

  Future<void> _onClaimReward(
      ClaimReward event, Emitter<SeasonPassState> emit) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      emit(const SeasonPassError("User not authenticated."));
      return;
    }

    try {
      // Step 1: Handle the gamification logic (claiming reward, giving XP/coins).
      await _gamificationRepository.claimSeasonReward(user.uid, event.reward);

      // Step 2: If the reward is a permanent item, add it to the inventory.
      if (event.reward.type == RewardType.badge) {
        // A better long-term solution is adding an `itemId` field to the SeasonPassReward model.
        // For now, we derive a unique ID from the title.
        final itemId = event.reward.title.replaceAll(' ', '_').toLowerCase();
        await _inventoryRepository.addItemToInventory(
          userId: user.uid,
          itemId: itemId,
        );
      }
    } catch (e) {
      debugPrint("Error claiming reward: $e");
    }
  }

  void _onSeasonPassUpdated(
      _SeasonPassUpdated event, Emitter<SeasonPassState> emit) {
    emit(SeasonPassLoaded(
      currentSeason: event.currentSeason,
      rewards: event.rewards,
      user: event.user,
    ));
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}
