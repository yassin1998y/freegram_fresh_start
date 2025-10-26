// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/scheduler.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/firebase_options.dart';
import 'package:freegram/locator.dart';
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
import 'package:freegram/screens/edit_profile_screen.dart';
import 'package:freegram/screens/login_screen.dart';
import 'package:freegram/screens/main_screen.dart';
import 'package:freegram/screens/onboarding_screen.dart';
// Services
import 'package:freegram/services/cache_manager_service.dart';
import 'package:freegram/services/sonar/notification_service.dart'
    as LocalNotificationService;
import 'package:freegram/services/sonar/sonar_controller.dart'; // <<<--- Added for MainScreenWrapper
import 'package:freegram/services/sync_manager.dart'; // <<<--- Added for MainScreenWrapper
import 'package:freegram/services/sonar/bluetooth_service.dart'; // <<<--- Added for MainScreenWrapper (StatusService)
// Other Imports
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:freegram/theme/app_theme.dart';

// --- START: Background Handler ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, like Firestore,
  // make sure you call `initializeApp` before using them.
  // IMPORTANT: Re-initializing Firebase here might be necessary if your background
  // task needs it and runs in a separate isolate. Test this thoroughly.
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
  debugPrint('Message data: ${message.data}');
  debugPrint(
      'Message notification: ${message.notification?.title}/${message.notification?.body}');

  // You COULD potentially show a local notification here as well,
  // but be mindful of double notifications if the system also shows one.
  // Example (needs testing in background isolate context):
  // await LocalNotificationService.NotificationService().initialize(); // May need initialization here
  // LocalNotificationService.NotificationService().showWaveNotification(
  //   title: message.notification?.title ?? "Background Notification",
  //   body: message.notification?.body ?? "",
  //   payload: message.data['click_action'] ?? message.data['screen'], // Example payload extraction
  // );
}
// --- END: Background Handler ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Got a message whilst in the foreground!');
    debugPrint('Message data: ${message.data}');
    RemoteNotification? notification = message.notification;
    if (notification != null && !kIsWeb) {
      debugPrint(
          'Foreground message contained a notification: ${notification.title}/${notification.body}');
      LocalNotificationService.NotificationService().showWaveNotification(
        title: notification.title ?? "New Notification",
        body: notification.body ?? "",
        payload: message.data['screen'] ?? message.data['click_action'],
      );
    }
  });
  // --- END: FCM Setup ---

  if (!kIsWeb) {
    MobileAds.instance.initialize();
  }
  await LocalNotificationService.NotificationService().initialize();
  await Hive.initFlutter();

  // --- Register Hive Adapters ---
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(NearbyUserAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(UserProfileAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(WaveRecordAdapter());
  if (!Hive.isAdapterRegistered(4))
    Hive.registerAdapter(FriendRequestRecordAdapter());

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
        home:
            const AuthWrapper(), // Start with AuthWrapper to handle login state
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Listens to AuthBloc state to show LoginScreen or MainScreen/EditProfileScreen
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        debugPrint("AuthWrapper: Received AuthState -> ${state.runtimeType}");
        if (state is Authenticated) {
          // debugPrint("AuthWrapper: State is Authenticated for user ${state.user.uid}. Getting UserModel stream...");
          // If authenticated, listen to the user's profile stream
          return StreamBuilder<UserModel>(
            stream: locator<UserRepository>().getUserStream(state.user.uid),
            builder: (context, snapshot) {
              // debugPrint("AuthWrapper StreamBuilder: State=${snapshot.connectionState}, HasData=${snapshot.hasData}, Error=${snapshot.error}");
              // Show loading indicator while waiting for the first profile data
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              // Handle errors loading the profile
              if (snapshot.hasError) {
                debugPrint(
                    "AuthWrapper StreamBuilder Error fetching UserModel: ${snapshot.error}");
                // Check if it's a "User not found" error (race condition)
                final errorString = snapshot.error.toString().toLowerCase();
                if (errorString.contains('user not found')) {
                  // Show loading for a bit longer for new users
                  return const Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
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
                // debugPrint("AuthWrapper StreamBuilder: Received UserModel for ${user.username}. Checking profile completeness...");
                // Check if essential profile details are filled
                final bool isProfileComplete = user.age > 0 &&
                    user.country.isNotEmpty &&
                    user.gender.isNotEmpty;

                if (isProfileComplete) {
                  // If complete, show the main app content wrapper
                  // debugPrint("AuthWrapper: ---> RETURNING MainScreenWrapper <---");
                  return MainScreenWrapper(
                    key: ValueKey(user
                        .id), // Use ValueKey for potential rebuilds on user change
                    connectivityBloc: BlocProvider.of<ConnectivityBloc>(
                        context), // Pass ConnectivityBloc from context
                  );
                } else {
                  // Check if user has already completed profile check once
                  final settingsBox = Hive.box('settings');
                  final hasCheckedProfile = settingsBox.get(
                      'hasCheckedProfileCompleteness',
                      defaultValue: false) as bool;

                  // Only show edit profile if this is the first time OR if profile is truly incomplete
                  if (!hasCheckedProfile) {
                    // Mark that we've checked once
                    settingsBox.put('hasCheckedProfileCompleteness', true);
                    // For first-time users or incomplete profiles, show EditProfileScreen
                    // debugPrint("AuthWrapper: ---> RETURNING EditProfileScreen (First Time) <---");
                    return EditProfileScreen(
                      currentUserData: user.toMap(), // Pass current data
                      isCompletingProfile:
                          true, // Flag to indicate profile completion flow
                    );
                  } else {
                    // User has checked before, just go to main screen
                    // Profile can be edited from menu
                    // debugPrint("AuthWrapper: Profile incomplete but already checked once, showing main screen");
                    return MainScreenWrapper(
                      key: ValueKey(user.id),
                      connectivityBloc:
                          BlocProvider.of<ConnectivityBloc>(context),
                    );
                  }
                }
              }
              // Fallback if stream closes unexpectedly or data is null after waiting
              // debugPrint("AuthWrapper StreamBuilder: No UserModel data after waiting. Returning LoginScreen.");
              return const LoginScreen();
            },
          );
        }
        // If state is Initial, Unauthenticated, or AuthError, show LoginScreen
        debugPrint(
            "AuthWrapper: State is ${state.runtimeType}. Showing LoginScreen.");
        return const LoginScreen();
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
  late final ConnectivityBloc
      _connectivityBloc; // Will be initialized in initState
  bool _sonarShouldBeRunning =
      false; // Flag to track if sonar should auto-restart

  @override
  void initState() {
    super.initState();
    _connectivityBloc =
        widget.connectivityBloc; // Initialize from widget parameter

    // Initialize services after the widget is built to avoid GetIt timing issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _sonarController = locator<SonarController>();
        _syncManager = locator<SyncManager>();
        debugPrint(
            'MainScreenWrapper: Successfully initialized services from locator');
      } catch (e) {
        debugPrint(
            'MainScreenWrapper: Error initializing services from locator: $e');
        // Retry after a short delay
        Future.delayed(const Duration(milliseconds: 100), () {
          try {
            _sonarController = locator<SonarController>();
            _syncManager = locator<SyncManager>();
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
      _checkOnboardingAndStartServices();
    });
    // Optional: Add logic here to handle notification taps that opened the app
    // _handleInitialNotificationTap();
    // FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationPayload);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    // Ensure sonar stops cleanly when this wrapper is disposed (e.g., on logout)
    _sonarController?.stopSonar();
    // Note: SyncManager might also need a dispose call if it has active timers
    // _syncManager?.dispose(); // Uncomment if SyncManager implements dispose
    super.dispose();
  }

  // --- Handle App Lifecycle Changes ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint("MainScreenWrapper: AppLifecycleState changed to $state");
    if (kIsWeb) return; // Ignore lifecycle events on web

    // Check if services are initialized before using them
    if (_sonarController == null || _syncManager == null) {
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

    final settingsBox = Hive.box('settings');
    final bool hasSeenOnboarding =
        settingsBox.get('hasSeenOnboarding', defaultValue: false);
    // debugPrint("MainScreenWrapper: Checking onboarding. Seen: $hasSeenOnboarding");

    // Show onboarding if needed, await its completion
    if (!hasSeenOnboarding && mounted) {
      // debugPrint("MainScreenWrapper: Showing OnboardingScreen.");
      await Navigator.of(context).push(
        // Await completion before starting services
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => const OnboardingScreen(),
        ),
      );
      // debugPrint("MainScreenWrapper: Onboarding finished. Proceeding to start services.");
    }

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
  // void _handleNotificationPayload(Map<String, dynamic> data) { /* ... */ }
  // --- End Optional Handlers ---

  @override
  Widget build(BuildContext context) {
    // This widget just wraps the actual MainScreen where the UI resides
    // debugPrint("MainScreenWrapper: Building MainScreen.");
    return const MainScreen();
  }
}
// --- END: Modified MainScreenWrapper ---
