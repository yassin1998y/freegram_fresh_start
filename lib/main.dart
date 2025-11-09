// lib/main.dart
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/firebase_options.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/fcm_navigation_service.dart';
import 'package:freegram/services/fcm_foreground_handler.dart';
import 'package:freegram/services/professional_notification_manager.dart';
import 'package:freegram/services/notification_action_handler.dart';
import 'package:freegram/services/navigation_service.dart';
// Hive Models
import 'package:freegram/models/hive/nearby_user.dart';
import 'package:freegram/models/hive/user_profile.dart';
import 'package:freegram/models/hive/wave_record.dart';
import 'package:freegram/models/hive/friend_request_record.dart';
// Other Models
import 'package:freegram/models/user_model.dart';
// Repositories
import 'package:freegram/repositories/auth_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
// Screens
import 'package:freegram/screens/login_screen.dart';
import 'package:freegram/screens/signup_screen.dart';
import 'package:freegram/screens/main_screen.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/screens/multi_step_onboarding_screen.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/screens/improved_chat_screen.dart';
import 'package:freegram/screens/settings_screen.dart';
import 'package:freegram/screens/store_screen.dart';
import 'package:freegram/screens/reels_feed_screen.dart';
import 'package:freegram/screens/create_reel_screen.dart';
import 'package:freegram/navigation/app_routes.dart';
import 'package:freegram/utils/auth_constants.dart';
// Services
import 'package:freegram/services/cache_manager_service.dart';
import 'package:freegram/services/presence_manager.dart'; // <<<--- Presence/online status
import 'package:freegram/services/sonar/notification_service.dart'
    as LocalNotificationService;
import 'package:freegram/services/sonar/sonar_controller.dart'; // <<<--- Added for MainScreenWrapper
import 'package:freegram/services/sync_manager.dart'; // <<<--- Added for MainScreenWrapper
import 'package:freegram/services/sonar/bluetooth_service.dart'; // <<<--- Added for MainScreenWrapper (StatusService)
import 'package:freegram/services/loading_overlay_service.dart'; // <<<--- Added for overlay cleanup
// MIUI/Redmi Fixes
import 'package:freegram/services/device_info_helper.dart';
// Other Imports
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:freegram/theme/app_theme.dart';
// Phase 1.3: Background Prefetch
// NOTE: Temporarily disabled due to workmanager compatibility issues with Flutter Android embedding
// import 'package:workmanager/workmanager.dart';
// import 'package:freegram/services/intelligent_prefetch_service.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// --- START: Firebase Messaging Background Handler ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background isolate
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('[FCM Background] Message: ${message.messageId}');
  debugPrint('[FCM Background] Type: ${message.data['type']}');

  // Initialize ProfessionalNotificationManager for rich notifications
  final proNotificationManager = ProfessionalNotificationManager();
  await proNotificationManager.initialize();

  // Initialize NotificationActionHandler for action buttons
  // Note: This is lightweight initialization, main init happens in app startup

  // Handle different notification types with rich local notifications
  final type = message.data['type'] ?? '';

  switch (type) {
    case 'newMessage':
      final chatId = message.data['chatId'] ?? '';
      final senderId = message.data['senderId'] ?? '';
      final senderUsername = message.data['senderUsername'] ?? 'User';
      final senderPhotoUrl = message.data['senderPhotoUrl'] ?? '';
      final messageText = message.data['messageText'] ?? '';
      final messageCount =
          int.tryParse(message.data['messageCount'] ?? '1') ?? 1;
      final messagesJson = message.data['messages'] ?? '[]';

      List<String> messages = [];
      try {
        messages = List<String>.from(jsonDecode(messagesJson));
      } catch (e) {
        messages = [messageText];
      }

      await proNotificationManager.showBackgroundMessageNotification(
        chatId: chatId,
        senderId: senderId,
        senderUsername: senderUsername,
        senderPhotoUrl: senderPhotoUrl,
        messageText: messageText,
        messageCount: messageCount,
        messages: messages,
      );
      break;

    case 'friendRequest':
      final fromUserId = message.data['fromUserId'] ?? '';
      final fromUsername = message.data['fromUsername'] ?? 'User';
      final fromPhotoUrl = message.data['fromPhotoUrl'] ?? '';

      await proNotificationManager.showBackgroundFriendRequestNotification(
        fromUserId: fromUserId,
        fromUsername: fromUsername,
        fromPhotoUrl: fromPhotoUrl,
      );
      break;

    case 'requestAccepted':
      final fromUserId = message.data['fromUserId'] ?? '';
      final fromUsername = message.data['fromUsername'] ?? 'User';
      final fromPhotoUrl = message.data['fromPhotoUrl'] ?? '';

      await proNotificationManager.showBackgroundFriendAcceptedNotification(
        fromUserId: fromUserId,
        fromUsername: fromUsername,
        fromPhotoUrl: fromPhotoUrl,
      );
      break;

    default:
      debugPrint('[FCM Background] Unknown type: $type');
  }
}
// --- END: Background Handler ---

