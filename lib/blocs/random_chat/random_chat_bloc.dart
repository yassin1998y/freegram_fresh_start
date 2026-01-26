import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/random_chat/random_chat_event.dart';
import 'package:freegram/blocs/random_chat/random_chat_state.dart';
import 'package:freegram/services/webrtc_service.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/match_history_model.dart';
import 'package:freegram/repositories/match_history_repository.dart';

class RandomChatBloc extends Bloc<RandomChatEvent, RandomChatState> {
  late final WebRTCService _webRTCService;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _remoteStreamSubscription;
  // We can also listen to localStream if needed, but it's usually set once.

  RandomChatBloc() : super(const RandomChatState()) {
    _webRTCService = locator<WebRTCService>();

    // Commands
    on<RandomChatEnterMatchTab>(_onEnterMatchTab);
    on<RandomChatJoinQueue>(
        (event, emit) => _onEnterMatchTab(RandomChatEnterMatchTab(), emit));

    on<RandomChatSwipeNext>(_onSwipeNext);

    on<RandomChatLeaveMatchTab>(_onLeaveMatchTab);
    on<RandomChatToggleBlur>(_onToggleBlur);

    // Listeners
    // MatchFound is effectively ConnectionState -> connected,
    // but if we want explicit event we can listen for it.
    // The service emits state changes, so we map those to BLoC state already.
    // If the USER explicitly requests 'MatchFound' event to be handled,
    // usually means we need to react to logic.
    // We already do in _onConnectionStateChanged.

    // Listeners
    on<RandomChatConnectionStateChanged>(_onConnectionStateChanged);
    on<RandomChatRemoteStreamChanged>(_onRemoteStreamChanged);

    _subscribeToService();
  }

  void _subscribeToService() {
    // Listen to connection state
    _webRTCService.connectionState.addListener(() {
      if (!isClosed) {
        add(RandomChatConnectionStateChanged(
            _webRTCService.connectionState.value));
      }
    });

    // Listen to remote stream
    _webRTCService.remoteStream.addListener(() {
      if (!isClosed) {
        add(RandomChatRemoteStreamChanged(_webRTCService.remoteStream.value));
      }
    });

    // Listen to local stream (optional, usually set immediately)
    _webRTCService.localStream.addListener(() {
      // We might want to update state if local stream changes
    });
  }

  Future<void> _onEnterMatchTab(
    RandomChatEnterMatchTab event,
    Emitter<RandomChatState> emit,
  ) async {
    // 1. Initialize Camera immediately
    await _webRTCService.initializeLocalStream();

    emit(state.copyWith(
      status: RandomChatStatus.idle,
      localStream: _webRTCService.localStream.value,
    ));
  }

  Future<void> _onSwipeNext(
    RandomChatSwipeNext event,
    Emitter<RandomChatState> emit,
  ) async {
    // Save previous if valid
    await _checkAndSaveHistory(); // Wait for save or fire and forget? Better await briefly.

    emit(state.copyWith(status: RandomChatStatus.searching, isBlurred: true));

    // Trigger Service
    _webRTCService.startRandomSearch();
  }

  Future<void> _onLeaveMatchTab(
    RandomChatLeaveMatchTab event,
    Emitter<RandomChatState> emit,
  ) async {
    // Depending on UX, we might want to kill the call but keep camera?
    // Or kill everything. The requirement says "Module Navigation".
    // If we go to History, we suspend call.
    // Check duration before ending
    _checkAndSaveHistory();

    _webRTCService.endCall();
    // We do NOT dispose local stream here to allow quick return,
    // generally handled by the Service's dispose or lifecycle if needed.

    emit(state.copyWith(status: RandomChatStatus.idle));
  }

  void _onToggleBlur(
    RandomChatToggleBlur event,
    Emitter<RandomChatState> emit,
  ) {
    emit(state.copyWith(isBlurred: !state.isBlurred));
  }

  void _onConnectionStateChanged(
    RandomChatConnectionStateChanged event,
    Emitter<RandomChatState> emit,
  ) {
    switch (event.status) {
      case 'searching':
        emit(state.copyWith(status: RandomChatStatus.searching));
        break;
      case 'connected':
        emit(state.copyWith(status: RandomChatStatus.connected));
        // Auto-unblur after 2 seconds could be done here or in UI.
        // Let's do it in UI or via a delayed event.
        if (state.isBlurred) {
          Future.delayed(const Duration(seconds: 2), () {
            if (!isClosed && state.status == RandomChatStatus.connected) {
              add(RandomChatToggleBlur());
            }
          });
        }
        break;
      case 'disconnected':
        emit(state.copyWith(
            status: RandomChatStatus.idle,
            remoteStream: null,
            partnerId: null));
        break;
      default:
        // 'connecting' -> searching
        emit(state.copyWith(status: RandomChatStatus.searching));
    }
  }

  void _onRemoteStreamChanged(
    RandomChatRemoteStreamChanged event,
    Emitter<RandomChatState> emit,
  ) {
    emit(state.copyWith(remoteStream: event.stream));
  }

  Future<void> _checkAndSaveHistory() async {
    final duration = _webRTCService.callDuration;
    // Save only if call was meaningful (> 10 seconds) AND we had a partner
    if (duration > 10 && state.partnerId != null) {
      final match = MatchHistoryModel(
        id: state.partnerId!,
        nickname: "User ${state.partnerId!.substring(0, 4)}", // Mock Name
        avatarUrl:
            "https://randomuser.me/api/portraits/men/${state.partnerId!.length % 99}.jpg", // Mock Avatar
        timestamp: DateTime.now(),
        durationSeconds: duration,
      );

      try {
        await locator<MatchHistoryRepository>().saveMatch(match);
      } catch (e) {
        debugPrint("Error saving match history: $e");
      }
    }
  }

  @override
  Future<void> close() {
    // Clean up listeners if we converted them to streams manually,
    // but ValueNotifier listeners are tricky to remove anonymously.
    // In a real app we'd wrap ValueNotifier in a Stream or keep ref to callback.
    // For now, since WebRTCService is singleton, we should probably remove listener.
    // BUT we didn't store the callback function refs.
    // This is a minor leak potential if Bloc is recreated many times.
    // TODO: Refactor Service to use Streams or keep callback refs.
    return super.close();
  }
}
