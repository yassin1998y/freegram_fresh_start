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
import 'package:freegram/screens/random_chat/phases/disconnected_phase_overlay.dart';
import 'package:freegram/screens/random_chat/components/privacy_secure_wrapper.dart';
import 'package:freegram/screens/random_chat/animations/remote_avatar_transition.dart';
import 'package:freegram/screens/random_chat/dialogs_and_sheets/permissions_preflight_sheet.dart';
import 'package:freegram/screens/random_chat/phases/shared_components/persistent_media_controls.dart';
import 'package:freegram/screens/random_chat/phases/sub_components/primary_action_bar.dart';
import 'package:freegram/screens/random_chat/widgets/glass_overlay_container.dart';
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
          body: PrivacySecureWrapper(
            child: BlocConsumer<RandomChatBloc, RandomChatState>(
              listenWhen: (prev, curr) =>
                  prev.currentPhase != curr.currentPhase ||
                  prev.errorType != curr.errorType,
              listener: (context, state) {
                if (state.errorType == RandomChatError.permissionsDenied ||
                    state.errorType ==
                        RandomChatError.permissionsPermanentlyDenied) {
                  PermissionsPreflightSheet.show(
                    context,
                    isPermanentlyDenied: state.errorType ==
                        RandomChatError.permissionsPermanentlyDenied,
                  ).then((_) {
                    if (context.mounted) {
                      context
                          .read<RandomChatBloc>()
                          .add(const RandomChatClearError());
                    }
                  });
                }

                if (state.currentPhase == RandomChatPhase.connected) {
                  _triggerCameraFlash();
                  HapticFeedback.vibrate();
                }
              },
              builder: (context, state) {
                return SwipeToSkipDetector(
                  isEnabled: state.isGesturesEnabled,
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
      ),
    );
  }

  Widget _buildSharedUI(RandomChatState state) {
    final bool isFatalError = state.errorType == RandomChatError.permissionsDenied || 
                             state.errorType == RandomChatError.permissionsPermanentlyDenied;

    return Stack(
      children: [
        // 1. Media Controls (Bottom Left) - Visible in all phases except fatal error
        if (!isFatalError)
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              child: const MinimalistMediaControls(),
            ),
          ),

        // 2. Primary Action Bar (Right side) - Only in Connected Phase
        Align(
          alignment: Alignment.centerRight,
          child: AnimatedOpacity(
            opacity: state.currentPhase == RandomChatPhase.connected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: IgnorePointer(
              ignoring: state.currentPhase != RandomChatPhase.connected,
              child: const Padding(
                padding: EdgeInsets.only(right: DesignTokens.spaceMD),
                child: PrimaryActionBar(),
              ),
            ),
          ),
        ),

        // 3. Standalone Skip Button (Bottom Right)
        if (state.currentPhase != RandomChatPhase.idle && !isFatalError)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              child: _CircularGlassButton(
                icon: Icons.skip_next_rounded,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.read<RandomChatBloc>().add(const RandomChatStartSearching());
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBaseLayer(RandomChatState state) {
    final webrtc = locator<WebRTCService>();

    // Render remote stream during matching AND connected phases to allow for first frame detection
    if (state.currentPhase == RandomChatPhase.connected ||
        state.currentPhase == RandomChatPhase.matching) {
      if (state.isRemoteCameraOff &&
          state.currentPhase == RandomChatPhase.connected) {
        return const RemoteAvatarTransition();
      } else {
        return StreamBuilder<MediaStream?>(
          stream: webrtc.remoteStreamStream,
          builder: (context, snapshot) {
            return WebRTCRenderManager(
              stream: snapshot.data,
              isLocal: false,
              onFirstFrameRendered: () {
                context
                    .read<RandomChatBloc>()
                    .add(const RandomChatFirstFrameRendered());
              },
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
    Widget overlay;
    switch (state.currentPhase) {
      case RandomChatPhase.idle:
        overlay = const IdlePhaseOverlay(key: ValueKey(RandomChatPhase.idle));
        break;
      case RandomChatPhase.searching:
        overlay = const SearchingPhaseOverlay(
            key: ValueKey(RandomChatPhase.searching));
        break;
      case RandomChatPhase.matching:
        overlay =
            const MatchingPhaseOverlay(key: ValueKey(RandomChatPhase.matching));
        break;
      case RandomChatPhase.connected:
        overlay = const ConnectedPhaseOverlay(
            key: ValueKey(RandomChatPhase.connected));
        break;
      case RandomChatPhase.disconnected:
        overlay = const DisconnectedPhaseOverlay(
            key: ValueKey(RandomChatPhase.disconnected));
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      child: overlay,
    );
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
}

class _CircularGlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircularGlassButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: GlassOverlayContainer(
        borderRadius: BorderRadius.circular(32),
        padding: const EdgeInsets.all(DesignTokens.spaceSM),
        child: Icon(icon, color: Colors.white, size: DesignTokens.iconMD),
      ),
    );
  }
}
