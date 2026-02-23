import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_event.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_state.dart';
import 'package:freegram/screens/random_chat/models/match_partner_context.dart';
import 'package:freegram/services/webrtc_service.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/match_history_model.dart';
import 'package:freegram/repositories/match_history_repository.dart';
// Removed unused imports

class RandomChatBloc extends Bloc<RandomChatEvent, RandomChatState> {
  late final WebRTCService _webRTCService;
  final List<StreamSubscription> _subscriptions = [];

  // Track start time for history
  DateTime? _connectedTime;
  Timer? _searchTimeout;

  RandomChatBloc() : super(const RandomChatState()) {
    _webRTCService = locator<WebRTCService>();

    on<RandomChatEnterMatchTab>(_onEnterMatchTab);
    on<RandomChatJoinQueue>(
        (event, emit) => add(const RandomChatEnterMatchTab())); // Alias

    on<RandomChatSwipeNext>(_onSwipeNext);
    on<InitializeGatedScreen>(_onInitializeGatedScreen);

    on<RandomChatLeaveMatchTab>(_onLeaveMatchTab);
    // on<RandomChatToggleBlur>(_onToggleBlur); // Retired
    on<RandomChatSetFilter>(_onSetFilter);

    on<RandomChatToggleMic>(_onToggleMic);
    on<RandomChatToggleCamera>(_onToggleCamera);

    // New Event Handlers
    on<RandomChatStartSearching>(_onStartSearching);
    on<RandomChatStopSearching>(_onStopSearching);
    on<RandomChatToggleLocalCamera>(_onToggleLocalCamera);
    on<RandomChatToggleLocalMic>(_onToggleLocalMic);
    on<RandomChatRemoteMediaChanged>(_onRemoteMediaChanged);
    on<RandomChatAppBackgrounded>(_onAppBackgrounded);
    on<RandomChatRoutePushed>(_onRoutePushed);
    on<RandomChatRoutePopped>(_onRoutePopped);

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

    // 4. Media State (Mic/Cam)
    _subscriptions.add(_webRTCService.micStateStream.listen((isOn) {
      add(RandomChatMediaStateChanged(
          isMicOn: isOn, isCameraOn: !state.isLocalCameraOff));
    }));

    _subscriptions.add(_webRTCService.cameraStateStream.listen((isOn) {
      add(RandomChatMediaStateChanged(
          isMicOn: !state.isLocalMicOff, isCameraOn: isOn));
    }));
  }

  Future<void> _onInitializeGatedScreen(
    InitializeGatedScreen event,
    Emitter<RandomChatState> emit,
  ) async {
    // Logic for unlocking/gating is being refactored.
    // Transitioning directly to media initialization.

    emit(state.copyWith(currentPhase: RandomChatPhase.idle));
    try {
      await _webRTCService.initializeMedia();
      emit(state.copyWith(
        currentPhase: RandomChatPhase.idle,
        // localStream is now handled by locator/service directly in component
        errorMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        currentPhase: RandomChatPhase.idle,
        errorMessage: "Failed to initialize camera: $e",
      ));
    }
  }

  Future<void> _onEnterMatchTab(
    RandomChatEnterMatchTab event,
    Emitter<RandomChatState> emit,
  ) async {
    // Transitioning to idle phase and initializing media
    emit(state.copyWith(currentPhase: RandomChatPhase.idle));
    await _webRTCService.initializeMedia();

    emit(state.copyWith(
      currentPhase: RandomChatPhase.idle,
      errorMessage: null,
    ));
  }

  Future<void> _onSwipeNext(
    RandomChatSwipeNext event,
    Emitter<RandomChatState> emit,
  ) async {
    // 🛑 Monetization Check: Filter Paywall
    // Filters and Paywall logic will be moved to models/config in Phase 2

    await _checkAndSaveHistory();

    emit(state.copyWith(
      currentPhase: RandomChatPhase.searching,
      partnerContext: null, // Reset partner
      errorMessage: null,
    ));

    _webRTCService.startRandomSearch();

    // Start 15s Global Search Timeout
    _searchTimeout?.cancel();
    _searchTimeout = Timer(const Duration(seconds: 15), () {
      if (!isClosed && state.currentPhase != RandomChatPhase.connected) {
        add(const RandomChatNewMessage(
            "Connection timed out. Searching new partner..."));
        add(const RandomChatSwipeNext());
      }
    });
  }

  void _onToggleMic(RandomChatToggleMic event, Emitter<RandomChatState> emit) {
    _webRTCService.toggleMic();
  }

  void _onToggleCamera(
      RandomChatToggleCamera event, Emitter<RandomChatState> emit) {
    _webRTCService.toggleCamera();
  }

  void _onMediaStateChanged(
    RandomChatMediaStateChanged event,
    Emitter<RandomChatState> emit,
  ) {
    emit(state.copyWith(
      isLocalMicOff: !event.isMicOn,
      isLocalCameraOff: !event.isCameraOn,
    ));
  }

