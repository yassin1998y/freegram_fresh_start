import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum RandomChatStatus {
  idle,
  cameraInitializing,
  searchError,
  searching,
  matching,
  connected,
  partnerLeft
}

class RandomChatState extends Equatable {
  final RandomChatStatus status;
  final bool isBlurred;
  final bool isMicOn;
  final bool isCameraOn;
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final String? partnerId;
  final String? errorMessage;
  final String? infoMessage;
  final String? genderFilter;
  final String? regionFilter;

  const RandomChatState({
    this.status = RandomChatStatus.idle,
    this.isBlurred = true,
    this.isMicOn = true,
    this.isCameraOn = true,
    this.localStream,
    this.remoteStream,
    this.partnerId,
    this.errorMessage,
    this.infoMessage,
    this.genderFilter,
    this.regionFilter,
  });

  RandomChatState copyWith({
    RandomChatStatus? status,
    bool? isBlurred,
    bool? isMicOn,
    bool? isCameraOn,
    MediaStream? localStream,
    MediaStream? remoteStream,
    String? partnerId,
    String? errorMessage,
    String? infoMessage,
    String? genderFilter,
    String? regionFilter,
  }) {
    return RandomChatState(
      status: status ?? this.status,
      isBlurred: isBlurred ?? this.isBlurred,
      isMicOn: isMicOn ?? this.isMicOn,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      localStream: localStream ?? this.localStream,
      remoteStream: remoteStream ?? this.remoteStream,
      partnerId: partnerId ?? this.partnerId,
      errorMessage: errorMessage ?? this.errorMessage,
      infoMessage: infoMessage ?? this.infoMessage,
      genderFilter: genderFilter ?? this.genderFilter,
      regionFilter: regionFilter ?? this.regionFilter,
    );
  }

  @override
  List<Object?> get props => [
        status,
        isBlurred,
        isMicOn, // New prop
        isCameraOn, // New prop
        localStream,
        remoteStream,
        partnerId,
        errorMessage,
        infoMessage,
        genderFilter,
        regionFilter,
      ];
}
