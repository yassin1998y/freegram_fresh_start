// lib/locator.dart
import 'package:freegram/blocs/connectivity_bloc.dart'; // Keep
import 'package:freegram/repositories/action_queue_repository.dart'; // Keep
import 'package:freegram/repositories/auth_repository.dart'; // Keep
import 'package:freegram/repositories/chat_repository.dart'; // Keep
// import 'package:freegram/repositories/gamification_repository.dart'; // Remove
// import 'package:freegram/repositories/game_repository.dart'; // Remove
// import 'package:freegram/repositories/inventory_repository.dart'; // Remove
import 'package:freegram/repositories/notification_repository.dart'; // Keep
// import 'package:freegram/repositories/post_repository.dart'; // Remove
import 'package:freegram/repositories/store_repository.dart'; // Keep
// import 'package:freegram/repositories/story_repository.dart'; // Remove
// import 'package:freegram/repositories/task_repository.dart'; // Remove
import 'package:freegram/repositories/user_repository.dart'; // Keep
import 'package:freegram/services/sonar/local_cache_service.dart'; // Keep
import 'package:freegram/services/sonar/notification_service.dart'; // Keep
import 'package:freegram/services/sonar/bluetooth_discovery_service.dart'; // Keep
import 'package:freegram/services/sonar/wave_service.dart'; // Keep
import 'package:freegram/services/sonar/sonar_controller.dart'; // Keep
import 'package:freegram/services/cache_manager_service.dart'; // Keep
import 'package:freegram/services/sync_manager.dart'; // Keep
import 'package:freegram/services/network_quality_service.dart'; // Chat improvements
import 'package:freegram/services/friend_cache_service.dart'; // Friends caching
import 'package:freegram/services/friend_request_rate_limiter.dart'; // Rate limiting
import 'package:freegram/services/friend_action_retry_service.dart'; // Offline retry
import 'package:freegram/services/fcm_token_service.dart'; // FCM push notifications
import 'package:freegram/services/presence_manager.dart'; // Presence/online status
import 'package:freegram/services/navigation_service.dart'; // Professional navigation
import 'package:freegram/services/loading_overlay_service.dart'; // Loading overlays
import 'package:get_it/get_it.dart';

final GetIt locator = GetIt.instance;

void setupLocator({required ConnectivityBloc connectivityBloc}) {
  // --- Register ConnectivityBloc first ---
  locator.registerLazySingleton<ConnectivityBloc>(() => connectivityBloc);

  // --- Register Core Repositories ---
  locator.registerLazySingleton(() => AuthRepository());
  locator.registerLazySingleton(() => NotificationRepository()); // Keep
  locator.registerLazySingleton(() => StoreRepository()); // Keep
  locator.registerLazySingleton(() => ActionQueueRepository()); // Keep

  // --- Register Repositories with Dependencies ---
  // UserRepository: Remove GamificationRepository dependency, keep NotificationRepository
  locator.registerLazySingleton(() => UserRepository(
        notificationRepository: locator<NotificationRepository>(),
        // gamificationRepository: locator<GamificationRepository>(), // Removed
      ));
  // ChatRepository: Remove GamificationRepository and TaskRepository dependencies
  locator.registerLazySingleton(() => ChatRepository(
      // gamificationRepository: locator<GamificationRepository>(), // Removed
      // taskRepository: locator<TaskRepository>(), // Removed
      ));

  // --- Register Core Services ---
  locator.registerLazySingleton(() => CacheManagerService());
  locator.registerLazySingleton(
      () => SyncManager(connectivityBloc: connectivityBloc));

  // Navigation and Loading Services
  locator.registerLazySingleton(() => NavigationService());
  locator.registerLazySingleton(() => LoadingOverlayService());

  // Friend Cache Service
  locator.registerLazySingleton(() => FriendCacheService());

  // Friend Request Rate Limiter
  locator.registerLazySingleton(() => FriendRequestRateLimiter());

  // ⭐ PHASE 5: RETRY SERVICE - Auto-retry failed friend actions
  locator.registerLazySingleton(() => FriendActionRetryService(
        userRepository: locator<UserRepository>(),
        actionQueue: locator<ActionQueueRepository>(),
      ));

  // FCM Token Service - Push Notifications
  locator.registerLazySingleton(() => FcmTokenService());

  // Presence Manager - Online status and last seen
  locator.registerLazySingleton(() => PresenceManager());

  // Initialize Services
  NetworkQualityService().init();
  locator<FriendCacheService>().init();
  locator<FriendRequestRateLimiter>().init();
  locator<FriendActionRetryService>().initialize();
  // Note: PresenceManager.initialize() called in main.dart after auth

  // --- Register SONAR Services (Corrected Order/Dependencies) ---
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

  // --- Remove registrations for deleted repositories ---
  // locator.registerLazySingleton(() => GamificationRepository());
  // locator.registerLazySingleton(() => StoryRepository());
  // locator.registerLazySingleton(() => InventoryRepository());
  // locator.registerLazySingleton(() => GameRepository());
  // locator.registerLazySingleton(() => PostRepository(...));
  // locator.registerLazySingleton(() => TaskRepository(...));
}
