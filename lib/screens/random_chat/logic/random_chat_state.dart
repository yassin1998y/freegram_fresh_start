import 'package:equatable/equatable.dart';
import 'package:freegram/screens/random_chat/models/match_partner_context.dart';

enum RandomChatPhase { idle, searching, matching, connected, disconnected }

enum RandomChatError {
  none,
  permissionsDenied,
  permissionsPermanentlyDenied,
  connectionTimeout,
  mediaInitializationFailed,
}

class RandomChatState extends Equatable {
  final RandomChatPhase currentPhase;
  final MatchPartnerContext? partnerContext;
  final bool isLocalCameraOff;
  final bool isLocalMicOff;
  final bool isRemoteCameraOff;
  final bool isRemoteMicOff;
  final RandomChatError errorType;
  final bool isRetrying;
  final bool isGesturesEnabled;
  final int? lastMatchDurationSeconds;

  const RandomChatState({
    this.currentPhase = RandomChatPhase.idle,
    this.partnerContext,
    this.isLocalCameraOff = false,
    this.isLocalMicOff = false,
    this.isRemoteCameraOff = false,
    this.isRemoteMicOff = false,
    this.errorType = RandomChatError.none,
    this.isRetrying = false,
    this.isGesturesEnabled = true,
    this.lastMatchDurationSeconds,
  });

  RandomChatState copyWith({
    RandomChatPhase? currentPhase,
    Object? partnerContext = const Object(),
    bool? isLocalCameraOff,
    bool? isLocalMicOff,
    bool? isRemoteCameraOff,
    bool? isRemoteMicOff,
    RandomChatError? errorType,
    bool? isRetrying,
    bool? isGesturesEnabled,
    int? lastMatchDurationSeconds,
  }) {
    return RandomChatState(
      currentPhase: currentPhase ?? this.currentPhase,
      partnerContext: partnerContext == const Object() 
          ? this.partnerContext 
          : partnerContext as MatchPartnerContext?,
      isLocalCameraOff: isLocalCameraOff ?? this.isLocalCameraOff,
      isLocalMicOff: isLocalMicOff ?? this.isLocalMicOff,
      isRemoteCameraOff: isRemoteCameraOff ?? this.isRemoteCameraOff,
      isRemoteMicOff: isRemoteMicOff ?? this.isRemoteMicOff,
      errorType: errorType ?? this.errorType,
      isRetrying: isRetrying ?? this.isRetrying,
      isGesturesEnabled: isGesturesEnabled ?? this.isGesturesEnabled,
      lastMatchDurationSeconds: lastMatchDurationSeconds ?? this.lastMatchDurationSeconds,
    );
  }

  @override
  List<Object?> get props => [
        currentPhase,
        partnerContext,
        isLocalCameraOff,
        isLocalMicOff,
        isRemoteCameraOff,
        isRemoteMicOff,
        errorType,
        isRetrying,
        isGesturesEnabled,
        lastMatchDurationSeconds,
      ];
}
