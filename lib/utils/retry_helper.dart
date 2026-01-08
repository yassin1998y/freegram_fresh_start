import 'package:flutter/foundation.dart';

/// Helper class for retry logic with exponential backoff
class RetryHelper {
  /// Execute a function with retry logic and exponential backoff
  ///
  /// [operation] - The async operation to retry
  /// [maxAttempts] - Maximum number of retry attempts (default: 3)
  /// [initialDelay] - Initial delay in milliseconds (default: 500ms)
  /// [maxDelay] - Maximum delay in milliseconds (default: 5000ms)
  /// [onRetry] - Optional callback called before each retry
  static Future<T> executeWithRetry<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    int initialDelay = 500,
    int maxDelay = 5000,
    void Function(int attempt, Object error)? onRetry,
  }) async {
    int attempt = 0;
    int delay = initialDelay;

    while (true) {
      attempt++;

      try {
        return await operation();
      } catch (e) {
        if (attempt >= maxAttempts) {
          debugPrint(
              'RetryHelper: Max attempts ($maxAttempts) reached. Giving up.');
          rethrow;
        }

        debugPrint('RetryHelper: Attempt $attempt failed: $e');
        debugPrint('RetryHelper: Retrying in ${delay}ms...');

        onRetry?.call(attempt, e);

        await Future.delayed(Duration(milliseconds: delay));

        // Exponential backoff with max delay cap
        delay = (delay * 2).clamp(initialDelay, maxDelay);
      }
    }
  }

  /// Execute with retry for network operations
  static Future<T> executeNetworkOperation<T>({
    required Future<T> Function() operation,
    void Function(int attempt, Object error)? onRetry,
  }) {
    return executeWithRetry(
      operation: operation,
      maxAttempts: 3,
      initialDelay: 1000,
      maxDelay: 5000,
      onRetry: onRetry,
    );
  }

  /// Execute with retry for Firestore operations
  static Future<T> executeFirestoreOperation<T>({
    required Future<T> Function() operation,
    void Function(int attempt, Object error)? onRetry,
  }) {
    return executeWithRetry(
      operation: operation,
      maxAttempts: 2,
      initialDelay: 500,
      maxDelay: 2000,
      onRetry: onRetry,
    );
  }

  /// Check if error is retryable
  static bool isRetryableError(Object error) {
    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket')) {
      return true;
    }

    // Firestore errors
    if (errorString.contains('unavailable') ||
        errorString.contains('deadline-exceeded') ||
        errorString.contains('resource-exhausted')) {
      return true;
    }

    return false;
  }

  /// Get user-friendly error message
  static String getUserFriendlyMessage(Object error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network connection issue. Please check your internet.';
    }

    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (errorString.contains('permission') || errorString.contains('denied')) {
      return 'Permission denied. Please contact support.';
    }

    if (errorString.contains('not found')) {
      return 'Item not found. It may have been deleted.';
    }

    if (errorString.contains('insufficient')) {
      return 'Insufficient balance. Please add more coins.';
    }

    if (errorString.contains('already')) {
      return 'This action has already been completed.';
    }

    // Generic fallback
    return 'Something went wrong. Please try again.';
  }
}
