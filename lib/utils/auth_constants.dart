// lib/utils/auth_constants.dart
/// Constants for authentication system
class AuthConstants {
  AuthConstants._();

  // Timeout and delay constants
  static const Duration signOutMinimumDisplayDuration =
      Duration(milliseconds: 800);
  static const Duration documentCreationRetryDelay =
      Duration(milliseconds: 100);
  static const int documentCreationMaxRetries = 10;

  // Hive keys patterns
  static const String onboardingCompletePrefix = 'onboardingComplete_';
  static const String profileCompletePrefix = 'profileComplete_';
  static const String hasCheckedPrefix = 'hasChecked_';
  static const String userPrefix = 'user_';

  // Standard onboarding key
  static String getOnboardingKey(String userId) =>
      '${onboardingCompletePrefix}$userId';
}
