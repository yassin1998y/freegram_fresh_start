import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:freegram/blocs/random_chat/random_chat_event.dart';
import 'package:freegram/blocs/random_chat/random_chat_state.dart';
import 'package:freegram/services/webrtc_service.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/match_history_model.dart';
import 'package:freegram/repositories/match_history_repository.dart';
import 'package:freegram/repositories/store_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RandomChatBloc extends Bloc<RandomChatEvent, RandomChatState> {
  late final WebRTCService _webRTCService;
  final List<StreamSubscription> _subscriptions = [];

  // Track start time for history
  DateTime? _connectedTime;

  RandomChatBloc() : super(const RandomChatState()) {
    _webRTCService = locator<WebRTCService>();

    on<RandomChatEnterMatchTab>(_onEnterMatchTab);
    on<RandomChatJoinQueue>(
        (event, emit) => add(RandomChatEnterMatchTab())); // Alias

    on<RandomChatSwipeNext>(_onSwipeNext);
    on<RandomChatLeaveMatchTab>(_onLeaveMatchTab);
    on<RandomChatToggleBlur>(_onToggleBlur);
    on<RandomChatSetFilter>(_onSetFilter);

    on<RandomChatToggleMic>(_onToggleMic);
    on<RandomChatToggleCamera>(_onToggleCamera);

    // Internal Events
    on<RandomChatConnectionStateChanged>(_onConnectionStateChanged);
    on<RandomChatRemoteStreamChanged>(_onRemoteStreamChanged);
    on<RandomChatNewMessage>(_onNewMessage);
    on<RandomChatMediaStateChanged>(_onMediaStateChanged);

    _subscribeToService();
  }

  void _subscribeToService() {
    // 1. Connection State
    _subscriptions.add(_webRTCService.connectionStateStream.listen((state) {
      if (!isClosed) {
        String statusStr;
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            statusStr = 'connected';
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            statusStr = 'disconnected';
            break;
          default:
            statusStr = 'connecting';
        }
        add(RandomChatConnectionStateChanged(statusStr));
      }
    }));

    // 2. Remote Stream
    _subscriptions.add(_webRTCService.remoteStreamStream.listen((stream) {
      if (!isClosed) {
        add(RandomChatRemoteStreamChanged(stream));
      }
    }));

    // 3. UX Messages
    _subscriptions.add(_webRTCService.messageStream.listen((message) {
      if (!isClosed) {
        add(RandomChatNewMessage(message));
      }
    }));

    // 4. Media State (Mic/Cam) - Though we toggle via BLoC, keeping sync is good practice
    // Actually, service emits when toggled inside service method.
    // If we call service.toggleMic, service emits new state.
    _subscriptions.add(_webRTCService.micStateStream.listen((isOn) {
      add(RandomChatMediaStateChanged(
          isMicOn: isOn, isCameraOn: state.isCameraOn));
    }));

    _subscriptions.add(_webRTCService.cameraStateStream.listen((isOn) {
      add(RandomChatMediaStateChanged(
          isMicOn: state.isMicOn, isCameraOn: isOn));
    }));
  }

  void _onToggleMic(RandomChatToggleMic event, Emitter<RandomChatState> emit) {
    _webRTCService
        .toggleMic(); // Service emits stream update, which triggers _onMediaStateChanged
  }

  void _onToggleCamera(
      RandomChatToggleCamera event, Emitter<RandomChatState> emit) {
    _webRTCService.toggleCamera(); // Service emits stream update
  }

  void _onMediaStateChanged(
      RandomChatMediaStateChanged event, Emitter<RandomChatState> emit) {
    emit(state.copyWith(isMicOn: event.isMicOn, isCameraOn: event.isCameraOn));
  }

  Future<void> _onEnterMatchTab(
    RandomChatEnterMatchTab event,
    Emitter<RandomChatState> emit,
  ) async {
    // 1. Pre-warm Camera
    emit(state.copyWith(status: RandomChatStatus.cameraInitializing));
    await _webRTCService.initializeLocalStream();

    emit(state.copyWith(
      status: RandomChatStatus.idle,
      localStream: _webRTCService.localStream,
      isBlurred: true,
      errorMessage: null,
    ));
  }

  Future<void> _onSwipeNext(
    RandomChatSwipeNext event,
    Emitter<RandomChatState> emit,
  ) async {
    // 🛑 Monetization Check: Filter Paywall
    if (state.genderFilter != null || state.regionFilter != null) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final hasPremium =
            await locator<StoreRepository>().hasFilterPassOrCoins(userId);
        if (!hasPremium) {
          emit(state.copyWith(
            status: RandomChatStatus.searchError,
            errorMessage: 'PREMIUM_FILTER_REQUIRED',
          ));
          return;
        }
      }
    }

    await _checkAndSaveHistory();

    emit(state.copyWith(
      status: RandomChatStatus.searching,
      isBlurred: true,
      remoteStream: null,
      partnerId: null, // Reset partner
      errorMessage: null,
    ));

    _webRTCService.startRandomSearch();
  }

  void _onSetFilter(
    RandomChatSetFilter event,
    Emitter<RandomChatState> emit,
  ) {
    emit(state.copyWith(
      genderFilter: event.gender,
      regionFilter: event.region,
    ));
  }

  void _onNewMessage(
    RandomChatNewMessage event,
    Emitter<RandomChatState> emit,
  ) {
    emit(state.copyWith(infoMessage: event.message));
  }

  Future<void> _onLeaveMatchTab(
    RandomChatLeaveMatchTab event,
    Emitter<RandomChatState> emit,
  ) async {
    await _checkAndSaveHistory();
    _webRTCService.dispose();
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
      case 'connected':
        if (state.status != RandomChatStatus.connected) {
          _connectedTime = DateTime.now(); // Track start time
          emit(state.copyWith(status: RandomChatStatus.connected));

          // Smart Unblur
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (!isClosed && state.status == RandomChatStatus.connected) {
              add(RandomChatToggleBlur());
            }
          });
        }
        break;

      case 'disconnected':
        if (state.status == RandomChatStatus.connected) {
          emit(state.copyWith(status: RandomChatStatus.partnerLeft));
          _checkAndSaveHistory();
        }
        break;

      case 'connecting':
        if (state.status == RandomChatStatus.searching) {
          emit(state.copyWith(status: RandomChatStatus.matching));
        }
        break;
    }
  }

  void _onRemoteStreamChanged(
    RandomChatRemoteStreamChanged event,
    Emitter<RandomChatState> emit,
  ) {
    emit(state.copyWith(remoteStream: event.stream));
  }

  Future<void> _checkAndSaveHistory() async {
    if (_connectedTime != null) {
      final duration = DateTime.now().difference(_connectedTime!).inSeconds;
      if (duration > 5) {
        final partnerId = _webRTCService.currentPartnerId;
        if (partnerId != null) {
          final match = MatchHistoryModel(
            id: partnerId,
            nickname: "Random User",
            avatarUrl: "https://via.placeholder.com/150",
            timestamp: DateTime.now(),
            durationSeconds: duration,
          );

          try {
            await locator<MatchHistoryRepository>().saveMatch(match);
          } catch (e) {
            debugPrint("History Error: $e");
          }
        }
      }
    }
    _connectedTime = null;
  }

  @override
  Future<void> close() {
    debugPrint('[BLOC_DISPOSE] All subscriptions cancelled.');
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _webRTCService.dispose();
    return super.close();
  }
}
