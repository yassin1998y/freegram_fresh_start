// lib/utils/auth_error_mapper.dart
import 'package:firebase_auth/firebase_auth.dart';

/// Centralized error message mapper for consistent error handling across auth methods
class AuthErrorMapper {
  AuthErrorMapper._();

  /// Map FirebaseAuthException to user-friendly message
  static String mapFirebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in method.';
      case 'ERROR_ABORTED_BY_USER':
        return 'Sign in was cancelled.';
      case 'ERROR_MISSING_TOKENS':
        return 'Failed to get authentication tokens. Please try again.';
      case 'ERROR_GOOGLE_SIGNIN_FAILED':
        return 'Google sign-in failed. Please try again.';
      case 'ERROR_FACEBOOK_LOGIN_FAILED':
        return 'Facebook sign-in failed. Please try again.';
      default:
        return error.message ?? 'An error occurred. Please try again.';
    }
  }

  /// Map generic exception to user-friendly message
  static String mapGenericError(dynamic error) {
    if (error is FirebaseAuthException) {
      return mapFirebaseError(error);
    }
    return error.toString().contains('network')
        ? 'Network error. Check your connection and try again.'
        : 'An unexpected error occurred. Please try again.';
  }
}
