// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/scheduler.dart';

import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/blocs/reel_upload/reel_upload_bloc.dart';
import 'package:freegram/firebase_options.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/reel_upload_manager.dart';
import 'package:freegram/services/draft_persistence_service.dart';

import 'package:freegram/services/professional_notification_manager.dart';

import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/services/gift_notification_service.dart';
import 'package:freegram/services/app_initializer.dart';
import 'package:freegram/services/session_manager.dart'; // Added import
// Hive Models

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
import 'package:freegram/widgets/splash_screen.dart';
import 'package:freegram/screens/multi_step_onboarding_screen.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/screens/improved_chat_screen.dart';
import 'package:freegram/screens/settings_screen.dart';
import 'package:freegram/screens/store_screen.dart';
import 'package:freegram/screens/reels_feed_screen.dart';
import 'package:freegram/screens/create_reel_screen.dart';
import 'package:freegram/navigation/app_routes.dart';
import 'package:freegram/screens/gift_send_selection_screen.dart';
import 'package:freegram/screens/gift_send_composer_screen.dart';
import 'package:freegram/screens/gift_send_friend_picker_screen.dart';
import 'package:freegram/models/gift_model.dart';
// Services

import 'package:freegram/services/user_stream_provider.dart';
// <<<--- Added for overlay cleanup
// MIUI/Redmi Fixes

// Other Imports

import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';

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

    case 'reelLike':
    case 'reelComment':
      final reelId = message.data['contentId'] ?? '';
      final fromUserId = message.data['fromUserId'] ?? '';
      final fromUsername = message.data['fromUsername'] ?? 'User';
      final fromPhotoUrl = message.data['fromPhotoUrl'] ?? '';
      final count = int.tryParse(message.data['count'] ?? '1') ?? 1;
      final notificationType = type; // 'reelLike' or 'reelComment'

      await proNotificationManager.showBackgroundReelNotification(
        reelId: reelId,
        fromUserId: fromUserId,
        fromUsername: fromUsername,
        fromPhotoUrl: fromPhotoUrl,
        notificationType: notificationType,
        count: count,
      );
      break;

    case 'comment':
    case 'reaction':
    case 'like':
    case 'mention':
      final postId = message.data['postId'] ?? message.data['contentId'] ?? '';
      final fromUserId = message.data['fromUserId'] ?? '';
      final fromUsername = message.data['fromUsername'] ?? 'User';
      final fromPhotoUrl = message.data['fromUserPhotoUrl'] ??
          message.data['fromPhotoUrl'] ??
          '';
      final count = int.tryParse(message.data['count'] ?? '1') ?? 1;
      final notificationType = type;
      final commentText = message.data['message'] ?? message.notification?.body;

      await proNotificationManager.showBackgroundPostNotification(
        postId: postId,
        fromUserId: fromUserId,
        fromUsername: fromUsername,
        fromPhotoUrl: fromPhotoUrl,
        notificationType: notificationType,
        count: count,
        commentText: commentText,
      );
      break;

    default:
      debugPrint('[FCM Background] Unknown type: $type');
  }
}
// --- END: Background Handler ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- START: FCM Background Handler Registration ---
  // Must be registered before any other Firebase initialization
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Background message handler already registered: $e');
  }
  // --- END: FCM Background Handler Registration ---

  // Show splash screen immediately
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      darkTheme: SonarPulseTheme.dark,
      themeMode: ThemeMode.system,
      home: SplashScreen(
        onInitializationComplete: AppInitializer.initialize,
        onComplete: (connectivityBloc) {
          return MyApp(connectivityBloc: connectivityBloc as ConnectivityBloc);
        },
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final ConnectivityBloc connectivityBloc;
  const MyApp({super.key, required this.connectivityBloc});

  @override
  Widget build(BuildContext context) {
    // Provides ConnectivityBloc, AuthBloc, and ReelUploadBloc to the widget tree
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
        BlocProvider<ReelUploadBloc>(
          // Create ReelUploadBloc for optimistic upload UI
          create: (context) => ReelUploadBloc(
            uploadManager: locator<ReelUploadManager>(),
            draftService: locator<DraftPersistenceService>(),
          ),
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
          // Set navigator key for gift notification service
          WidgetsBinding.instance.addPostFrameCallback((_) {
            locator<GiftNotificationService>()
                .setNavigatorKey(locator<NavigationService>().navigatorKey);
          });

          // Ensure proper media query handling for keyboard and system UI
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              // Ensure text doesn't scale too much
              textScaler: TextScaler.linear(
                  MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2)),
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
            case AppRoutes.giftSendSelection:
              debugPrint('Navigation: Generating giftSendSelection route');
              final args = settings.arguments as Map<String, dynamic>?;
              debugPrint('Navigation: Args: $args');
              final recipient = args?['recipient'] as UserModel?;
              debugPrint('Navigation: Recipient: $recipient');

              if (recipient != null) {
                return MaterialPageRoute(
                  builder: (_) => GiftSendSelectionScreen(recipient: recipient),
                );
              }
              debugPrint(
                  'Navigation: Error - Recipient is null for giftSendSelection');
              // Fallback to error screen or previous screen to prevent crash
              return MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(
                      child:
                          Text('Error: Missing recipient for gift selection')),
                ),
              );
            case AppRoutes.giftSendComposer:
              final args = settings.arguments as Map<String, dynamic>?;
              final recipient = args?['recipient'] as UserModel?;
              final gift = args?['gift'] as GiftModel?;
              final isOwned = args?['isOwned'] as bool? ?? false;

              if (recipient != null && gift != null) {
                return MaterialPageRoute(
                  builder: (_) => GiftSendComposerScreen(
                    recipient: recipient,
                    gift: gift,
                    isOwned: isOwned,
                    ownedGiftId: args?['ownedGiftId'] as String?,
                  ),
                );
              }
              return MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(
                      child:
                          Text('Error: Missing arguments for gift composer')),
                ),
              );
            case AppRoutes.giftSendFriendPicker:
              final args = settings.arguments as Map<String, dynamic>?;
              final gift = args?['gift'] as GiftModel?;
              final ownedGiftId = args?['ownedGiftId'] as String?;
              return MaterialPageRoute(
                builder: (_) => GiftSendFriendPickerScreen(
                  preselectedGift: gift,
                  ownedGiftId: ownedGiftId,
                ),
              );
          }
          debugPrint('Navigation: Unknown route: ${settings.name}');
          return null;
        },
      ),
    );
  }
}

