import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_event.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_state.dart';
import 'package:freegram/screens/random_chat/models/match_partner_context.dart';
import 'package:freegram/services/webrtc_service.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/match_monitor_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:freegram/services/foreground_service_manager.dart';

class RandomChatBloc extends Bloc<RandomChatEvent, RandomChatState> {
  late final WebRTCService _webRTCService;
  late final MatchMonitorService _matchMonitorService;
  final List<StreamSubscription> _subscriptions = [];

  // Track start time for history
  DateTime? _connectedTime;
  Timer? _searchTimeout;
  Timer? _matchingTimeout;
  Timer? _backgroundCleanupTimer;

  RandomChatBloc() : super(const RandomChatState()) {
    _webRTCService = locator<WebRTCService>();
    _matchMonitorService = locator<MatchMonitorService>();

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
    on<RandomChatAppResumed>(_onAppResumed);
    on<RandomChatRoutePushed>(_onRoutePushed);
    on<RandomChatRoutePopped>(_onRoutePopped);
    on<RandomChatClearError>((event, emit) => emit(state.copyWith(errorType: RandomChatError.none)));
    on<RandomChatSetGesturesEnabled>((event, emit) => emit(state.copyWith(isGesturesEnabled: event.isEnabled)));

    // Internal Events
    on<RandomChatConnectionStateChanged>(_onConnectionStateChanged);
    on<RandomChatRemoteStreamChanged>(_onRemoteStreamChanged);
    on<RandomChatNewMessage>(_onNewMessage);
    on<RandomChatMediaStateChanged>(_onMediaStateChanged);
    on<RandomChatFirstFrameRendered>(_onFirstFrameRendered);
    on<RandomChatGracePeriodExpired>(_onGracePeriodExpired);
    on<RandomChatMatchingTimedOut>(_onMatchingTimedOut);

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
    
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;
    
    if (cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
      emit(state.copyWith(
        currentPhase: RandomChatPhase.idle,
        errorType: RandomChatError.permissionsPermanentlyDenied,
      ));
      return;
    }

    try {
      await _webRTCService.initializeMedia();
      emit(state.copyWith(
        currentPhase: RandomChatPhase.idle,
        // localStream is now handled by locator/service directly in component
        errorType: RandomChatError.none,
      ));
    } catch (e) {
      emit(state.copyWith(
        currentPhase: RandomChatPhase.idle,
        errorType: RandomChatError.mediaInitializationFailed,
      ));
    }
  }

  Future<void> _onEnterMatchTab(
    RandomChatEnterMatchTab event,
    Emitter<RandomChatState> emit,
  ) async {
    // Transitioning to idle phase and initializing media
    emit(state.copyWith(currentPhase: RandomChatPhase.idle));
    
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;
    
    if (cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
      emit(state.copyWith(
        currentPhase: RandomChatPhase.idle,
        errorType: RandomChatError.permissionsPermanentlyDenied,
      ));
      return;
    }

    try {
      await _webRTCService.initializeMedia();
      emit(state.copyWith(
        currentPhase: RandomChatPhase.idle,
        errorType: RandomChatError.none,
      ));
    } catch (e) {
      emit(state.copyWith(
        currentPhase: RandomChatPhase.idle,
        errorType: RandomChatError.permissionsDenied,
      ));
    }
  }

  Future<void> _onSwipeNext(
    RandomChatSwipeNext event,
    Emitter<RandomChatState> emit,
  ) async {
    // 🛑 Monetization Check: Filter Paywall
    // Filters and Paywall logic will be moved to models/config in Phase 2

    _recordHistoryIfApplicable();

    emit(state.copyWith(
      currentPhase: RandomChatPhase.searching,
      partnerContext: null, // Reset partner
      errorType: RandomChatError.none,
      isRetrying: false,
    ));

    _webRTCService.startRandomSearch();
    _matchingTimeout?.cancel();

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
    _recordHistoryIfApplicable();
    _searchTimeout?.cancel();
    _matchingTimeout?.cancel();
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
    _matchingTimeout?.cancel();
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
    if (state.currentPhase == RandomChatPhase.connected) {
      // High priority match. Keep alive with foreground service
      ForegroundServiceManager().startService();
      return;
    }
    _backgroundCleanupTimer?.cancel();
    _backgroundCleanupTimer = Timer(const Duration(seconds: 60), () {
      if (!isClosed) {
        add(const RandomChatStopSearching());
      }
    });
  }

