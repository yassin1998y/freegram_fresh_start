// lib/locator.dart
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:freegram/blocs/connectivity_bloc.dart'; // Keep
import 'package:freegram/repositories/action_queue_repository.dart'; // Keep
import 'package:freegram/repositories/auth_repository.dart'; // Keep
import 'package:freegram/repositories/chat_repository.dart'; // Keep
// import 'package:freegram/repositories/gamification_repository.dart'; // Remove
// import 'package:freegram/repositories/game_repository.dart'; // Remove
// import 'package:freegram/repositories/inventory_repository.dart'; // Remove
import 'package:freegram/repositories/notification_repository.dart'; // Keep
import 'package:freegram/repositories/post_repository.dart'; // Social Feed
import 'package:freegram/repositories/page_repository.dart'; // Pages & Admin System
import 'package:freegram/repositories/post_template_repository.dart'; // Post Templates
import 'package:freegram/repositories/report_repository.dart'; // Reporting & Moderation
import 'package:freegram/repositories/feature_guide_repository.dart'; // Feature Discovery
import 'package:freegram/repositories/store_repository.dart'; // Keep
import 'package:freegram/repositories/story_repository.dart'; // Stories Feature
// import 'package:freegram/repositories/task_repository.dart'; // Remove
import 'package:freegram/repositories/user_repository.dart'; // Keep
import 'package:freegram/repositories/friend_repository.dart';
import 'package:freegram/repositories/gift_repository.dart'; // Gamification
import 'package:freegram/repositories/profile_repository.dart'; // Gamification
import 'package:freegram/repositories/marketplace_repository.dart';
import 'package:freegram/services/daily_reward_service.dart'; // Gamification
import 'package:freegram/repositories/achievement_repository.dart'; // Gamification
import 'package:freegram/repositories/analytics_repository.dart'; // Gamification
import 'package:freegram/services/referral_service.dart'; // Gamification

import 'package:freegram/repositories/user_discovery_repository.dart';
import 'package:freegram/services/sonar/local_cache_service.dart'; // Keep
import 'package:freegram/services/sonar/notification_service.dart'; // Keep
import 'package:freegram/services/sonar/bluetooth_discovery_service.dart'; // Keep
import 'package:freegram/services/sonar/wave_service.dart'; // Keep
import 'package:freegram/services/sonar/sonar_controller.dart'; // Keep
import 'package:freegram/services/cache_manager_service.dart'; // Keep
import 'package:freegram/services/sync_manager.dart'; // Keep
import 'package:freegram/services/network_quality_service.dart'; // Chat improvements
import 'package:freegram/services/media_prefetch_service.dart';
// Note: IntelligentPrefetchService is initialized manually in MainScreenWrapper
// after SharedPreferences is ready, so we don't import it here
import 'package:freegram/services/friend_cache_service.dart'; // Friends caching
import 'package:freegram/services/feed_cache_service.dart'; // Feed caching for offline
import 'package:freegram/services/friend_request_rate_limiter.dart'; // Rate limiting
import 'package:freegram/services/friend_action_retry_service.dart'; // Offline retry
import 'package:freegram/services/fcm_token_service.dart'; // FCM push notifications
import 'package:freegram/services/presence_manager.dart'; // Presence/online status
import 'package:freegram/services/navigation_service.dart'; // Professional navigation
import 'package:freegram/services/loading_overlay_service.dart'; // Loading overlays
import 'package:freegram/services/page_analytics_service.dart'; // Page Analytics
import 'package:freegram/services/hashtag_service.dart'; // Hashtag System
import 'package:freegram/services/mention_service.dart'; // Mention System
import 'package:freegram/services/moderation_service.dart'; // Moderation System
import 'package:freegram/repositories/search_repository.dart'; // Search & Discovery
import 'package:freegram/repositories/reel_repository.dart'; // Reels Feature
import 'package:freegram/services/ad_service.dart'; // Ad Service
import 'package:freegram/services/gallery_service.dart'; // Gallery Service for Stories
import 'package:freegram/services/reel_upload_manager.dart'; // Reel Upload Manager
import 'package:freegram/services/draft_persistence_service.dart'; // Draft Persistence
import 'package:freegram/services/gift_notification_service.dart'; // Gift Notifications
import 'package:get_it/get_it.dart';

final GetIt locator = GetIt.instance;

