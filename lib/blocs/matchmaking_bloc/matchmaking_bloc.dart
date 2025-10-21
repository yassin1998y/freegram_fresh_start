import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/game_session.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/game_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:meta/meta.dart';

part 'matchmaking_event.dart';
part 'matchmaking_state.dart';

class MatchmakingBloc extends Bloc<MatchmakingEvent, MatchmakingState> {
  final GameRepository _gameRepository;
  final UserRepository _userRepository;
  // FIX: Added fields to hold the selected loadout
  final BoosterType _selectedBooster;
  final List<PerkType> _selectedPerks;

  StreamSubscription? _gameSubscription;
  String? _currentGameId;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  // FIX: Added required named parameters to the constructor
  MatchmakingBloc({
    required GameRepository gameRepository,
    required UserRepository userRepository,
    required BoosterType selectedBooster,
    required List<PerkType> selectedPerks,
  })  : _gameRepository = gameRepository,
        _userRepository = userRepository,
        _selectedBooster = selectedBooster,
        _selectedPerks = selectedPerks,
        super(MatchmakingInitial()) {
    on<FindGame>(_onFindGame);
    on<CancelSearch>(_onCancelSearch);
    on<_GameStatusChanged>(_onGameStatusChanged);
  }

  Future<void> _onFindGame(FindGame event, Emitter<MatchmakingState> emit) async {
    try {
      final user = await _userRepository.getUser(_userId);
      // FIX: Pass the selected booster and perks to the repository
      _currentGameId = await _gameRepository.findOrCreateGameSession(
          user, _selectedBooster, _selectedPerks);

      emit(MatchmakingSearching(_currentGameId!));

      _gameSubscription?.cancel();
      _gameSubscription =
          _gameRepository.streamGameSession(_currentGameId!).listen((doc) {
            if (doc.exists) {
              add(_GameStatusChanged(GameSession.fromDoc(doc)));
            }
          });
    } catch (e) {
      emit(MatchmakingError(e.toString()));
    }
  }

  void _onGameStatusChanged(
      _GameStatusChanged event, Emitter<MatchmakingState> emit) {
    if (event.gameSession.status == 'active') {
      emit(MatchmakingSuccess(event.gameSession));
      _gameSubscription?.cancel();
    }
  }

  Future<void> _onCancelSearch(
      CancelSearch event, Emitter<MatchmakingState> emit) async {
    _gameSubscription?.cancel();
    if (_currentGameId != null) {
      await _gameRepository.cancelSearch(_userId, _currentGameId!);
    }
    _currentGameId = null;
    emit(MatchmakingInitial());
  }

  @override
  Future<void> close() {
    _gameSubscription?.cancel();
    if (_currentGameId != null && state is MatchmakingSearching) {
      _gameRepository.cancelSearch(_userId, _currentGameId!);
    }
    return super.close();
  }
}

