// lib/models/audio_segment_model.dart

import 'package:equatable/equatable.dart';

class AudioSegment extends Equatable {
  final String audioFilePath;
  final double startTime; // in seconds
  final double endTime; // in seconds
  final double duration; // calculated: endTime - startTime

  const AudioSegment({
    required this.audioFilePath,
    required this.startTime,
    required this.endTime,
  }) : duration = endTime - startTime;

  AudioSegment copyWith({
    String? audioFilePath,
    double? startTime,
    double? endTime,
  }) {
    return AudioSegment(
      audioFilePath: audioFilePath ?? this.audioFilePath,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  List<Object?> get props => [audioFilePath, startTime, endTime, duration];
}

