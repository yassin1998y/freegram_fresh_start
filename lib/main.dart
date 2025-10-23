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
import 'package:freegram/models/hive/nearby_user.dart';
import 'package:freegram/models/hive/user_profile.dart';
import 'package:freegram/models/hive/wave_record.dart';
import 'package:freegram/models/hive/friend_request_record.dart';
import 'package:freegram/models/user_model.dart';
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
  Hive.registerAdapter(NearbyUserAdapter());
  Hive.registerAdapter(UserProfileAdapter());
  Hive.registerAdapter(WaveRecordAdapter());
  Hive.registerAdapter(FriendRequestRecordAdapter());
  await Hive.openBox('settings');
  await Hive.openBox<NearbyUser>('nearbyUsers');
  await Hive.openBox<UserProfile>('userProfiles');
  await Hive.openBox<WaveRecord>('pendingWaves');
  await Hive.openBox<FriendRequestRecord>('pendingFriendRequests');
  await Hive.openBox('action_queue');
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
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
      ),
    );
  }
}

// AuthWrapper - Simplified StreamBuilder Handling + Final Return Log
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

              if (snapshot.hasData) {
                final user = snapshot.data!;
                debugPrint("AuthWrapper StreamBuilder: Received UserModel for ${user.username}. Checking profile completeness...");

                final bool isProfileComplete = user.age > 0 &&
                    user.country.isNotEmpty &&
                    user.gender.isNotEmpty;

                if (isProfileComplete) {
                  debugPrint("AuthWrapper: ---> RETURNING MainScreenWrapper <---"); // Final return log
                  return MainScreenWrapper(key: ValueKey(user.id));
                } else {
                  debugPrint("AuthWrapper: ---> RETURNING EditProfileScreen <---"); // Final return log
                  return EditProfileScreen(
                    currentUserData: user.toMap(),
                    isCompletingProfile: true,
                  );
                }
              } else if (snapshot.hasError) {
                debugPrint("AuthWrapper StreamBuilder Error fetching UserModel: ${snapshot.error}");
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error loading user profile: ${snapshot.error}. Please try logging in again.'),
                          backgroundColor: Colors.red,
                        )
                    );
                  }
                });
                debugPrint("AuthWrapper: ---> RETURNING LoginScreen (due to error) <---"); // Final return log
                return const LoginScreen();
              } else {
                debugPrint("AuthWrapper StreamBuilder: Waiting for initial UserModel data...");
                // *** ADDED LOG ***
                debugPrint("AuthWrapper: ---> RETURNING Loading Indicator <---");
                // *** END LOG ***
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
            },
          );
        }
        // Unauthenticated or Initial state
        debugPrint("AuthWrapper: State is ${state.runtimeType}. Showing LoginScreen.");
        debugPrint("AuthWrapper: ---> RETURNING LoginScreen (Unauthenticated/Initial) <---"); // Final return log
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

    debugPrint("MainScreenWrapper: Checking onboarding. Seen: $hasSeenOnboarding");

    if (!hasSeenOnboarding && mounted) {
      debugPrint("MainScreenWrapper: Showing OnboardingScreen.");
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
    debugPrint("MainScreenWrapper: Building MainScreen.");
    return const MainScreen();
  }
}