import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

class AppLogger {
  static void log(String message,
      {String name = 'AppLogger', Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      developer.log(
        message,
        name: name,
        error: error,
        stackTrace: stackTrace,
        time: DateTime.now(),
      );
    }
  }

  static void debug(String message) => log(message, name: 'DEBUG');
  static void info(String message) => log(message, name: 'INFO');
  static void warning(String message) => log(message, name: 'WARNING');
  static void error(String message, [Object? error, StackTrace? stackTrace]) =>
      log(message, name: 'ERROR', error: error, stackTrace: stackTrace);
}
