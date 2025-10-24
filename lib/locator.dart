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
// Import NotificationRepository correctly for UserRepository
import 'package:freegram/repositories/notification_repository.dart'; // Keep (needed by UserRepository)
import 'package:freegram/services/sonar/notification_service.dart'; // Keep
import 'package:freegram/services/sonar/bluetooth_discovery_service.dart'; // Keep
import 'package:freegram/services/sonar/wave_service.dart'; // Keep
import 'package:freegram/services/sonar/sonar_controller.dart'; // Keep
import 'package:freegram/services/cache_manager_service.dart'; // Keep
import 'package:freegram/services/sync_manager.dart'; // Keep
import 'package:get_it/get_it.dart';

final GetIt locator = GetIt.instance;

void setupLocator({required ConnectivityBloc connectivityBloc}) {
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
  locator.registerLazySingleton(() => SyncManager(connectivityBloc: connectivityBloc));

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
    notificationService: locator(),
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