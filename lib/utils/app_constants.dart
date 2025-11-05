// lib/utils/app_constants.dart
/// Application-wide constants for better maintainability
class AppConstants {
  AppConstants._(); // Prevent instantiation

  // --- Firestore Limits ---
  /// Maximum items per Firestore query batch (Firestore limit)
  static const int firestoreBatchLimit = 30;

  /// Maximum chats to load initially
  static const int chatListInitialLimit = 30;

  // --- Sync & Cache Constants ---
  /// Duration to debounce sync triggers when new users are discovered
  static const Duration syncDebounceDuration = Duration(milliseconds: 1500);

  /// Delay before retrying user stream when document not found
  static const Duration userStreamRetryDelay = Duration(milliseconds: 1000);

  /// Maximum retry attempts for user stream
  static const int userStreamMaxRetries = 3;

  /// Interval for periodic sync checks when online
  static const Duration syncPeriodicCheckInterval = Duration(minutes: 2);

  // --- Cache Constants ---
  /// Duration for pending work count cache validity
  static const Duration pendingWorkCacheDuration = Duration(seconds: 30);

  // --- Concurrency Constants ---
  /// Maximum number of parallel batch requests to Firestore
  static const int maxConcurrentBatches = 3;

  /// Maximum number of profiles to process in parallel during sync
  static const int maxConcurrentProfileSync = 5;

  /// Maximum size of image pre-caching queue
  static const int maxImageCacheQueueSize = 20;

  /// Batch size for processing action queue items
  static const int actionQueueBatchSize = 5;

  // --- Chat List Constants ---
  /// Threshold for showing "load more" indicator in chat list
  static const int chatListLoadMoreThreshold = 30;
}
