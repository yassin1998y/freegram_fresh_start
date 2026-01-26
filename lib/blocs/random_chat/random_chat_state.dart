import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum RandomChatStatus { initial, idle, searching, connected }

class RandomChatState extends Equatable {
  final RandomChatStatus status;
  final bool isBlurred;
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final String? partnerId;
  final String? errorMessage;

  const RandomChatState({
    this.status = RandomChatStatus.initial,
    this.isBlurred = true,
    this.localStream,
    this.remoteStream,
    this.partnerId,
    this.errorMessage,
  });

  RandomChatState copyWith({
    RandomChatStatus? status,
    bool? isBlurred,
    MediaStream? localStream,
    MediaStream? remoteStream,
    String? partnerId,
    String? errorMessage,
  }) {
    return RandomChatState(
      status: status ?? this.status,
      isBlurred: isBlurred ?? this.isBlurred,
      localStream: localStream ?? this.localStream,
      remoteStream: remoteStream ?? this.remoteStream,
      partnerId: partnerId ?? this.partnerId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        isBlurred,
        localStream,
        remoteStream,
        partnerId,
        errorMessage,
      ];
}
