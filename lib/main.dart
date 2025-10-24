// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/scheduler.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/firebase_options.dart';
import 'package:freegram/locator.dart';
// Hive Models to Keep:
import 'package:freegram/models/hive/nearby_user.dart';
import 'package:freegram/models/hive/user_profile.dart';
import 'package:freegram/models/hive/wave_record.dart';
import 'package:freegram/models/hive/friend_request_record.dart';
// Remove Hive adapters for deleted models if they existed here
import 'package:freegram/models/user_model.dart'; // Keep UserModel import
import 'package:freegram/repositories/auth_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/edit_profile_screen.dart';
import 'package:freegram/screens/login_screen.dart';
import 'package:freegram/screens/main_screen.dart';
import 'package:freegram/screens/onboarding_screen.dart';
import 'package:freegram/services/cache_manager_service.dart';
import 'package:freegram/services/sonar/notification_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:freegram/theme/app_theme.dart';

// Hive Type IDs:
// 0: NearbyMessage (kept in models/ folder, generated file needs checking)
// 1: NearbyUser
// 2: UserProfile
// 3: WaveRecord
// 4: FriendRequestRecord

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    MobileAds.instance.initialize();
  }
  await NotificationService().initialize();
  await Hive.initFlutter();

  // --- Register Hive Adapters for KEPT models ---
  // Ensure Type IDs match your generated adapters exactly
  // Check the .g.dart files for the correct typeId values
  // Only register adapters if they haven't been registered elsewhere (e.g., in the model file itself if using build_runner setup)
  // It's safer to assume build_runner handles registration if set up correctly,
  // but explicitly registering here ensures they are available. Double-check if you get errors.

  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(NearbyUserAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(UserProfileAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(WaveRecordAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(FriendRequestRecordAdapter());
  // Assuming NearbyMessageAdapter (typeId 0) is registered elsewhere or automatically

  // --- Open Hive Boxes ---
  await Hive.openBox('settings'); // Keep for onboarding etc.
  await Hive.openBox<NearbyUser>('nearbyUsers'); // Keep
  await Hive.openBox<UserProfile>('userProfiles'); // Keep
  await Hive.openBox<WaveRecord>('pendingWaves'); // Keep
  await Hive.openBox<FriendRequestRecord>('pendingFriendRequests'); // Keep
  await Hive.openBox('action_queue'); // Keep

  // --- Initialize BLoCs and Services ---
  final connectivityBloc = ConnectivityBloc()..add(CheckConnectivity());
  setupLocator(connectivityBloc: connectivityBloc); // Setup GetIt locator
  if (!kIsWeb) {
    await locator<CacheManagerService>().manageCache(); // Keep cache management
  }
  runApp(MyApp(connectivityBloc: connectivityBloc));
}

class MyApp extends StatelessWidget {
  final ConnectivityBloc connectivityBloc;
  const MyApp({super.key, required this.connectivityBloc});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: connectivityBloc), // Keep Connectivity BLoC
        BlocProvider<AuthBloc>( // Keep Auth BLoC
          create: (context) => AuthBloc(
            authRepository: locator<AuthRepository>(),
          )..add(CheckAuthentication()),
        ),
        // Remove providers for deleted BLoCs if any were here
      ],
      child: MaterialApp(
        title: 'Freegram',
        debugShowCheckedModeBanner: false,
        theme: SonarPulseTheme.light, // Keep theme
        darkTheme: SonarPulseTheme.dark, // Keep theme
        themeMode: ThemeMode.system, // Keep theme mode
        home: const AuthWrapper(), // Keep AuthWrapper
      ),
    );
  }
}

// AuthWrapper remains largely the same, but ensure UserModel checks
// do not reference deleted fields (e.g., gamification levels)
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        debugPrint("AuthWrapper: Received AuthState -> ${state.runtimeType}");

        if (state is Authenticated) {
          debugPrint("AuthWrapper: State is Authenticated for user ${state.user.uid}. Getting UserModel stream...");
          return StreamBuilder<UserModel>(
            stream: locator<UserRepository>().getUserStream(state.user.uid),
            builder: (context, snapshot) {
              debugPrint("AuthWrapper StreamBuilder: State=${snapshot.connectionState}, HasData=${snapshot.hasData}, Error=${snapshot.error}");

              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                // Show loading indicator while waiting for the first UserModel data
                debugPrint("AuthWrapper StreamBuilder: Waiting for initial UserModel data...");
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                debugPrint("AuthWrapper StreamBuilder Error fetching UserModel: ${snapshot.error}");
                // Handle error state, maybe show login screen with an error message
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error loading user profile: ${snapshot.error}. Please try logging in again.'),
                          backgroundColor: Colors.red,
                        )
                    );
                    // Optionally force logout if profile error is critical
                    // context.read<AuthBloc>().add(SignOut());
                  }
                });
                return const LoginScreen(); // Fallback to LoginScreen on error
              }
              if (snapshot.hasData) {
                final user = snapshot.data!;
                debugPrint("AuthWrapper StreamBuilder: Received UserModel for ${user.username}. Checking profile completeness...");

                // Profile completeness check might need adjustment
                // if it relied on deleted fields. Use remaining fields.
                final bool isProfileComplete = user.age > 0 &&
                    user.country.isNotEmpty &&
                    user.gender.isNotEmpty;

                if (isProfileComplete) {
                  debugPrint("AuthWrapper: ---> RETURNING MainScreenWrapper <---");
                  return MainScreenWrapper(key: ValueKey(user.id)); // Use ValueKey to rebuild if user changes
                } else {
                  debugPrint("AuthWrapper: ---> RETURNING EditProfileScreen <---");
                  return EditProfileScreen(
                    currentUserData: user.toMap(), // Pass current data
                    isCompletingProfile: true,
                  );
                }
              }
              // Fallback if data is null after waiting (should ideally not happen with Firestore streams unless doc deleted)
              debugPrint("AuthWrapper StreamBuilder: No UserModel data after waiting. Returning LoginScreen.");
              return const LoginScreen();
            },
          );
        }
        // Unauthenticated or Initial state
        debugPrint("AuthWrapper: State is ${state.runtimeType}. Showing LoginScreen.");
        return const LoginScreen(); // Show LoginScreen for Unauthenticated/Initial states
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
    final bool hasSeenOnboarding = settingsBox.get('hasSeenOnboarding', defaultValue: false);

    debugPrint("MainScreenWrapper: Checking onboarding. Seen: $hasSeenOnboarding");

    if (!hasSeenOnboarding && mounted) {
      debugPrint("MainScreenWrapper: Showing OnboardingScreen.");
      // Use pushReplacement if you don't want the user to go back to MainScreen from Onboarding
      // Use push for modal-like behavior
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true, // Makes it slide up like a modal
          builder: (context) => const OnboardingScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("MainScreenWrapper: Building MainScreen.");
    return const MainScreen(); // Just build MainScreen
  }
}