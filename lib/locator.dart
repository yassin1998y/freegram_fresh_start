// lib/locator.dart
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/repositories/action_queue_repository.dart';
import 'package:freegram/repositories/auth_repository.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/repositories/gamification_repository.dart';
import 'package:freegram/repositories/game_repository.dart';
import 'package:freegram/repositories/inventory_repository.dart';
import 'package:freegram/repositories/notification_repository.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/store_repository.dart';
import 'package:freegram/repositories/story_repository.dart';
import 'package:freegram/repositories/task_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/services/sonar/local_cache_service.dart';
import 'package:freegram/services/sonar/notification_service.dart';
import 'package:freegram/services/sonar/bluetooth_discovery_service.dart';
import 'package:freegram/services/sonar/wave_service.dart';
import 'package:freegram/services/sonar/sonar_controller.dart';
import 'package:freegram/services/cache_manager_service.dart';
import 'package:freegram/services/sync_manager.dart';
import 'package:get_it/get_it.dart';

final GetIt locator = GetIt.instance;

void setupLocator({required ConnectivityBloc connectivityBloc}) {
  // --- Register Existing Repositories ---
  locator.registerLazySingleton(() => AuthRepository());
  locator.registerLazySingleton(() => GamificationRepository());
  locator.registerLazySingleton(() => NotificationRepository());
  locator.registerLazySingleton(() => StoreRepository());
  locator.registerLazySingleton(() => StoryRepository());
  locator.registerLazySingleton(() => InventoryRepository());
  locator.registerLazySingleton(() => GameRepository());
  locator.registerLazySingleton(() => ActionQueueRepository());
  locator.registerLazySingleton(() => TaskRepository(
        gamificationRepository: locator<GamificationRepository>(),
      ));
  locator.registerLazySingleton(() => UserRepository(
        notificationRepository: locator<NotificationRepository>(),
        gamificationRepository: locator<GamificationRepository>(),
      ));
  locator.registerLazySingleton(() => ChatRepository(
        gamificationRepository: locator<GamificationRepository>(),
        taskRepository: locator<TaskRepository>(),
      ));
  locator.registerLazySingleton(() => PostRepository(
        userRepository: locator<UserRepository>(),
        gamificationRepository: locator<GamificationRepository>(),
        taskRepository: locator<TaskRepository>(),
        notificationRepository: locator<NotificationRepository>(),
      ));

  // --- Register Existing Services ---
  locator.registerLazySingleton(() => CacheManagerService());
  locator.registerLazySingleton(() => SyncManager(connectivityBloc: connectivityBloc));

  // --- ADD NEW SONAR SERVICE REGISTRATIONS (Corrected Order/Dependencies) ---
  locator.registerLazySingleton(() => LocalCacheService());
  locator.registerLazySingleton(() => NotificationService());

  // BluetoothDiscoveryService no longer needs WaveService passed in constructor
  locator.registerLazySingleton(() => BluetoothDiscoveryService(
      cacheService: locator(),
      // BleAdvertiser and BleScanner are instantiated internally
  ));
  // WaveService can now safely depend on BluetoothDiscoveryService
  locator.registerLazySingleton(() => WaveService(
      discoveryService: locator(),
      cacheService: locator(),
      notificationService: locator(),
  ));
  // SonarController registration
  locator.registerLazySingleton(() => SonarController(
      discoveryService: locator(),
      cacheService: locator(),
      waveService: locator(),
      notificationService: locator(),
      syncManager: locator(),
      connectivityBloc: connectivityBloc,
      userRepository: locator(),
  ));
}