// --- Phase 1.3: WorkManager Background Task Callback ---
// NOTE: Temporarily disabled due to workmanager compatibility issues
// @pragma('vm:entry-point')
// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) async {
//     debugPrint('WorkManager: Background task executed: $task');
//     debugPrint('WorkManager: Input data: $inputData');
//
//     // TODO: Implement actual prefetch logic here
//     // This would need to:
//     // 1. Initialize Firebase (if needed)
//     // 2. Get current user ID from SharedPreferences or secure storage
//     // 3. Call a service to prefetch feed content
//     // 4. Prefetch images/videos using MediaPrefetchService
//     //
//     // Example structure:
//     // try {
//     //   final userId = await _getUserIdFromStorage();
//     //   if (userId != null) {
//     //     final feedService = FeedPrefetchService();
//     //     await feedService.prefetchFeedForUser(userId);
//     //     debugPrint('WorkManager: Successfully prefetched feed for user $userId');
//     //   }
//     // } catch (e) {
//     //   debugPrint('WorkManager: Error prefetching feed: $e');
//     //   return Future.value(false);
//     // }
//
//     // For now, just log that the task ran
//     debugPrint(
//         'WorkManager: Prefetch task completed (placeholder implementation)');
//
//     return Future.value(true);
//   });
// }
// --- END: WorkManager Callback ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // MIUI/Redmi Critical Fix: Initialize device info early
  // This helps detect Xiaomi devices and apply appropriate fixes
  await DeviceInfoHelper().initialize();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- START: FCM Setup ---
  // Only register background handler once to prevent duplicate isolate warnings
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Background message handler already registered: $e');
  }

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

  // FOREGROUND: Use Island Popup (Professional App Behavior)
  // Don't use FCM local notifications when app is open
  // Background notifications are handled by system automatically
  // FcmForegroundHandler will handle foreground messages with Island Popup

  // Initialize Professional Notification System
  await ProfessionalNotificationManager().initialize();

  // Initialize Notification Action Handler (for Reply, Mark as Read, etc.)
  await NotificationActionHandler().initialize();

  // Initialize FCM Services
  FcmNavigationService().initialize(); // Background/Terminated navigation
  FcmForegroundHandler().initialize(); // Foreground Island Popup
  // --- END: FCM Setup ---

  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }
  await LocalNotificationService.NotificationService().initialize();
  await Hive.initFlutter();

  // Phase 1.3: Initialize WorkManager for background prefetching
  // NOTE: Temporarily disabled due to workmanager compatibility issues
  // if (!kIsWeb) {
  //   try {
  //     await Workmanager().initialize(
  //       callbackDispatcher,
  //       isInDebugMode: kDebugMode,
  //     );
  //     debugPrint('WorkManager: Initialized successfully');
  //   } catch (e) {
  //     debugPrint('WorkManager: Error initializing: $e');
  //   }
  // }

  // --- Register Hive Adapters ---
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(NearbyUserAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(UserProfileAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(WaveRecordAdapter());
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(FriendRequestRecordAdapter());
  }

  // --- Open Hive Boxes ---
  await Hive.openBox('settings');
  await Hive.openBox<NearbyUser>('nearbyUsers');
  await Hive.openBox<UserProfile>('userProfiles');
  await Hive.openBox<WaveRecord>('pendingWaves');
  await Hive.openBox<FriendRequestRecord>('pendingFriendRequests');
  await Hive.openBox('action_queue');

  // --- Initialize BLoCs and Services ---
  final connectivityBloc = ConnectivityBloc()..add(CheckConnectivity());
  setupLocator(connectivityBloc: connectivityBloc);
  if (!kIsWeb) {
    await locator<CacheManagerService>().manageCache();
  }
  runApp(MyApp(connectivityBloc: connectivityBloc));
}

