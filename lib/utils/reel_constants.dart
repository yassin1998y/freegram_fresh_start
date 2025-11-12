// lib/utils/reel_constants.dart

/// Constants for Reel creation and display
class ReelConstants {
  ReelConstants._(); // Private constructor to prevent instantiation

  // Reel video max duration (seconds)
  static const int maxVideoDurationSeconds = 60;

  // Reel video timeout for picking (seconds)
  static const int videoPickTimeoutSeconds = 30;

  // Recording indicator sizes
  static const double recordingIndicatorWidth = 12.0;
  static const double recordingIndicatorHeight = 12.0;

  // Camera button sizes
  static const double cameraButtonSize = 70.0;
  static const double cameraButtonBorderWidth = 4.0;
  static const double cameraButtonIconSize = 40.0;

  // Upload progress indicator sizes
  static const double uploadProgressIndicatorSize = 16.0;
  static const double uploadProgressIndicatorStrokeWidth = 2.0;
}
