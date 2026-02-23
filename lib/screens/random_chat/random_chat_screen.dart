import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/webrtc_service.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_event.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_state.dart';
import 'package:freegram/screens/random_chat/lifecycle_and_gestures/random_chat_lifecycle_handler.dart';
import 'package:freegram/screens/random_chat/lifecycle_and_gestures/smart_snap_draggable_pip.dart';
import 'package:freegram/screens/random_chat/lifecycle_and_gestures/swipe_to_skip_detector.dart';
import 'package:freegram/screens/random_chat/components/webrtc_render_manager.dart';
import 'package:freegram/screens/random_chat/phases/idle_phase_overlay.dart';
import 'package:freegram/screens/random_chat/phases/searching_phase_overlay.dart';
import 'package:freegram/screens/random_chat/phases/matching_phase_overlay.dart';
import 'package:freegram/screens/random_chat/phases/connected_phase_overlay.dart';
import 'package:freegram/screens/random_chat/phases/shared_components/persistent_media_controls.dart';
import 'package:freegram/screens/random_chat/animations/remote_avatar_transition.dart';
import 'package:freegram/screens/random_chat/dialogs_and_sheets/permissions_preflight_sheet.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/blocs/interaction/interaction_bloc.dart';

class RandomChatScreen extends StatefulWidget {
  final bool isVisible;
  const RandomChatScreen({super.key, this.isVisible = true});

  @override
  State<RandomChatScreen> createState() => _RandomChatScreenState();
}

class _RandomChatScreenState extends State<RandomChatScreen> {
  bool _showFlash = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      _enableSecureMode();
    }
  }

  @override
  void dispose() {
    _disableSecureMode();
    super.dispose();
  }

  static const _windowChannel = MethodChannel('freegram/window_manager');
  static const int _flagSecure = 8192;

  Future<void> _enableSecureMode() async {
    if (Theme.of(context).platform != TargetPlatform.android) return;
    try {
      await _windowChannel.invokeMethod('addFlags', {'flags': _flagSecure});
    } catch (_) {}
  }

  Future<void> _disableSecureMode() async {
    if (Theme.of(context).platform != TargetPlatform.android) return;
    try {
      await _windowChannel.invokeMethod('clearFlags', {'flags': _flagSecure});
    } catch (_) {}
  }

  void _triggerCameraFlash() {
    setState(() => _showFlash = true);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _showFlash = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (context) =>
                RandomChatBloc()..add(const RandomChatEnterMatchTab())),
        BlocProvider(create: (context) => InteractionBloc()),
      ],
      child: RandomChatLifecycleHandler(
        child: Scaffold(
          backgroundColor: Colors.black,
          body: BlocConsumer<RandomChatBloc, RandomChatState>(
            listenWhen: (prev, curr) =>
                prev.currentPhase != curr.currentPhase ||
                prev.errorMessage != curr.errorMessage,
            listener: (context, state) {
              if (state.errorMessage == 'PERMISSIONS_DENIED') {
                PermissionsPreflightSheet.show(context);
              }

              if (state.currentPhase == RandomChatPhase.connected) {
                _triggerCameraFlash();
                HapticFeedback.vibrate();
              }
            },
            builder: (context, state) {
              return SwipeToSkipDetector(
                child: Stack(
                  children: [
                    // --- Layer A: Base Layer (Video Feed) ---
                    _buildBaseLayer(state),

                    // --- Layer B: Phase Overlays ---
                    _buildPhaseOverlay(state),

                    // --- Layer C: Local Video Layer (PiP) ---
                    _buildPiP(state),

                    // --- Layer D: Shared UI Layer ---
                    _buildSharedUI(state),

                    // Camera Flash Effect
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _showFlash ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBaseLayer(RandomChatState state) {
    final webrtc = locator<WebRTCService>();

    if (state.currentPhase == RandomChatPhase.connected) {
      if (state.isRemoteCameraOff) {
        return const RemoteAvatarTransition();
      } else {
        return StreamBuilder<MediaStream?>(
          stream: webrtc.remoteStreamStream,
          builder: (context, snapshot) {
            return WebRTCRenderManager(
              stream: snapshot.data,
              isLocal: false,
            );
          },
        );
      }
    } else if (state.currentPhase == RandomChatPhase.idle) {
      // Idle phase: blurry local camera
      return Stack(
        children: [
          WebRTCRenderManager(stream: webrtc.localStream, isLocal: true),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(color: Colors.black);
  }

  Widget _buildPhaseOverlay(RandomChatState state) {
    switch (state.currentPhase) {
      case RandomChatPhase.idle:
        return const IdlePhaseOverlay();
      case RandomChatPhase.searching:
        return const SearchingPhaseOverlay();
      case RandomChatPhase.matching:
        return const MatchingPhaseOverlay();
      case RandomChatPhase.connected:
        return const ConnectedPhaseOverlay();
    }
  }

  Widget _buildPiP(RandomChatState state) {
    if (state.currentPhase == RandomChatPhase.idle) {
      return const SizedBox.shrink();
    }

    return SmartSnapDraggablePiP(
      cameraPreview: WebRTCRenderManager(
        stream: locator<WebRTCService>().localStream,
        isLocal: true,
      ),
    );
  }

  Widget _buildSharedUI(RandomChatState state) {
    // Hidden only in matching
    if (state.currentPhase == RandomChatPhase.matching) {
      return const SizedBox.shrink();
    }

    return const Positioned(
      bottom: DesignTokens.spaceXL,
      left: 0,
      right: 0,
      child: PersistentMediaControls(),
    );
  }
}