void setupLocator({required ConnectivityBloc connectivityBloc}) {
  // Guard: If already registered, skip re-registration (e.g., during hot reload)
  if (locator.isRegistered<ConnectivityBloc>()) {
    return;
  }

  // --- Register ConnectivityBloc first ---
  locator.registerLazySingleton<ConnectivityBloc>(() => connectivityBloc);

  // Debug logging
  debugPrint("setupLocator: Registering PresenceManager...");
  locator.registerLazySingleton(() => PresenceManager());

  // --- Register Core Repositories ---
  locator.registerLazySingleton(() => AuthRepository());
  locator.registerLazySingleton(() => NotificationRepository()); // Keep
  locator.registerLazySingleton(() => StoreRepository()); // Keep
  locator.registerLazySingleton(() => ActionQueueRepository()); // Keep
  // PostRepository now depends on HashtagService and MentionService, so register them first
  locator.registerLazySingleton(() => HashtagService());
  locator.registerLazySingleton(() => MentionService(
        userRepository: locator<UserRepository>(),
      ));
  locator.registerLazySingleton(() => PostRepository()); // Social Feed
  locator.registerLazySingleton(() => PageRepository()); // Pages & Admin System
  locator
      .registerLazySingleton(() => PostTemplateRepository()); // Post Templates
  locator.registerLazySingleton(
      () => ReportRepository()); // Reporting & Moderation
  locator.registerLazySingleton(
      () => FeatureGuideRepository()); // Feature Discovery
  locator.registerLazySingleton(() => SearchRepository()); // Search & Discovery
  locator.registerLazySingleton(() => StoryRepository()); // Stories Feature
  locator.registerLazySingleton(() => ReelRepository()); // Reels Feature
  locator.registerLazySingleton(() => GiftRepository()); // Gamification - Gifts
  locator.registerLazySingleton(
      () => ProfileRepository()); // Gamification - Profile
  locator.registerLazySingleton(
      () => MarketplaceRepository()); // Gamification - Marketplace
  locator.registerLazySingleton(
      () => DailyRewardService()); // Gamification - Daily Rewards
  locator.registerLazySingleton(
      () => AchievementRepository()); // Gamification - Achievements
  locator.registerLazySingleton(
      () => ReferralService()); // Gamification - Referrals
  locator.registerLazySingleton(
      () => AnalyticsRepository()); // Gamification - Analytics
  locator.registerLazySingleton(
      () => GiftNotificationService()); // Gift Notifications

  // --- Register Repositories with Dependencies ---
  // UserRepository: Remove GamificationRepository dependency, keep NotificationRepository
  locator.registerLazySingleton(() => UserRepository(
        notificationRepository: locator<NotificationRepository>(),
        // gamificationRepository: locator<GamificationRepository>(), // Removed
      ));

  // FriendRepository
  locator.registerLazySingleton(() => FriendRepository(
        notificationRepository: locator<NotificationRepository>(),
        userRepository: locator<UserRepository>(),
      ));

  locator.registerLazySingleton<UserDiscoveryRepository>(
      () => UserDiscoveryRepository());
  // ChatRepository: Remove GamificationRepository and TaskRepository dependencies
  locator.registerLazySingleton(() => ChatRepository(
      // gamificationRepository: locator<GamificationRepository>(), // Removed
      // taskRepository: locator<TaskRepository>(), // Removed
      ));

  // --- Register Core Services ---
  locator.registerLazySingleton(() => CacheManagerService());

  // Network Quality Service - Register as singleton (it uses factory pattern internally)
  locator.registerLazySingleton<NetworkQualityService>(
      () => NetworkQualityService());

  // Media Prefetch Service - Prefetches videos/images for better performance
  locator.registerLazySingleton(() => MediaPrefetchService(
        networkService: locator<
            NetworkQualityService>(), // Use GetIt instead of direct instantiation
        cacheService: locator<CacheManagerService>(),
      ));
  if (!kIsWeb) {
    locator.registerLazySingleton(
        () => SyncManager(connectivityBloc: connectivityBloc));
  }

  // Navigation and Loading Services
  locator.registerLazySingleton(() => NavigationService());
  locator.registerLazySingleton(() => LoadingOverlayService());

  // Friend Cache Service
  locator.registerLazySingleton(() => FriendCacheService());

  // Feed Cache Service
  locator.registerLazySingleton(() => FeedCacheService());

  // Friend Request Rate Limiter
  locator.registerLazySingleton(() => FriendRequestRateLimiter());

  // ⭐ PHASE 5: RETRY SERVICE - Auto-retry failed friend actions
  locator.registerLazySingleton(() => FriendActionRetryService(
        friendRepository: locator<FriendRepository>(),
        actionQueue: locator<ActionQueueRepository>(),
      ));

  // FCM Token Service - Push Notifications
  locator.registerLazySingleton(() => FcmTokenService());

  // Page Analytics Service
  locator.registerLazySingleton(() => PageAnalyticsService());

  // Ad Service
  locator.registerLazySingleton(() => AdService());

  // Moderation Service
  locator.registerLazySingleton(() => ModerationService());

  // Gallery Service
  locator.registerLazySingleton(() => GalleryService());

  // Reel Upload Services
  locator.registerLazySingleton(() => ReelUploadManager());
  locator.registerLazySingleton(() => DraftPersistenceService());

  // Phase 1.3: Intelligent Prefetch Service
  // Note: This service is initialized manually in MainScreenWrapper
  // after SharedPreferences is ready, so we don't register it here

  // Initialize Services
  locator<NetworkQualityService>()
      .init(); // Use GetIt instead of direct instantiation
  locator<FriendCacheService>().init();
  locator<FriendRequestRateLimiter>().init();
  locator<FriendActionRetryService>().initialize();
  // Note: PresenceManager.initialize() called in main.dart after auth

  // --- Register SONAR Services (Condition for Non-Web) ---
  if (!kIsWeb) {
    locator.registerLazySingleton(() => LocalCacheService());
    locator.registerLazySingleton(() => NotificationService());

    // BluetoothDiscoveryService
    locator.registerLazySingleton(() => BluetoothDiscoveryService(
          cacheService: locator(),
          // BleAdvertiser and BleScanner are instantiated internally
        ));
    // WaveService
    locator.registerLazySingleton(() => WaveService(
          discoveryService: locator(),
          cacheService: locator(),
          notificationService: locator(),
        ));
    // SonarController registration (Keep UserRepository dependency)
    locator.registerLazySingleton(() => SonarController(
          discoveryService: locator(),
          cacheService: locator(),
          waveService: locator(),
          syncManager: locator(),
          connectivityBloc: connectivityBloc,
          userRepository: locator(), // Keep this dependency
        ));
  }

  // --- Remove registrations for deleted repositories ---
  // locator.registerLazySingleton(() => GamificationRepository());
  // locator.registerLazySingleton(() => StoryRepository());
  // locator.registerLazySingleton(() => InventoryRepository());
  // locator.registerLazySingleton(() => GameRepository());
  // locator.registerLazySingleton(() => PostRepository(...));
  // locator.registerLazySingleton(() => TaskRepository(...));
}