// PHASE 1: Memory Leak Fix - Convert to StatefulWidget for explicit stream management
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  StreamSubscription<UserModel>? _userStreamSubscription;
  UserModel? _cachedUser;
  String? _currentUserId;

  @override
  void dispose() {
    // PHASE 1: Explicitly cancel stream subscription to prevent memory leaks
    _userStreamSubscription?.cancel();
    _userStreamSubscription = null;
    super.dispose();
  }

  void _listenToUserStream(String userId) {
    // Cancel existing subscription if user changed
    if (_currentUserId != userId) {
      _userStreamSubscription?.cancel();
      _userStreamSubscription = null;
      _cachedUser = null;
    }

    if (_userStreamSubscription != null) return; // Already listening

    _currentUserId = userId;
    // CRITICAL: Use UserStreamProvider to ensure data is cached for other screens
    _userStreamSubscription = UserStreamProvider().getUserStream(userId).listen(
      (user) {
        if (mounted) {
          setState(() {
            _cachedUser = user;
          });
        }
      },
      onError: (error) {
        debugPrint("AuthWrapper: User stream error: $error");
        if (mounted) {
          setState(() {
            _cachedUser = null;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listens to AuthBloc state to show LoginScreen or MainScreen/EditProfileScreen
    // CRITICAL: Use BlocConsumer to ensure we always respond to state changes, even if Equatable says states are equal
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        // Log all state changes for debugging
        debugPrint(
            "AuthWrapper listener: State changed to ${state.runtimeType}");
        // PHASE 1: Cancel stream subscription when auth state changes to Unauthenticated
        if (state is Unauthenticated || state is AuthError) {
          _userStreamSubscription?.cancel();
          _userStreamSubscription = null;
          _cachedUser = null;
          _currentUserId = null;
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
          // PHASE 1: Start listening to user stream with explicit subscription management
          _listenToUserStream(state.user.uid);

          // Show loading while waiting for user data
          if (_cachedUser == null) {
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppProgressIndicator(),
                    const SizedBox(height: DesignTokens.spaceMD),
                    Text(
                      'Loading your profile...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          // Use cached user data
          final user = _cachedUser!;

          // Check if user has essential profile data in Firestore
          // Show multistep screen only for new users with no data
          final bool isProfileComplete = user.age > 0 &&
              user.country.isNotEmpty &&
              user.gender.isNotEmpty &&
              user.username.isNotEmpty;

          if (isProfileComplete) {
            // If complete, show the main app content wrapper
            debugPrint(
                "AuthWrapper: Profile complete for ${user.username}. Showing MainScreen.");
            // CRITICAL: Wrap in a widget that ensures something is always visible
            // If MainScreenWrapper is disposed, this Scaffold remains to prevent black screen
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: MainScreenWrapper(
                key: ValueKey(user.id),
                connectivityBloc: BlocProvider.of<ConnectivityBloc>(context),
              ),
            );
          } else {
            // Profile is incomplete - show multi-step onboarding for new users
            debugPrint(
                "AuthWrapper: Profile incomplete for ${user.username.isEmpty ? 'new user' : user.username}. Showing MultiStepOnboardingScreen.");
            return MultiStepOnboardingScreen(
              currentUserData: user,
            );
          }
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

// --- START: Simplified MainScreenWrapper ---
// Session initialization is now handled in SplashScreen
// This wrapper only manages lifecycle and connectivity
class MainScreenWrapper extends StatefulWidget {
  final ConnectivityBloc connectivityBloc;
  const MainScreenWrapper({super.key, required this.connectivityBloc});

  @override
  State<MainScreenWrapper> createState() => _MainScreenWrapperState();
}

class _MainScreenWrapperState extends State<MainScreenWrapper>
    with WidgetsBindingObserver {
  final _sessionManager = SessionManager();
  late final ConnectivityBloc _connectivityBloc;

  @override
  void initState() {
    super.initState();
    _connectivityBloc = widget.connectivityBloc;
    WidgetsBinding.instance.addObserver(this);

    // Session is already initialized in SplashScreen
    // Just ensure background services are running
    _sessionManager.checkOnboardingAndStartServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionManager.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _sessionManager.handleLifecycleChange(state, _connectivityBloc);
  }

  @override
  Widget build(BuildContext context) {
    // Directly show MainScreen - session already initialized
    return const MainScreen();
  }
}
// --- END: Simplified MainScreenWrapper ---