class MyApp extends StatelessWidget {
  final ConnectivityBloc connectivityBloc;
  const MyApp({super.key, required this.connectivityBloc});

  @override
  Widget build(BuildContext context) {
    // Provides ConnectivityBloc and AuthBloc to the widget tree
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(
            value: connectivityBloc), // Provide existing ConnectivityBloc
        BlocProvider<AuthBloc>(
          // Create AuthBloc
          create: (context) => AuthBloc(
            authRepository: locator<AuthRepository>(),
          )..add(CheckAuthentication()), // Initial auth check
        ),
      ],
      child: MaterialApp(
        title: 'Freegram',
        debugShowCheckedModeBanner: false,
        theme: SonarPulseTheme.light, // Light theme definition
        darkTheme: SonarPulseTheme.dark, // Dark theme definition
        themeMode: ThemeMode.system, // Use system theme setting
        navigatorKey: locator<NavigationService>()
            .navigatorKey, // Professional navigation
        builder: (context, child) {
          // Ensure proper media query handling for keyboard and system UI
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              // Ensure text doesn't scale too much
              textScaler: TextScaler.linear(MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2)),
            ),
            child: child!,
          );
        },
        home:
            const AuthWrapper(), // Start with AuthWrapper to handle login state
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppRoutes.profile:
              final args = settings.arguments as Map<String, dynamic>?;
              final parsed = ProfileArguments.fromMap(args);
              if (parsed.userId.isNotEmpty) {
                return MaterialPageRoute(
                  builder: (_) => ProfileScreen(userId: parsed.userId),
                );
              }
              return null;
            case AppRoutes.chat:
              final args = settings.arguments as Map<String, dynamic>?;
              final parsed = ChatArguments.fromMap(args);
              if (parsed.chatId.isNotEmpty && parsed.otherUserId.isNotEmpty) {
                return MaterialPageRoute(
                  builder: (_) => FutureBuilder<UserModel?>(
                    future:
                        locator<UserRepository>().getUser(parsed.otherUserId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Scaffold(
                          body: Center(child: AppProgressIndicator()),
                        );
                      }
                      final username = snapshot.data?.username ??
                          (parsed.otherUsername ?? 'User');
                      return ImprovedChatScreen(
                        chatId: parsed.chatId,
                        otherUsername: username,
                      );
                    },
                  ),
                );
              }
              return null;
            case AppRoutes.settings:
              return MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
              );
            case AppRoutes.signup:
              return MaterialPageRoute(
                builder: (_) => const SignUpScreen(),
              );
            case AppRoutes.store:
              return MaterialPageRoute(
                builder: (_) => const StoreScreen(),
              );
            case AppRoutes.reels:
              return MaterialPageRoute(
                builder: (_) => const ReelsFeedScreen(),
              );
            case AppRoutes.createReel:
              return MaterialPageRoute(
                builder: (_) => const CreateReelScreen(),
              );
            // Create post functionality is now integrated into CreatePostWidget
            // case AppRoutes.createPost:
            //   return MaterialPageRoute(
            //     builder: (_) => const CreatePostScreen(),
            //   );
          }
          return null;
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Listens to AuthBloc state to show LoginScreen or MainScreen/EditProfileScreen
    // CRITICAL: Use BlocConsumer to ensure we always respond to state changes, even if Equatable says states are equal
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        // Log all state changes for debugging
        debugPrint(
            "AuthWrapper listener: State changed to ${state.runtimeType}");
        // Force a rebuild by scheduling a post-frame callback
        // This ensures LoginScreen shows even if BlocBuilder doesn't rebuild
        if (state is Unauthenticated || state is AuthError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // CRITICAL: Check context.mounted before accessing context
            // This callback ensures the widget tree updates
            if (context.mounted) {
              debugPrint(
                  "AuthWrapper listener: Post-frame callback for ${state.runtimeType}");
            }
          });
        }
      },
      buildWhen: (previous, current) {
        // CRITICAL: Always rebuild on state changes to ensure LoginScreen shows on logout
        // Log to debug why rebuild might not happen
        final shouldRebuild = previous.runtimeType != current.runtimeType ||
            (previous is Authenticated && current is Unauthenticated) ||
            (current is Unauthenticated && previous is! Unauthenticated);
        debugPrint(
            "AuthWrapper buildWhen: previous=${previous.runtimeType}, current=${current.runtimeType}, shouldRebuild=$shouldRebuild");
        return shouldRebuild;
      },
      builder: (context, state) {
        debugPrint("AuthWrapper: Received AuthState -> ${state.runtimeType}");

        // Handle different auth states
        if (state is AuthInitial) {
          // Show loading for initial auth check
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(
              child: AppProgressIndicator(),
            ),
          );
        }

        if (state is Authenticated) {
          // If authenticated, listen to the user's profile stream
          // CRITICAL: Use auth state type in key to ensure StreamBuilder disposes when auth state changes
          // When state changes to Unauthenticated, this key changes, forcing StreamBuilder disposal
          return StreamBuilder<UserModel>(
            key: ValueKey('user_stream_authenticated_${state.user.uid}'),
            stream: locator<UserRepository>().getUserStream(state.user.uid),
            builder: (context, snapshot) {
              // Show loading indicator while waiting for the first profile data
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Scaffold(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  body: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading your profile...'),
                      ],
                    ),
                  ),
                );
              }
              // Handle errors loading the profile
              if (snapshot.hasError) {
                debugPrint(
                    "AuthWrapper StreamBuilder Error fetching UserModel: ${snapshot.error}");
                // Check if it's a "User not found" error (race condition)
                final errorString = snapshot.error.toString().toLowerCase();
                if (errorString.contains('user not found')) {
                  // Show loading for a bit longer for new users
                  return Scaffold(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    body: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Setting up your profile...'),
                        ],
                      ),
                    ),
                  );
                }
                // Show error message and fallback to LoginScreen for other errors
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'Error loading user profile: ${snapshot.error}. Please try logging in again.'),
                      backgroundColor: Colors.red,
                    ));
                  }
                });
                return const LoginScreen(); // Fallback to Login
              }
              // If profile data is loaded
              if (snapshot.hasData) {
                final user = snapshot.data!;

                final settingsBox = Hive.box('settings');
                final onboardingKey = AuthConstants.getOnboardingKey(user.id);
                final hasCompletedOnboarding =
                    settingsBox.get(onboardingKey, defaultValue: false) as bool;

                // Check if essential profile details are filled
                final bool isProfileComplete = user.age > 0 &&
                    user.country.isNotEmpty &&
                    user.gender.isNotEmpty &&
                    user.username.isNotEmpty &&
                    user.username !=
                        'User'; // Not the default temporary username

                if (hasCompletedOnboarding && isProfileComplete) {
                  // If complete, show the main app content wrapper
                  debugPrint(
                      "AuthWrapper: Profile complete for ${user.username}. Showing MainScreen.");
                  // CRITICAL: Wrap in a widget that ensures something is always visible
                  // If MainScreenWrapper is disposed, this Scaffold remains to prevent black screen
                  return Scaffold(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    body: MainScreenWrapper(
                      key: ValueKey(user.id),
                      connectivityBloc:
                          BlocProvider.of<ConnectivityBloc>(context),
                    ),
                  );
                } else {
                  // Profile is incomplete - show multi-step onboarding
                  debugPrint(
                      "AuthWrapper: Profile incomplete for ${user.username}. Showing MultiStepOnboardingScreen.");
                  return MultiStepOnboardingScreen(
                    currentUserData: user,
                  );
                }
              }
              // Fallback if stream closes unexpectedly or data is null after waiting
              return const LoginScreen();
            },
          );
        }
        // If state is Unauthenticated or AuthError, show LoginScreen
        debugPrint(
            "AuthWrapper: State is ${state.runtimeType}. Showing LoginScreen.");
        // CRITICAL: Use ValueKey to force widget recreation when switching from Authenticated to Unauthenticated
        // This ensures LoginScreen always shows, even if BlocBuilder doesn't rebuild
        return LoginScreen(key: ValueKey('login_${state.runtimeType}'));
      },
    );
  }
}