  void _onSetFilter(
    RandomChatSetFilter event,
    Emitter<RandomChatState> emit,
  ) {
    // Filters are being refactored out of the main state
  }

  void _onNewMessage(
    RandomChatNewMessage event,
    Emitter<RandomChatState> emit,
  ) {
    // Info messages handled via UI dialogs/sheets in next steps
  }

  Future<void> _onLeaveMatchTab(
    RandomChatLeaveMatchTab event,
    Emitter<RandomChatState> emit,
  ) async {
    await _checkAndSaveHistory();
    _searchTimeout?.cancel();
    _webRTCService.dispose();
    emit(state.copyWith(currentPhase: RandomChatPhase.idle));
  }

  // --- New Lifecycle and Toggle Handlers ---

  void _onStartSearching(
      RandomChatStartSearching event, Emitter<RandomChatState> emit) {
    add(const RandomChatSwipeNext());
  }

  void _onStopSearching(
      RandomChatStopSearching event, Emitter<RandomChatState> emit) {
    _searchTimeout?.cancel();
    _webRTCService.dispose();
    emit(state.copyWith(currentPhase: RandomChatPhase.idle));
  }

  void _onToggleLocalCamera(
      RandomChatToggleLocalCamera event, Emitter<RandomChatState> emit) {
    _webRTCService.toggleCamera();
  }

  void _onToggleLocalMic(
      RandomChatToggleLocalMic event, Emitter<RandomChatState> emit) {
    _webRTCService.toggleMic();
  }

  void _onRemoteMediaChanged(
      RandomChatRemoteMediaChanged event, Emitter<RandomChatState> emit) {
    emit(state.copyWith(
      isRemoteCameraOff: event.isCameraOff,
      isRemoteMicOff: event.isMicOff,
    ));
  }

  void _onAppBackgrounded(
      RandomChatAppBackgrounded event, Emitter<RandomChatState> emit) {
    add(const RandomChatStopSearching());
  }

  void _onRoutePushed(
      RandomChatRoutePushed event, Emitter<RandomChatState> emit) {
    // Media flow optimization placeholder
  }

  void _onRoutePopped(
      RandomChatRoutePopped event, Emitter<RandomChatState> emit) {
    // Media flow optimization placeholder
  }

  void _onConnectionStateChanged(
    RandomChatConnectionStateChanged event,
    Emitter<RandomChatState> emit,
  ) {
    switch (event.status) {
      case 'connected':
        if (state.currentPhase != RandomChatPhase.connected) {
          _connectedTime = DateTime.now(); // Track start time
          _searchTimeout?.cancel();

          // Create partner context from service info
          final partnerId = _webRTCService.currentPartnerId;
          final partnerContext = partnerId != null
              ? MatchPartnerContext(
                  id: partnerId,
                  name: "Random User",
                  avatarUrl: "https://via.placeholder.com/150",
                  age: 20)
              : null;

          emit(state.copyWith(
            currentPhase: RandomChatPhase.connected,
            partnerContext: partnerContext,
          ));
        }
        break;

      case 'disconnected':
        if (state.currentPhase == RandomChatPhase.connected) {
          emit(state.copyWith(
            currentPhase: RandomChatPhase.idle,
            partnerContext: null,
          ));
          _checkAndSaveHistory();
        }
        break;

      case 'connecting':
        if (state.currentPhase == RandomChatPhase.searching) {
          emit(state.copyWith(currentPhase: RandomChatPhase.matching));
        }
        break;
    }
  }

  void _onRemoteStreamChanged(
    RandomChatRemoteStreamChanged event,
    Emitter<RandomChatState> emit,
  ) {
    // remoteStream is now handled by locator/service directly in component

    // FORCE UI TRANSITION: If we have a stream, we are effectively connected
    if (event.stream != null &&
        state.currentPhase != RandomChatPhase.connected) {
      debugPrint(
          '🚀 [BLOC_ACTION] Force transitioning to connected (Stream Received)');
      _connectedTime = DateTime.now(); // Track start time
      _searchTimeout?.cancel();

      final partnerId = _webRTCService.currentPartnerId;
      final partnerContext = partnerId != null
          ? MatchPartnerContext(
              id: partnerId,
              name: "Random User",
              avatarUrl: "https://via.placeholder.com/150",
              age: 20)
          : null;

      emit(state.copyWith(
        currentPhase: RandomChatPhase.connected,
        partnerContext: partnerContext,
      ));
    }
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
  Future<void> close() async {
    debugPrint('[BLOC_DISPOSE] All subscriptions cancelled.');
    for (var sub in _subscriptions) {
      await sub.cancel();
    }
    _searchTimeout?.cancel();
    // _webRTCService.dispose(); // Do not dispose service to keep call alive in PiP or background
    await super.close();
  }
}
