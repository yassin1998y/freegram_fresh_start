import 'package:equatable/equatable.dart';
import 'package:freegram/screens/random_chat/models/match_partner_context.dart';

enum RandomChatPhase { idle, searching, matching, connected }

class RandomChatState extends Equatable {
  final RandomChatPhase currentPhase;
  final MatchPartnerContext? partnerContext;
  final bool isLocalCameraOff;
  final bool isLocalMicOff;
  final bool isRemoteCameraOff;
  final bool isRemoteMicOff;
  final String? errorMessage;

  const RandomChatState({
    this.currentPhase = RandomChatPhase.idle,
    this.partnerContext,
    this.isLocalCameraOff = false,
    this.isLocalMicOff = false,
    this.isRemoteCameraOff = false,
    this.isRemoteMicOff = false,
    this.errorMessage,
  });

  RandomChatState copyWith({
    RandomChatPhase? currentPhase,
    MatchPartnerContext? partnerContext,
    bool? isLocalCameraOff,
    bool? isLocalMicOff,
    bool? isRemoteCameraOff,
    bool? isRemoteMicOff,
    String? errorMessage,
  }) {
    return RandomChatState(
      currentPhase: currentPhase ?? this.currentPhase,
      partnerContext: partnerContext ?? this.partnerContext,
      isLocalCameraOff: isLocalCameraOff ?? this.isLocalCameraOff,
      isLocalMicOff: isLocalMicOff ?? this.isLocalMicOff,
      isRemoteCameraOff: isRemoteCameraOff ?? this.isRemoteCameraOff,
      isRemoteMicOff: isRemoteMicOff ?? this.isRemoteMicOff,
      errorMessage: errorMessage ?? this.errorMessage,
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
        errorMessage,
      ];
}