// --- START: Modified MainScreenWrapper ---
class MainScreenWrapper extends StatefulWidget {
  final ConnectivityBloc connectivityBloc;
  const MainScreenWrapper({super.key, required this.connectivityBloc});

  @override
  State<MainScreenWrapper> createState() => _MainScreenWrapperState();
}

// Add WidgetsBindingObserver for app lifecycle events
class _MainScreenWrapperState extends State<MainScreenWrapper>
    with WidgetsBindingObserver {
  // Get instances needed for lifecycle management - moved to initState to avoid GetIt errors
  SonarController? _sonarController;
  SyncManager? _syncManager;
  PresenceManager? _presenceManager;
  late final ConnectivityBloc
      _connectivityBloc; // Will be initialized in initState
  bool _sonarShouldBeRunning =
      false; // Flag to track if sonar should auto-restart
  // IntelligentPrefetchService? _prefetchService; // Phase 1.3: Background prefetch (temporarily disabled)

  @override
  void initState() {
    super.initState();
    _connectivityBloc =
        widget.connectivityBloc; // Initialize from widget parameter

    // Initialize services after the widget is built to avoid GetIt timing issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // CRITICAL: Check mounted before accessing any state or context
      if (!mounted) return;

      try {
        _sonarController = locator<SonarController>();
        _syncManager = locator<SyncManager>();
        _presenceManager = locator<PresenceManager>();

        // Initialize presence manager
        _presenceManager?.initialize();

        // Phase 1.3: Initialize Intelligent Prefetch Service (temporarily disabled)
        // _initializePrefetchService();

        debugPrint(
            'MainScreenWrapper: Successfully initialized services from locator');
      } catch (e) {
        debugPrint(
            'MainScreenWrapper: Error initializing services from locator: $e');
        // Retry after a short delay
        Future.delayed(const Duration(milliseconds: 100), () {
          // CRITICAL: Check mounted before retry
          if (!mounted) return;

          try {
            _sonarController = locator<SonarController>();
            _syncManager = locator<SyncManager>();
            _presenceManager = locator<PresenceManager>();

            // Initialize presence manager
            _presenceManager?.initialize();

            // Phase 1.3: Initialize Intelligent Prefetch Service (temporarily disabled)
            // _initializePrefetchService();

            debugPrint(
                'MainScreenWrapper: Successfully initialized services on retry');
          } catch (retryError) {
            debugPrint(
                'MainScreenWrapper: Failed to initialize services even on retry: $retryError');
          }
        });
      }
    });

    WidgetsBinding.instance.addObserver(this); // Register observer
    // After the first frame, check onboarding and start background services
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // CRITICAL: Check mounted before accessing state
      if (mounted) {
        _checkOnboardingAndStartServices();
      }
    });
    // Optional: Add logic here to handle notification taps that opened the app
    // _handleInitialNotificationTap();
    // FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationPayload);
  }

  @override
  void dispose() {
    debugPrint("MainScreenWrapper: dispose() called - cleaning up services");
    WidgetsBinding.instance.removeObserver(this); // Remove observer

    // CRITICAL: Hide any loading overlays that might be blocking the screen
    try {
      final loadingOverlay = locator<LoadingOverlayService>();
      if (loadingOverlay.isShowing) {
        loadingOverlay.hide();
        debugPrint("MainScreenWrapper: Hid loading overlay on dispose");
      }
    } catch (e) {
      debugPrint("MainScreenWrapper: Error hiding loading overlay: $e");
    }

    // CRITICAL FIX: Stop services in fire-and-forget mode to prevent blocking logout
    // Don't await - let them clean up in background while LoginScreen shows immediately
    try {
      // Stop sonar in background (fire-and-forget to prevent blocking)
      _sonarController?.stopSonar().catchError((e) {
        debugPrint("MainScreenWrapper: Error stopping sonar in background: $e");
      });
      debugPrint("MainScreenWrapper: Sonar stop initiated (non-blocking)");
    } catch (e) {
      debugPrint("MainScreenWrapper: Error initiating sonar stop: $e");
    }

    try {
      // Dispose presence manager (cancels timers) - this is synchronous
      _presenceManager?.dispose();
      debugPrint("MainScreenWrapper: PresenceManager disposed");
    } catch (e) {
      debugPrint("MainScreenWrapper: Error disposing PresenceManager: $e");
    }

    // Note: SyncManager subscriptions are tied to ConnectivityBloc
    // They will be cleaned up automatically when the bloc is disposed
    // No need to manually dispose SyncManager here

    debugPrint("MainScreenWrapper: Dispose complete (non-blocking)");
    super.dispose();
  }

  // --- Handle App Lifecycle Changes ---
  /// Phase 1.3: Initialize Intelligent Prefetch Service (temporarily disabled)
  // Future<void> _initializePrefetchService() async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     _prefetchService = IntelligentPrefetchService(prefs: prefs);
  //     
  //     // Record initial app open
  //     _prefetchService?.recordAppOpen();
  //     
  //     // Schedule background prefetch
  //     _prefetchService?.scheduleBackgroundPrefetch();
  //     
  //     debugPrint('MainScreenWrapper: IntelligentPrefetchService initialized');
  //   } catch (e) {
  //     debugPrint('MainScreenWrapper: Error initializing prefetch service: $e');
  //   }
  // }

  /// Phase 1.3: Record app open for pattern learning (temporarily disabled)
  // void _recordAppOpen() {
  //   _prefetchService?.recordAppOpen();
  //   // Re-schedule prefetch after recording new pattern
  //   _prefetchService?.scheduleBackgroundPrefetch();
  // }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Phase 1.3: Track app opens for intelligent prefetching (temporarily disabled)
    // if (state == AppLifecycleState.resumed) {
    //   _recordAppOpen();
    // }
    super.didChangeAppLifecycleState(state);
    debugPrint("MainScreenWrapper: AppLifecycleState changed to $state");
    if (kIsWeb) return; // Ignore lifecycle events on web

    // Check if services are initialized before using them
    if (_sonarController == null ||
        _syncManager == null ||
        _presenceManager == null) {
      debugPrint(
          "MainScreenWrapper: Services not yet initialized, skipping lifecycle handling");
      return;
    }

    if (state == AppLifecycleState.resumed) {
      // --- Improvement #1 (Sync Trigger - App Resume) ---
      // When app resumes, trigger sync if online
      if (_connectivityBloc.state is Online) {
        debugPrint(
            "MainScreenWrapper: App Resumed and Online - Triggering SyncManager.processQueue()");
        _syncManager?.processQueue();
      } else {
        debugPrint(
            "MainScreenWrapper: App Resumed but Offline - Skipping sync trigger.");
      }

      // --- Improvement (Auto-Run Sonar - Resume) ---
      // Check permissions/adapter state and restart Sonar if it was running before pausing
      if (_sonarShouldBeRunning) {
        debugPrint(
            "MainScreenWrapper: App Resumed - Attempting to restart Sonar...");
        // SonarController's startSonar checks permissions/adapter internally
        _sonarController?.startSonar();
      } else {
        debugPrint(
            "MainScreenWrapper: App Resumed - Sonar was not previously running, not restarting.");
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // --- Improvement (Auto-Run Sonar - Pause) ---
      // When app pauses, stop Sonar to save battery
      // Check if Sonar is currently active before stopping
      final currentStatus = BluetoothStatusService().currentStatus;
      if (currentStatus == NearbyStatus.scanning ||
          currentStatus == NearbyStatus.userFound) {
        debugPrint("MainScreenWrapper: App Paused/Inactive - Stopping Sonar");
        _sonarController?.stopSonar();
        _sonarShouldBeRunning =
            true; // Set flag to indicate it should restart on resume
      } else {
        // If Sonar wasn't active (e.g., idle, error, permissions denied), don't set the flag
        debugPrint(
            "MainScreenWrapper: App Paused/Inactive - Sonar was not active ($currentStatus), not setting restart flag.");
        _sonarShouldBeRunning = false;
      }
    }
    // No specific action needed for `detached`, dispose handles final cleanup
  }

  // --- Combined Onboarding Check and Service Start ---
  Future<void> _checkOnboardingAndStartServices() async {
    // Check if services are initialized before proceeding
    if (_sonarController == null) {
      debugPrint(
          "MainScreenWrapper: SonarController not yet initialized, skipping service startup");
      return;
    }

    // Onboarding is now handled by AuthWrapper using MultiStepOnboardingScreen
    // Removed old OnboardingScreen usage - it's been replaced by MultiStepOnboardingScreen

    // --- Improvement (Auto-Run Sonar - Initial Start) ---
    // Start Sonar automatically after onboarding (or if already seen)
    // Only proceed if still mounted and not on web
    if (mounted && !kIsWeb) {
      debugPrint("MainScreenWrapper: Attempting initial Sonar start...");
      // Initialize user data needed by SonarController
      bool userInitialized = await _sonarController?.initializeUser() ?? false;
      if (userInitialized) {
        // Attempt to start Sonar (checks permissions/adapter internally)
        await _sonarController?.startSonar();
        // Check the actual status *after* attempting to start
        final currentStatus = BluetoothStatusService().currentStatus;
        // If successfully started (scanning or found), set the flag
        if (currentStatus == NearbyStatus.scanning ||
            currentStatus == NearbyStatus.userFound) {
          _sonarShouldBeRunning = true;
          debugPrint(
              "MainScreenWrapper: Initial Sonar start successful, sonarShouldBeRunning = true.");
        } else {
          // If start failed (permissions, adapter off etc.), ensure flag is false
          _sonarShouldBeRunning = false;
          debugPrint(
              "MainScreenWrapper: Initial Sonar start failed or stopped immediately ($currentStatus), sonarShouldBeRunning = false.");
        }
      } else {
        // If user initialization fails, cannot start Sonar
        debugPrint(
            "MainScreenWrapper: User initialization failed, cannot start Sonar.");
        _sonarShouldBeRunning = false;
      }
    }
  }

  // --- Optional: Example handlers for notification taps ---
  // Future<void> _handleInitialNotificationTap() async { /* ... */ }
  // void _handleNotificationPaylad(Map<String, dynamic> data) { /* ... */ }
  // --- End Optional Handlers ---

  @override
  Widget build(BuildContext context) {
    // This widget just wraps the actual MainScreen where the UI resides
    return const MainScreen();
  }
}
// --- END: Modified MainScreenWrapper ---
