import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/firebase_options.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/hive/friend_request_record.dart';
import 'package:freegram/models/hive/nearby_user.dart';
import 'package:freegram/models/hive/user_profile.dart';
import 'package:freegram/models/hive/wave_record.dart';
import 'package:freegram/services/cache_manager_service.dart';
import 'package:freegram/services/device_info_helper.dart';
import 'package:freegram/services/fcm_foreground_handler.dart';
import 'package:freegram/services/fcm_navigation_service.dart';
import 'package:freegram/services/notification_action_handler.dart';
import 'package:freegram/services/professional_notification_manager.dart';
import 'package:freegram/services/sonar/notification_service.dart'
    as LocalNotificationService;
import 'package:freegram/services/gift_notification_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Service responsible for initializing all app dependencies and configurations
/// This centralizes startup logic to clean up main.dart and improve reliability
class AppInitializer {
  // Private constructor
  AppInitializer._();

  /// Initialize all app services and dependencies
  /// Returns the ConnectivityBloc needed for the root widget
  static Future<ConnectivityBloc> initialize() async {
    final stopwatch = Stopwatch()..start();
    debugPrint('🚀 AppInitializer: Starting initialization...');

    try {
      // 1. Load environment variables
      await dotenv.load(fileName: ".env");
      debugPrint('✅ AppInitializer: Environment variables loaded');

      // 2. Initialize Device Info (Critical for MIUI/Redmi fixes)
      await DeviceInfoHelper().initialize();
      debugPrint('✅ AppInitializer: Device info initialized');

      // 3. Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ AppInitializer: Firebase initialized');

      // 4. Initialize FCM (Firebase Cloud Messaging)
      await _initializeFCM();
      debugPrint('✅ AppInitializer: FCM initialized');

      // 5. Initialize Third-Party SDKs
      if (!kIsWeb) {
        await MobileAds.instance.initialize();
      }
      await LocalNotificationService.NotificationService().initialize();
      debugPrint('✅ AppInitializer: Third-party SDKs initialized');

      // 6. Initialize Hive (Local Database)
      await _initializeHive();
      debugPrint('✅ AppInitializer: Hive initialized');

      // 7. Initialize Dependency Injection & BLoCs
      final connectivityBloc = ConnectivityBloc()..add(CheckConnectivity());
      setupLocator(connectivityBloc: connectivityBloc);
      debugPrint('✅ AppInitializer: Locator and BLoCs initialized');

      // 8. Initialize Cache Manager
      if (!kIsWeb) {
        await locator<CacheManagerService>().manageCache();
      }
      debugPrint('✅ AppInitializer: Cache manager initialized');

      // 9. Initialize Gift Notification Service
      await locator<GiftNotificationService>().initialize();
      debugPrint('✅ AppInitializer: Gift notification service initialized');

      // 10. Configure System UI
      _configureSystemUI();
      debugPrint('✅ AppInitializer: System UI configured');

      stopwatch.stop();
      debugPrint(
          '🚀 AppInitializer: Initialization complete in ${stopwatch.elapsedMilliseconds}ms');

      return connectivityBloc;
    } catch (e, stackTrace) {
      debugPrint('❌ AppInitializer: Initialization failed: $e');
      debugPrint(stackTrace.toString());
      // Rethrow to let the splash screen handle the error
      rethrow;
    }
  }

  /// Initialize Firebase Cloud Messaging and Notification services
  static Future<void> _initializeFCM() async {
    // Only register background handler once to prevent duplicate isolate warnings
    // Note: The actual handler function must be a top-level function in main.dart
    // or imported from there. We assume it's already registered if we're here,
    // or main.dart handles the background callback registration.

    // In this refactor, we'll handle the registration in main.dart
    // because it requires a top-level function that might not be visible here
    // depending on imports, but we can try to register it if we import it.
    // For now, we'll assume main.dart registers the background handler
    // BEFORE calling AppInitializer, or we move the handler here.
    // Best practice: Keep background handler in main.dart or a dedicated file,
    // but registration can happen here if we import it.

    // Request permissions
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('User granted FCM permission: ${settings.authorizationStatus}');

    // Initialize Professional Notification System
    await ProfessionalNotificationManager().initialize();

    // Initialize Notification Action Handler
    await NotificationActionHandler().initialize();

    // Initialize FCM Services
    FcmNavigationService().initialize(); // Background/Terminated navigation
    FcmForegroundHandler().initialize(); // Foreground Island Popup
  }

  /// Initialize Hive database and register adapters
  static Future<void> _initializeHive() async {
    await Hive.initFlutter();

    // Register Adapters
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(NearbyUserAdapter());
    if (!Hive.isAdapterRegistered(2))
      Hive.registerAdapter(UserProfileAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(WaveRecordAdapter());
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(FriendRequestRecordAdapter());
    }

    // Open Boxes
    await Hive.openBox('settings');
    await Hive.openBox<NearbyUser>('nearbyUsers');
    await Hive.openBox<UserProfile>('userProfiles');
    await Hive.openBox<WaveRecord>('pendingWaves');
    await Hive.openBox<FriendRequestRecord>('pendingFriendRequests');
    await Hive.openBox('action_queue');
  }

  /// Configure System UI overlays and orientation
  static void _configureSystemUI() {
    // Make app full screen (hide system UI bars)
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );

    // Set preferred orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}
