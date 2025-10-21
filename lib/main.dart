// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/firebase_options.dart';
import 'package:freegram/locator.dart';
// Import Hive models
import 'package:freegram/models/hive/nearby_user.dart';
import 'package:freegram/models/hive/user_profile.dart';
import 'package:freegram/models/hive/wave_record.dart';
import 'package:freegram/models/hive/friend_request_record.dart';
// Regular models
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/auth_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/edit_profile_screen.dart';
import 'package:freegram/screens/login_screen.dart';
import 'package:freegram/screens/main_screen.dart';
import 'package:freegram/screens/onboarding_screen.dart';
import 'package:freegram/services/cache_manager_service.dart';
// Import NotificationService
import 'package:freegram/services/sonar/notification_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:freegram/theme/app_theme.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Mobile Ads (if not web)
  if (!kIsWeb) {
    MobileAds.instance.initialize();
  }

  // **Initialize Notification Service**
  await NotificationService().initialize();

  // --- Hive Initialization ---
  await Hive.initFlutter();

  // Register all Hive adapters
  Hive.registerAdapter(NearbyUserAdapter());
  Hive.registerAdapter(UserProfileAdapter());
  Hive.registerAdapter(WaveRecordAdapter());
  Hive.registerAdapter(FriendRequestRecordAdapter());

  // Open all Hive boxes
  await Hive.openBox('settings'); // Keep settings box
  await Hive.openBox<NearbyUser>('nearbyUsers');
  await Hive.openBox<UserProfile>('userProfiles');
  await Hive.openBox<WaveRecord>('pendingWaves');
  await Hive.openBox<FriendRequestRecord>('pendingFriendRequests');
  await Hive.openBox('action_queue');

  // --- End Hive Initialization ---

  // Initialize Connectivity Bloc
  final connectivityBloc = ConnectivityBloc()..add(CheckConnectivity());

  // Setup Dependency Injection (GetIt)
  setupLocator(connectivityBloc: connectivityBloc);

  // Manage Cache (if not web)
  if (!kIsWeb) {
    await locator<CacheManagerService>().manageCache();
  }

  // Run the App
  runApp(MyApp(connectivityBloc: connectivityBloc));
}

// MyApp remains the same
class MyApp extends StatelessWidget {
  final ConnectivityBloc connectivityBloc;
  const MyApp({super.key, required this.connectivityBloc});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: connectivityBloc),
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(
            authRepository: locator<AuthRepository>(),
          )..add(CheckAuthentication()),
        ),
      ],
      child: MaterialApp(
        title: 'Freegram',
        debugShowCheckedModeBanner: false,
        theme: SonarPulseTheme.light,
        darkTheme: SonarPulseTheme.dark,
        themeMode: ThemeMode.system, // Or load from settings
        home: const AuthWrapper(),
      ),
    );
  }
}

// AuthWrapper remains the same
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return StreamBuilder<UserModel>(
            stream: locator<UserRepository>().getUserStream(state.user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                    body: Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        )));
              }
              if (!snapshot.hasData || snapshot.hasError) {
                print("AuthWrapper Error: ${snapshot.error}");
                return const LoginScreen();
              }

              final user = snapshot.data!;
              final bool isProfileComplete = user.age > 0 &&
                  user.country.isNotEmpty &&
                  user.gender.isNotEmpty;

              if (isProfileComplete) {
                return MainScreenWrapper(key: ValueKey(user.id));
              } else {
                return EditProfileScreen(
                  currentUserData: user.toMap(),
                  isCompletingProfile: true,
                );
              }
            },
          );
        }
        return const LoginScreen();
      },
    );
  }
}

// MainScreenWrapper remains the same
class MainScreenWrapper extends StatefulWidget {
  const MainScreenWrapper({super.key});

  @override
  State<MainScreenWrapper> createState() => _MainScreenWrapperState();
}

class _MainScreenWrapperState extends State<MainScreenWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboarding();
    });
  }

  void _checkOnboarding() {
    final settingsBox = Hive.box('settings');
    final bool hasSeenOnboarding =
    settingsBox.get('hasSeenOnboarding', defaultValue: false);

    if (!hasSeenOnboarding && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => const OnboardingScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MainScreen();
  }
}
