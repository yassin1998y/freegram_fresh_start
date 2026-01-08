import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Controller responsible for managing audio capture for voice messages.
///
/// Usage:
/// ```dart
/// final controller = VoiceRecorderController();
/// await controller.startRecording();
/// // ... update UI via the exposed ValueNotifiers
/// final path = await controller.stopRecording();
/// controller.dispose();
/// ```
class VoiceRecorderController {
  VoiceRecorderController({
    AudioRecorder? recorder,
    RecordConfig? recordConfig,
    Duration durationTick = const Duration(seconds: 1),
    Duration amplitudeInterval = const Duration(milliseconds: 120),
  })  : _recorder = recorder ?? AudioRecorder(),
        _recordConfig = recordConfig ??
            const RecordConfig(
              encoder: AudioEncoder.aacLc,
              bitRate: 128000,
              sampleRate: 44100,
            ),
        _durationTick = durationTick,
        _amplitudeInterval = amplitudeInterval;

  final AudioRecorder _recorder;
  final RecordConfig _recordConfig;
  final Duration _durationTick;
  final Duration _amplitudeInterval;

  final ValueNotifier<bool> isRecording = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPaused = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> recordingDuration =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<double> amplitude = ValueNotifier<double>(0);

  Timer? _durationTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Stream<Amplitude>? _amplitudeStream;
  String? _currentFilePath;

  /// Starts a new recording session.
  ///
  /// Returns `true` if the recorder started successfully, otherwise `false`.
  Future<bool> startRecording() async {
    if (isRecording.value) {
      return true;
    }

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      return false;
    }

    final hasRecordPermission = await _recorder.hasPermission();
    if (!hasRecordPermission) {
      return false;
    }

    final directory = await getTemporaryDirectory();
    final filename =
        'voice_${DateTime.now().millisecondsSinceEpoch}_${_randomNumber()}.m4a';
    final outputPath = p.join(directory.path, filename);

    await _recorder.start(_recordConfig, path: outputPath);

    // Verify that recording actually started
    // Wait a bit for the recorder to fully initialize
    for (int i = 0; i < 10; i++) {
      if (await _recorder.isRecording()) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Double-check that recording is actually active
    if (!await _recorder.isRecording()) {
      debugPrint('Warning: Recording did not start properly');
      return false;
    }

    _currentFilePath = outputPath;
    _resetDuration();
    _startDurationTimer();
    await _listenToAmplitude();

    isRecording.value = true;
    isPaused.value = false;
    return true;
  }

  /// Pauses an active recording session.
  Future<void> pauseRecording() async {
    if (!isRecording.value || isPaused.value) {
      return;
    }

    if (await _recorder.isRecording()) {
      await _recorder.pause();
      _stopDurationTimer();
      isPaused.value = true;
    }
  }

  /// Resumes a paused recording session.
  Future<void> resumeRecording() async {
    if (!isRecording.value || !isPaused.value) {
      return;
    }

    await _recorder.resume();
    _startDurationTimer();
    isPaused.value = false;
  }

  /// Stops recording and returns the file path of the captured audio.
  Future<String?> stopRecording() async {
    if (!isRecording.value) {
      return null;
    }

    // Stop recording and get the actual file path from the recorder
    // The recorder may return the actual path where the file was written
    final path = await _recorder.stop();
    final finalPath = path ?? _currentFilePath;

    // Debug: Log both paths to see if they differ
    if (path != null && path != _currentFilePath) {
      debugPrint(
          'Recorder returned different path: $path vs $_currentFilePath');
    }

    if (finalPath == null) {
      debugPrint(
          'Warning: Both recorder.stop() and _currentFilePath returned null');
      await _cleanupAfterRecording();
      return null;
    }

    // Don't cleanup yet - wait for file to be written first
    // MPEG4Writer writes asynchronously, so we need to wait
    // This matches the behavior of long-press which works reliably
    final file = File(finalPath);
    int? lastSize;
    int stableCount = 0;
    const int stableChecksRequired = 3; // File size must be stable for 3 checks

    // Wait for file to be written (max 10 seconds, checking every 100ms)
    // We check for file size stability to ensure it's fully written
    debugPrint('Waiting for audio file to be written: $finalPath');
    for (int i = 0; i < 100; i++) {
      if (await file.exists()) {
        try {
          final stat = await file.stat();
          if (stat.size > 0) {
            // Check if file size is stable (not changing)
            if (lastSize == stat.size) {
              stableCount++;
              if (stableCount >= stableChecksRequired) {
                // File size is stable, it's fully written
                debugPrint(
                    'Audio file is ready: $finalPath (size: ${stat.size} bytes, stable for ${stableChecksRequired} checks)');
                await _cleanupAfterRecording();
                return finalPath;
              }
            } else {
              // File size changed, reset stability counter
              stableCount = 0;
              lastSize = stat.size;
            }
          }
        } catch (e) {
          // File might be locked, wait a bit more
          debugPrint('File stat error (might be locked): $e');
        }
      } else {
        // File doesn't exist yet, log progress every second
        if (i % 10 == 0) {
          debugPrint(
              'Waiting for audio file... (${i / 10}s elapsed, path: $finalPath)');
        }
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Final check with error handling
    if (await file.exists()) {
      try {
        final stat = await file.stat();
        if (stat.size > 0) {
          debugPrint(
              'Audio file found on final check: $finalPath (size: ${stat.size} bytes)');
          await _cleanupAfterRecording();
          return finalPath;
        } else {
          debugPrint('Warning: Audio file exists but is empty: $finalPath');
        }
      } catch (e) {
        debugPrint('File stat error on final check: $e');
      }
    } else {
      debugPrint(
          'Warning: Audio file does not exist after 10 seconds: $finalPath');
    }

    // Cleanup even if file check failed
    await _cleanupAfterRecording();
    debugPrint(
        'Warning: Audio file does not exist or is empty after stop: $finalPath');
    return null;
  }

  /// Cancels the current recording and deletes the temporary file.
  Future<void> cancelRecording() async {
    if (!isRecording.value) {
      return;
    }

    await _recorder.stop();
    await _cleanupAfterRecording(deleteFile: true);
  }

  /// Releases resources. Call from `State.dispose`.
  Future<void> dispose() async {
    await _recorder.dispose();
    _stopDurationTimer();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    isRecording.dispose();
    isPaused.dispose();
    recordingDuration.dispose();
    amplitude.dispose();
  }

  Future<void> _listenToAmplitude() async {
    await _amplitudeSubscription?.cancel();
    _amplitudeStream ??=
        _recorder.onAmplitudeChanged(_amplitudeInterval).asBroadcastStream();
    _amplitudeSubscription = _amplitudeStream!
        .listen((amp) => amplitude.value = amp.current.toDouble());
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(_durationTick, (_) {
      recordingDuration.value += _durationTick;
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void _resetDuration() {
    recordingDuration.value = Duration.zero;
  }

  Future<void> _deleteTempFile() async {
    final path = _currentFilePath;
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    _currentFilePath = null;
  }

  Future<void> _cleanupAfterRecording({bool deleteFile = false}) async {
    _stopDurationTimer();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    amplitude.value = 0;
    isRecording.value = false;
    isPaused.value = false;
    if (deleteFile) {
      await _deleteTempFile();
    }
  }

  int _randomNumber() => DateTime.now().microsecondsSinceEpoch.remainder(10000);
}