  void _onAppResumed(
      RandomChatAppResumed event, Emitter<RandomChatState> emit) {
    ForegroundServiceManager().stopService();
    _backgroundCleanupTimer?.cancel();

    // If we dropped to disconnected in the background, we want to go straight to idle
    if (state.currentPhase == RandomChatPhase.disconnected) {
      emit(state.copyWith(currentPhase: RandomChatPhase.idle, partnerContext: null));
    }
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
          _searchTimeout?.cancel();
          _matchingTimeout?.cancel();
          _matchingTimeout = Timer(const Duration(seconds: 7), () {
            if (!isClosed) {
              add(const RandomChatMatchingTimedOut());
            }
          });

          // Create partner context from service info
          final partnerId = _webRTCService.currentPartnerId;
          final partnerContext = partnerId != null
              ? MatchPartnerContext(
                  id: partnerId,
                  name: "Random User",
                  avatarUrl: "https://via.placeholder.com/150",
                  age: 20)
              : null;

          // Stay in matching phase until first frame is rendered
          emit(state.copyWith(
            partnerContext: partnerContext,
          ));
        }
        break;

      case 'disconnected':
        if (state.currentPhase == RandomChatPhase.connected) {
          final duration = _connectedTime != null
              ? DateTime.now().difference(_connectedTime!).inSeconds
              : 0;

          emit(state.copyWith(
            currentPhase: RandomChatPhase.disconnected,
            lastMatchDurationSeconds: duration,
          ));
          _recordHistoryIfApplicable();
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

    // If we have a stream, we update partner context but STAY in matching phase
    if (event.stream != null &&
        state.currentPhase != RandomChatPhase.connected) {
      debugPrint('[BLOC_ACTION] Stream Received - Staying in Matching Phase');
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
        partnerContext: partnerContext,
      ));
    }
  }

  void _onFirstFrameRendered(
    RandomChatFirstFrameRendered event,
    Emitter<RandomChatState> emit,
  ) {
    _matchingTimeout?.cancel();
    if (state.currentPhase != RandomChatPhase.connected) {
      debugPrint(
          '🚀 [BLOC_ACTION] First Frame Rendered - Transitioning to connected');
      _connectedTime = DateTime.now();
      emit(state.copyWith(
        currentPhase: RandomChatPhase.connected,
      ));
    }
  }

  void _onGracePeriodExpired(
    RandomChatGracePeriodExpired event,
    Emitter<RandomChatState> emit,
  ) {
    debugPrint('[BLO_ACTION] Grace Period Expired - Disposing Session');
    _recordHistoryIfApplicable();
    _searchTimeout?.cancel();
    _matchingTimeout?.cancel();
    _webRTCService.dispose();
    emit(state.copyWith(
        currentPhase: RandomChatPhase.idle, partnerContext: null));
  }

  void _recordHistoryIfApplicable() {
    if (_connectedTime != null && state.partnerContext != null) {
      final duration = DateTime.now().difference(_connectedTime!).inSeconds;
      _matchMonitorService.recordSessionEnd(
        partner: state.partnerContext!,
        durationSeconds: duration,
      );
    }
    _connectedTime = null;
  }

  void _onMatchingTimedOut(
    RandomChatMatchingTimedOut event,
    Emitter<RandomChatState> emit,
  ) {
    if (state.currentPhase == RandomChatPhase.matching || state.currentPhase == RandomChatPhase.searching) {
      debugPrint('[BLOC_ACTION] Matching timeout expired - Transitioning to swipe next');
      emit(state.copyWith(
        isRetrying: true,
        errorType: RandomChatError.connectionTimeout,
      ));
      add(const RandomChatSwipeNext());
    }
  }

  @override
  Future<void> close() async {
    debugPrint('[BLOC_DISPOSE] All subscriptions cancelled.');
    for (var sub in _subscriptions) {
      await sub.cancel();
    }
    _searchTimeout?.cancel();
    _matchingTimeout?.cancel();
    _backgroundCleanupTimer?.cancel();
    _webRTCService.dispose(); 
    await ForegroundServiceManager().stopService();
    await super.close();
  }
}
