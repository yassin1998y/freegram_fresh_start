import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utility class for handling Firestore errors with retry logic and user-friendly messages.
class FirestoreErrorHandler {
  /// Maximum number of retry attempts for transient errors
  static const int maxRetries = 3;

  /// Delay between retry attempts (exponential backoff)
  static const Duration initialRetryDelay = Duration(milliseconds: 500);

  /// Executes a Firestore operation with automatic retry logic for transient errors.
  ///
  /// Retries operations that fail due to:
  /// - Network issues (unavailable, deadline-exceeded)
  /// - Resource exhaustion
  /// - Internal server errors
  ///
  /// Does NOT retry:
  /// - Permission errors
  /// - Not found errors
  /// - Invalid argument errors
  /// - Aborted transactions (should be retried at higher level)
  static Future<T> executeWithRetry<T>({
    required Future<T> Function() operation,
    String? operationName,
    int maxAttempts = maxRetries,
  }) async {
    int attempt = 0;
    Duration delay = initialRetryDelay;

    while (true) {
      attempt++;
      try {
        return await operation();
      } on FirebaseException catch (e) {
        final shouldRetry = _isTransientError(e) && attempt < maxAttempts;

        if (kDebugMode) {
          debugPrint(
              '[FirestoreErrorHandler] ${operationName ?? 'Operation'} failed (attempt $attempt/$maxAttempts): ${e.code} - ${e.message}');
        }

        if (!shouldRetry) {
          // Convert to user-friendly error message
          throw Exception(getUserFriendlyMessage(e, operationName));
        }

        // Exponential backoff: 500ms, 1s, 2s
        if (kDebugMode) {
          debugPrint(
              '[FirestoreErrorHandler] Retrying in ${delay.inMilliseconds}ms...');
        }
        await Future.delayed(delay);
        delay *= 2;
      } catch (e) {
        // Non-Firestore errors - don't retry
        if (kDebugMode) {
          debugPrint(
              '[FirestoreErrorHandler] ${operationName ?? 'Operation'} failed with non-Firestore error: $e');
        }
        rethrow;
      }
    }
  }

  /// Determines if a Firestore error is transient and should be retried.
  static bool _isTransientError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'resource-exhausted':
      case 'internal':
      case 'unknown':
        return true;
      case 'aborted': // Transaction conflicts - should be retried at transaction level
      case 'permission-denied':
      case 'not-found':
      case 'already-exists':
      case 'invalid-argument':
      case 'failed-precondition':
      case 'out-of-range':
      case 'unimplemented':
      case 'data-loss':
      case 'unauthenticated':
        return false;
      default:
        return false;
    }
  }

  /// Converts Firestore errors to user-friendly messages.
  static String getUserFriendlyMessage(
      FirebaseException error, String? operationName) {
    final operation = operationName ?? 'operation';

    switch (error.code) {
      case 'permission-denied':
        return 'You don\'t have permission to perform this action. Please check your account settings.';
      case 'not-found':
        return 'The requested data could not be found. It may have been deleted.';
      case 'already-exists':
        return 'This $operation already exists. Please try a different action.';
      case 'invalid-argument':
        return 'Invalid data provided. Please check your input and try again.';
      case 'failed-precondition':
        return 'This action cannot be completed right now. Please try again later.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please check your internet connection and try again.';
      case 'deadline-exceeded':
        return 'The request took too long. Please try again.';
      case 'resource-exhausted':
        return 'Too many requests. Please wait a moment and try again.';
      case 'unauthenticated':
        return 'You need to be logged in to perform this action.';
      case 'aborted':
        return 'The operation was interrupted. Please try again.';
      case 'out-of-range':
        return 'The provided value is out of acceptable range.';
      case 'unimplemented':
        return 'This feature is not yet available.';
      case 'internal':
        return 'An internal error occurred. Please try again later.';
      case 'data-loss':
        return 'Data corruption detected. Please contact support.';
      case 'unknown':
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Provides detailed error context for debugging.
  static String getDetailedErrorMessage(FirebaseException error) {
    return 'Firestore Error [${error.code}]: ${error.message}\n'
        'Plugin: ${error.plugin}\n'
        'Stack trace: ${error.stackTrace}';
  }
}

/// Common error messages for specific operations
class ErrorMessages {
  // Friend operations
  static const String friendRequestAlreadySent =
      'You have already sent a friend request to this user.';
  static const String alreadyFriends =
      'You are already friends with this user.';
  static const String userBlocked = 'You have blocked this user.';
  static const String blockedByUser = 'This user has blocked you.';
  static const String friendRequestNotFound =
      'No pending friend request found.';
  static const String notFriends = 'You are not friends with this user.';
  static const String cannotAddSelf =
      'You cannot send a friend request to yourself.';
  static const String userNotFound =
      'User not found. They may have deleted their account.';

  // Match operations
  static const String noSuperLikes =
      'You have no Super Likes left. Watch an ad or visit the store.';
  static const String alreadyMatched =
      'You have already matched with this user.';
  static const String matchNotFound = 'Match not found.';

  // Chat operations
  static const String chatNotFound =
      'Chat not found. It may have been deleted.';
  static const String messageNotFound =
      'Message not found. It may have been deleted.';
  static const String cannotSendMessage =
      'You cannot send more than two messages until they reply or accept.';
  static const String mustAcceptFirst =
      'You cannot reply until you accept the friend request.';
  static const String voiceMessageOffline =
      'Cannot send voice messages while offline.';

  // General
  static const String networkError =
      'Network error. Please check your connection and try again.';
  static const String unknownError =
      'An unexpected error occurred. Please try again.';
}
