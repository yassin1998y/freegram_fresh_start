// lib/screens/nearby_screen.dart
import 'dart:async';
import 'dart:io'; // For Platform check
import 'dart:ui'; // For ImageFilter and BackdropFilter
import 'package:app_settings/app_settings.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter_bloc/flutter_bloc.dart';
// Blocs
import 'package:freegram/blocs/nearby_bloc.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
// Locator, Repositories, Services
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/services/sonar/local_cache_service.dart';
import 'package:freegram/services/sonar/sonar_controller.dart';
import 'package:freegram/services/sonar/bluetooth_service.dart';
import 'package:freegram/services/sonar/ble_advertiser.dart';
import 'package:freegram/services/sync_manager.dart'; // Import SyncManager
// MIUI/Redmi Fixes
import 'package:freegram/services/device_info_helper.dart';
import 'package:freegram/services/miui_permission_helper.dart';
// Models (Hive & Firestore Alias)
import 'package:freegram/models/hive/nearby_user.dart';
import 'package:freegram/models/hive/user_profile.dart';
import 'package:freegram/models/user_model.dart' as ServerUserModel; // Alias
import 'package:freegram/services/navigation_service.dart';
// Screens
import 'package:freegram/screens/profile_screen.dart';
// Widgets
import 'package:freegram/widgets/sonar_view.dart';
import 'package:freegram/widgets/professional_components.dart';
import 'package:freegram/widgets/responsive_system.dart';
import 'package:freegram/theme/app_theme.dart'; // For SonarPulseTheme
import 'package:freegram/theme/design_tokens.dart';
// Other Utils
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// --- Main StatelessWidget Wrapper ---
// Provides BLoCs needed by this screen and its children
class NearbyScreen extends StatelessWidget {
  const NearbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // NearbyBloc listens to BluetoothStatusService for UI state
        BlocProvider(create: (context) => NearbyBloc()),
        // FriendsBloc needed for actions within NearbyUserCard's modal
        BlocProvider(
          create: (context) =>
              FriendsBloc(userRepository: locator<UserRepository>())
                ..add(LoadFriends()),
        ),
      ],
      child: const _NearbyScreenView(), // The main stateful widget
    );
  }
}

// --- Main StatefulWidget View ---
// Handles UI state, animations, and interacts with services/Blocs
class _NearbyScreenView extends StatefulWidget {
  const _NearbyScreenView();
  @override
  State<_NearbyScreenView> createState() => _NearbyScreenViewState();
}

// Keep WidgetsBindingObserver for app lifecycle and battery optimization check
class _NearbyScreenViewState extends State<_NearbyScreenView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Get service instances via locator
  final SonarController _sonarController = locator<SonarController>();
  final LocalCacheService _localCacheService = locator<LocalCacheService>();
  final UserRepository _userRepository = locator<UserRepository>();
  final SyncManager _syncManager =
      locator<SyncManager>(); // Get SyncManager instance
  final Box _settingsBox = Hive.box('settings');

  // UI State Variables
  bool _isBluetoothHardwareEnabled =
      false; // Tracks UI state based on Service status
  late AnimationController
      _unleashController; // Animation for sonar start pulse
  late AnimationController
      _discoveryController; // Animation for user found pulse
  String? _currentUserPhotoUrl; // For the center avatar
  final bool _isWeb = kIsWeb; // Check if running on web
  StreamSubscription?
      _statusSubscription; // Subscription to shared BluetoothStatusService

  // Sync-related state
  Timer? _syncTimer; // Timer for auto-sync
  bool _isSyncing = false; // Track sync status
  int _unsyncedCount = 0; // Count of unsynced profiles
  bool _isOnline = true; // Track connectivity status
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Found users section state
  bool _isFoundUsersExpanded =
      false; // Controls horizontal avatar list visibility

  @override
  void initState() {
    super.initState();
    if (!_isWeb) {
      WidgetsBinding.instance.addObserver(this); // Observe app lifecycle

      // Initialize animation controllers
      _unleashController = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 800));
      _discoveryController = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 600));

      // Fetch current user's photo for the center avatar
      _fetchCurrentUserPhoto();

      // Listen to status updates from the shared BluetoothStatusService
      _statusSubscription =
          BluetoothStatusService().statusStream.listen(_handleStatusUpdate);
      // Set initial UI state based on the current service status
      _handleStatusUpdate(BluetoothStatusService().currentStatus);

      // Check for battery optimization settings after the first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndShowBatteryOptimizationDialog();
      });

      // Start auto-sync timer
      _startAutoSync();

      // Start connectivity monitoring
      _startConnectivityMonitoring();
    }
  }

  @override
  void dispose() {
    if (!_isWeb) {
      WidgetsBinding.instance
          .removeObserver(this); // Unsubscribe lifecycle observer
      // SonarController stop is now handled centrally in MainScreenWrapper
      _unleashController.dispose();
      _discoveryController.dispose();
      _statusSubscription?.cancel(); // Cancel status listener
      _syncTimer?.cancel(); // Cancel auto-sync timer
      _connectivitySubscription?.cancel(); // Cancel connectivity listener
    }
    super.dispose();
  }

  // --- App Lifecycle Handling (Simplified) ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // We only need this here now for the battery dialog check potentially,
    // or screen-specific resume logic if any. Core Sonar/Sync resume is handled higher up.
    if (_isWeb) return;
    if (state == AppLifecycleState.resumed) {
      // Re-check hardware state on resume to update UI chip if needed
      _syncHardwareStateUI();
      // Potentially re-trigger battery check if user went to settings?
      // _checkAndShowBatteryOptimizationDialog();
    }
  }

  // --- Status and UI Synchronization ---

  // Handles status updates from BluetoothStatusService to update UI state
  void _handleStatusUpdate(NearbyStatus status) {
    if (mounted) {
      setState(() {
        // Update UI enable state based on service status
        _isBluetoothHardwareEnabled = status != NearbyStatus.adapterOff &&
            status != NearbyStatus.permissionsDenied &&
            status != NearbyStatus.permissionsPermanentlyDenied &&
            status != NearbyStatus.error; // Include error state
        // Trigger discovery ripple animation when a user is found
        if (status == NearbyStatus.userFound) {
          _discoveryController.forward(from: 0.0);
        }
      });
    }
  }

  // Syncs the UI chip based on current hardware status (called on resume)
  Future<void> _syncHardwareStateUI() async {
    if (_isWeb) return;
    // We rely on the BluetoothStatusService's stream listener mostly,
    // but this ensures the chip is correct immediately on resume.
    _handleStatusUpdate(BluetoothStatusService().currentStatus);
  }

  // --- Permission Handling ---

  // Handle tap on "Grant Permissions" button
  Future<void> _handlePermissionRequest() async {
    debugPrint(
        "NearbyScreen: Handling permission request via SonarController.startSonar()");
    // Triggering startSonar will automatically handle the permission request flow
    // and update the status via BluetoothStatusService if permissions change.
    await _sonarController.startSonar();
    // Update local UI state based on potential status change from startSonar
    _handleStatusUpdate(BluetoothStatusService().currentStatus);
  }

  // --- Data Fetching & User Actions ---

  // Fetch current user photo for the center avatar
  Future<void> _fetchCurrentUserPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final ServerUserModel.UserModel userModel =
            await _userRepository.getUser(user.uid);
        if (mounted) setState(() => _currentUserPhotoUrl = userModel.photoUrl);
      } catch (e) {
        debugPrint("NearbyScreen: Error fetching current user photo: $e");
        if (mounted) setState(() => _currentUserPhotoUrl = ''); // Fallback
      }
    } else {
      if (mounted) setState(() => _currentUserPhotoUrl = ''); // Fallback
    }
  }

  // Show confirmation dialog before removing a discovered user
  void _deleteFoundUser(String uidShort) {
    String? profileId = _localCacheService.getNearbyUser(uidShort)?.profileId;
    String username = "User (${uidShort.substring(0, 4)})";
    if (profileId != null) {
      username = _localCacheService.getUserProfile(profileId)?.name ?? username;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Remove $username?"),
        content: const Text("This user can be discovered again later."),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              _localCacheService.pruneSpecificUser(uidShort);
              Navigator.of(ctx).pop();
            },
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  // --- Connectivity Monitoring ---
  void _startConnectivityMonitoring() {
    if (_isWeb) return;
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      final bool wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      if (mounted) {
        setState(() {});
      }

      // If device came back online and there are unsynced profiles, trigger sync
      if (!wasOnline && _isOnline && _unsyncedCount > 0) {
        debugPrint(
            "NearbyScreen: Device came back online, triggering sync for $_unsyncedCount unsynced profiles");
        _triggerProfileSync();
      }
    });
  }

  // --- Auto-Sync Methods ---
  void _startAutoSync() {
    if (_isWeb) return;
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkAndSyncUnsyncedProfiles();
    });
  }

  Future<void> _checkAndSyncUnsyncedProfiles() async {
    if (_isWeb || _isSyncing || !_isOnline) return;

    try {
      // Count unsynced profiles
      final nearbyUsers =
          _localCacheService.getNearbyUsersListenable().value.values.toList();
      int unsyncedCount = 0;

      for (final nearbyUser in nearbyUsers) {
        if (nearbyUser.profileId == null || nearbyUser.profileId!.isEmpty) {
          unsyncedCount++;
        }
      }

      if (mounted) {
        setState(() {
          _unsyncedCount = unsyncedCount;
        });
      }

      // If there are unsynced profiles and we're online, trigger sync
      if (unsyncedCount > 0 && _isOnline) {
        await _triggerProfileSync();
      }
    } catch (e) {
      debugPrint("NearbyScreen: Error checking unsynced profiles: $e");
    }
  }

  Future<void> _triggerProfileSync() async {
    if (_isWeb || _isSyncing || !_isOnline) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      await _syncManager.triggerManualSync();
    } catch (e) {
      debugPrint("NearbyScreen: Error during profile sync: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  // --- Manual Sync Trigger ---

  // --- Battery Optimization Dialog (MIUI/Redmi Enhanced) ---
  Future<void> _checkAndShowBatteryOptimizationDialog() async {
    if (!mounted ||
        !Platform.isAndroid ||
        _settingsBox.get('hasSeenBatteryDialog', defaultValue: false)) return;

    // Use the new MIUI Permission Helper
    final miuiHelper = MiuiPermissionHelper();
    final deviceInfo = DeviceInfoHelper();
    await deviceInfo.initialize();

    // Check if battery optimization is enabled
    final isBatteryOptimized = await miuiHelper.isBatteryOptimizationEnabled();

    // Show dialog if battery optimization is enabled and device has aggressive optimization
    if (isBatteryOptimized && deviceInfo.hasAggressiveBatteryOptimization) {
      if (mounted) {
        await miuiHelper.showMiuiPermissionGuide(context);
      }
    }

    await _settingsBox.put('hasSeenBatteryDialog', true);
  }

  // --- Get Status Message ---
  // Determines the text shown below the Sonar animation
  String _getStatusMessage(NearbyState state) {
    // Prioritize hardware/permission issues reported by the StatusService
    final currentServiceStatus = BluetoothStatusService().currentStatus;
    if (currentServiceStatus == NearbyStatus.permissionsPermanentlyDenied)
      return "Enable Permissions in Settings.";
    if (currentServiceStatus == NearbyStatus.permissionsDenied)
      return "Enable Permissions to start.";
    if (currentServiceStatus == NearbyStatus.adapterOff)
      return "Enable Bluetooth to start.";

    // Use BLoC state for operational status
    if (state is NearbyError) {
      // Check if it's a Xiaomi advertising error
      if (state.message.contains('18') ||
          state.message.contains('advertising')) {
        return "Xiaomi device detected - Check battery optimization settings";
      }
      return state.message; // Show specific error from BLoC if any
    }
    if (state is NearbyActive) {
      // Sonar is running
      if (currentServiceStatus == NearbyStatus.scanning) {
        // Check if we're in scan-only mode (can't advertise)
        try {
          final advertiser = locator<BleAdvertiser>();
          if (advertiser.isScanOnlyMode) {
            return "Scan-only mode - Can find others but not discoverable";
          }
        } catch (e) {
          // If we can't access the advertiser, assume normal mode
        }
        return "Actively searching..."; // Use service status
      }
      if (currentServiceStatus == NearbyStatus.userFound)
        return "Discovery active..."; // Use service status
    }
    // Default/Idle state message
    return "Tap your picture to begin scanning."; // Updated idle message
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    // Show placeholder on web
    if (_isWeb) return const _WebPlaceholder();

    // Use BlocConsumer to react to state changes and build UI
    return Scaffold(
      // CRITICAL: Explicit background color to prevent black screen during transitions
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocConsumer<NearbyBloc, NearbyState>(
        listener: (context, state) {
          // Optional: Add listeners for specific state transitions if needed
        },
        builder: (context, state) {
          final currentServiceStatus = BluetoothStatusService().currentStatus;
          Widget bodyContent;

          // Build UI based on permission/hardware status first
          if (currentServiceStatus ==
              NearbyStatus.permissionsPermanentlyDenied) {
            bodyContent = _PermissionDeniedState(isPermanentlyDenied: true);
          } else if (currentServiceStatus == NearbyStatus.permissionsDenied) {
            bodyContent =
                _PermissionDeniedState(onRetry: _handlePermissionRequest);
          }
          // Handle BLoC error state (unless it's already covered by hardware/permission state)
          else if (state is NearbyError &&
              currentServiceStatus != NearbyStatus.adapterOff) {
            bodyContent = _ErrorState(
              message: state.message,
              onRetry: () async {
                await _sonarController.startSonar(); // Retry starting
                _handleStatusUpdate(
                    BluetoothStatusService().currentStatus); // Update UI
              },
            );
          }
          // Otherwise, build the main Nearby UI
          else {
            bodyContent = _buildFullScreenSonar(context, state);
          }
          // Animate transitions between permission/error/main UI states
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child:
                bodyContent, // Switch between the different body content widgets
          );
        },
      ),
    );
  }

  // --- Helper Build Methods ---

  // Build full-screen sonar layout with professional components
  Widget _buildFullScreenSonar(BuildContext context, NearbyState state) {
    bool isScanningActive = state is NearbyActive;
    int userCount = _getUserCount();

    return Column(
      children: [
        // Professional Top Status Bar
        Padding(
          padding: EdgeInsets.fromLTRB(
            DesignTokens.spaceLG,
            MediaQuery.of(context).padding.top + DesignTokens.spaceLG,
            DesignTokens.spaceLG,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: ProfessionalStatusChip(
                  label: "Bluetooth",
                  icon: Icons.bluetooth,
                  isActive: _isBluetoothHardwareEnabled,
                  onTap: () => AppSettings.openAppSettings(
                    type: AppSettingsType.bluetooth,
                  ),
                ),
              ),
              SizedBox(width: DesignTokens.spaceMD),
              Expanded(
                child: ProfessionalStatusChip(
                  label: "Rankings",
                  icon: Icons.leaderboard_outlined,
                  isActive: false, // Disabled
                ),
              ),
            ],
          ),
        ),

        // Professional Sonar Area with Glassmorphism
        Expanded(
          child: ProfessionalGlassmorphicContainer(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.all(DesignTokens.spaceLG),
            borderRadius: DesignTokens.radiusLG,
            blurIntensity: DesignTokens.blurMedium,
            child: GestureDetector(
              onTap: () => _handleSonarToggle(isScanningActive),
              child: SonarView(
                isScanning: isScanningActive,
                unleashController: _unleashController,
                discoveryController: _discoveryController,
                centerAvatar: _buildProfessionalCenterAvatar(isScanningActive),
                foundUserAvatars: const [], // Empty for now
              ),
            ),
          ),
        ),

        // Professional Bottom Status and Controls
        Padding(
          padding: EdgeInsets.fromLTRB(
            DesignTokens.spaceLG,
            DesignTokens.spaceMD,
            DesignTokens.spaceLG,
            MediaQuery.of(context).padding.bottom + DesignTokens.spaceLG,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status message with better typography
              Text(
                _getStatusMessage(state),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.8),
                      fontSize: DesignTokens.fontSizeMD,
                      fontWeight: FontWeight.w500,
                      height: DesignTokens.lineHeightNormal,
                    ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: DesignTokens.spaceLG),

              // Found users section - always show if users exist in cache
              if (userCount > 0) _buildProfessionalFoundUsersSection(),
            ],
          ),
        ),
      ],
    );
  }

  // Build professional center avatar with enhanced glassmorphism
  Widget _buildProfessionalCenterAvatar(bool isScanningActive) {
    return Container(
      width: DesignTokens.avatarSizeLarge,
      height: DesignTokens.avatarSizeLarge,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: isScanningActive
            ? [
                BoxShadow(
                  color: SonarPulseTheme.primaryAccent.withOpacity(0.6),
                  blurRadius: DesignTokens.elevation4,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: SonarPulseTheme.primaryAccent.withOpacity(0.3),
                  blurRadius: DesignTokens.elevation4 * 2,
                  spreadRadius: 6,
                ),
              ]
            : DesignTokens.shadowMedium,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Enhanced glassmorphic border
          Container(
            width: DesignTokens.avatarSizeLarge,
            height: DesignTokens.avatarSizeLarge,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: DesignTokens.glassmorphicGradient,
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: Center(
              child: ClipOval(
                child: _currentUserPhotoUrl != null &&
                        _currentUserPhotoUrl!.isNotEmpty
                    ? Image(
                        image:
                            CachedNetworkImageProvider(_currentUserPhotoUrl!),
                        width: DesignTokens.avatarSizeLarge - 8,
                        height: DesignTokens.avatarSizeLarge - 8,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: DesignTokens.avatarSizeLarge - 8,
                          height: DesignTokens.avatarSizeLarge - 8,
                          color: Theme.of(context).colorScheme.surface,
                          child: Icon(
                            Icons.person,
                            size: DesignTokens.iconXL,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      )
                    : Container(
                        width: DesignTokens.avatarSizeLarge - 8,
                        height: DesignTokens.avatarSizeLarge - 8,
                        color: Theme.of(context).colorScheme.surface,
                        child: Icon(
                          Icons.person,
                          size: DesignTokens.iconXL,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build professional found users section
  Widget _buildProfessionalFoundUsersSection() {
    return ValueListenableBuilder<Box<NearbyUser>>(
      valueListenable: _localCacheService.getNearbyUsersListenable(),
      builder: (context, nearbyBox, _) {
        final nearbyUsers = nearbyBox.values.toList()
          ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

        if (nearbyUsers.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            // Professional header with count and expand button
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceLG,
                vertical: DesignTokens.spaceSM,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: DesignTokens.iconMD,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: DesignTokens.spaceSM),
                      Text(
                        'Found ${nearbyUsers.length} User${nearbyUsers.length > 1 ? 's' : ''}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onBackground,
                              fontSize: DesignTokens.fontSizeLG,
                            ),
                      ),
                      if (_unsyncedCount > 0) ...[
                        SizedBox(width: DesignTokens.spaceSM),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceSM,
                            vertical: DesignTokens.spaceXS,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusSM),
                          ),
                          child: Text(
                            '${_unsyncedCount} syncing...',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: DesignTokens.fontSizeXS,
                                    ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isFoundUsersExpanded = !_isFoundUsersExpanded;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(DesignTokens.spaceSM),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusXL),
                      ),
                      child: Icon(
                        _isFoundUsersExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Theme.of(context).colorScheme.primary,
                        size: DesignTokens.iconMD,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Professional horizontal scrollable avatar list (only when expanded)
            if (_isFoundUsersExpanded)
              SizedBox(
                height: DesignTokens.spaceXXXL * 1.5,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding:
                      EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
                  itemCount: nearbyUsers.length,
                  itemBuilder: (context, index) {
                    final nearbyUser = nearbyUsers[index];
                    return _buildProfessionalUserAvatar(nearbyUser, index);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  // Build professional user avatar for horizontal grid
  Widget _buildProfessionalUserAvatar(NearbyUser nearbyUser, int index) {
    return ValueListenableBuilder<Box<UserProfile>>(
      valueListenable: Hive.box<UserProfile>('userProfiles').listenable(
        keys: nearbyUser.profileId != null ? [nearbyUser.profileId!] : null,
      ),
      builder: (context, profileBox, _) {
        final userProfile = nearbyUser.profileId != null
            ? _localCacheService.getUserProfile(nearbyUser.profileId!)
            : null;

        final bool isProfileSynced = userProfile != null;
        final bool isNew =
            DateTime.now().difference(nearbyUser.lastSeen).inSeconds < 60;

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 100)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Transform.rotate(
                angle: (1 - value) * 0.1,
                child: Opacity(
                  opacity: value,
                  child: GestureDetector(
                    onTap: () => _showFoundUsersBottomSheet(context),
                    child: Container(
                      width: DesignTokens.spaceXXXL * 1.2,
                      margin: EdgeInsets.only(right: DesignTokens.spaceMD),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Professional avatar with indicators
                          SizedBox(
                            width: DesignTokens.spaceXXXL,
                            height: DesignTokens.spaceXXXL,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: DesignTokens.spaceXXXL / 2,
                                  backgroundColor:
                                      Theme.of(context).colorScheme.surface,
                                  backgroundImage:
                                      userProfile?.photoUrl != null &&
                                              userProfile!.photoUrl.isNotEmpty
                                          ? CachedNetworkImageProvider(
                                              userProfile.photoUrl)
                                          : null,
                                  child: userProfile?.photoUrl == null ||
                                          userProfile!.photoUrl.isEmpty
                                      ? _buildGenderPlaceholderIcon(
                                          size: DesignTokens.spaceXXXL / 2)
                                      : null,
                                ),
                                // Sync status indicator
                                if (!isProfileSynced)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: DesignTokens.spaceMD,
                                      height: DesignTokens.spaceMD,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: Icon(
                                        Icons.cloud_download_outlined,
                                        size: DesignTokens.iconXS,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                // New indicator
                                if (isNew)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: DesignTokens.spaceMD,
                                      height: DesignTokens.spaceMD,
                                      decoration: BoxDecoration(
                                        color: DesignTokens.successColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.fiber_new,
                                        size: DesignTokens.iconXS,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(height: DesignTokens.spaceXS),
                          // Username text with better constraints
                          SizedBox(
                            width: DesignTokens.spaceXXXL * 1.2,
                            height: DesignTokens.spaceMD,
                            child: Text(
                              userProfile?.name ??
                                  "User ${nearbyUser.uidShort.substring(0, 4)}",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontSize: DesignTokens.fontSizeXS,
                                    fontWeight: FontWeight.w500,
                                    height: DesignTokens.lineHeightTight,
                                  ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Handle sonar toggle logic
  void _handleSonarToggle(bool isScanningActive) {
    HapticFeedback.lightImpact();

    if (!_isBluetoothHardwareEnabled) {
      // If hardware/permissions are off, guide user instead of trying to start
      final currentStatus = BluetoothStatusService().currentStatus;
      if (currentStatus == NearbyStatus.adapterOff) {
        AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
      } else if (currentStatus == NearbyStatus.permissionsDenied) {
        _handlePermissionRequest(); // Ask for permissions
      } else if (currentStatus == NearbyStatus.permissionsPermanentlyDenied) {
        AppSettings.openAppSettings(
            type: AppSettingsType.settings); // Open app settings
      }
      return;
    }

    // If hardware/perms OK, toggle the Sonar state via SonarController
    if (!isScanningActive) {
      _unleashController.forward(from: 0.0); // Play unleash animation
      _sonarController.startSonar(); // Tell controller to start

      // For Xiaomi devices, show additional guidance
      _showXiaomiDiscoveryTips();
    } else {
      _sonarController.stopSonar(); // Tell controller to stop
    }
    // UI state update will happen via the BluetoothStatusService listener
  }

  // Show discovery tips for first-time users only
  void _showXiaomiDiscoveryTips() {
    // Check if this is a Xiaomi device and if user hasn't seen tips before
    if (Platform.isAndroid) {
      // Check if user has seen the discovery tips before
      final hasSeenTips =
          _settingsBox.get('hasSeenDiscoveryTips', defaultValue: false);

      if (!hasSeenTips) {
        // Show a helpful dialog for better discovery
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('💡 Discovery Tips'),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('For better discovery:'),
                    SizedBox(height: 8),
                    Text('1. Keep devices within 1-2 meters'),
                    Text('2. Wait 10-15 seconds for discovery'),
                    Text('3. Try moving devices closer together'),
                    Text('4. Ensure both devices are scanning'),
                    SizedBox(height: 8),
                    Text(
                        'Note: Some devices may have limited discoverability due to manufacturer restrictions.'),
                    SizedBox(height: 8),
                    Text(
                        '💡 Tip: You can start a new scan anytime by tapping the button again!'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      // Mark that user has seen the tips
                      _settingsBox.put('hasSeenDiscoveryTips', true);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Got it'),
                  ),
                ],
              ),
            );
          }
        });
      }
    }
  }

  // Get user count for display
  int _getUserCount() {
    try {
      final nearbyBox = _localCacheService.getNearbyUsersListenable();
      return nearbyBox.value.values.length;
    } catch (e) {
      return 0;
    }
  }

  // Show found users bottom sheet with professional design
  void _showFoundUsersBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return BlocProvider.value(
          value: BlocProvider.of<FriendsBloc>(context),
          child: _ProfessionalFoundUsersModal(
            localCacheService: _localCacheService,
            onDeleteUser: _deleteFoundUser,
            onStartScanning: () => _handleSonarToggle(false),
          ),
        );
      },
    );
  }

  // Build gender placeholder icon
  Widget _buildGenderPlaceholderIcon({double size = 40}) {
    return Icon(
      Icons.person_outline,
      size: size,
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
    );
  }
} // End _NearbyScreenViewState

class _PermissionDeniedState extends StatelessWidget {
  final VoidCallback? onRetry; // Callback to request permissions again
  final bool isPermanentlyDenied;
  const _PermissionDeniedState(
      {this.onRetry, this.isPermanentlyDenied = false});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.orange),
            const SizedBox(height: 16),
            const Text("Permissions Required",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                isPermanentlyDenied
                    ? "You've permanently denied permissions. Please enable them in your device settings to use this feature."
                    : "This feature needs Bluetooth and Location permissions to discover people.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            // Show "Grant Permissions" button only if not permanently denied
            if (!isPermanentlyDenied && onRetry != null)
              ElevatedButton(
                  onPressed: onRetry, child: const Text('Grant Permissions')),
            // Always show "Open Settings" button
            TextButton(
                onPressed: () =>
                    AppSettings.openAppSettings(type: AppSettingsType.settings),
                child: const Text('Open Settings')),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

class _WebPlaceholder extends StatelessWidget {
  const _WebPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // CRITICAL: Explicit background color to prevent black screen
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.radar_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 24),
              Text('Feature Not Available on Web',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text(
                  'The Nearby feature uses device Bluetooth and is only available on the mobile app.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// Professional Found Users Modal with 40 improvements
class _ProfessionalFoundUsersModal extends StatefulWidget {
  final LocalCacheService localCacheService;
  final Function(String) onDeleteUser;
  final VoidCallback onStartScanning;

  const _ProfessionalFoundUsersModal({
    required this.localCacheService,
    required this.onDeleteUser,
    required this.onStartScanning,
  });

  @override
  State<_ProfessionalFoundUsersModal> createState() =>
      _ProfessionalFoundUsersModalState();
}

class _ProfessionalFoundUsersModalState
    extends State<_ProfessionalFoundUsersModal> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _staggerController;
  late AnimationController _refreshController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late List<Animation<double>> _staggerAnimations;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: DesignTokens.durationSlow,
      vsync: this,
    );
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: DesignTokens.curveEaseOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: DesignTokens.curveEaseOut,
    ));

    // Stagger animations for content elements
    _staggerAnimations = List.generate(5, (index) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _staggerController,
        curve: Interval(
          index * 0.15,
          1.0,
          curve: DesignTokens.curveEaseOut,
        ),
      ));
    });

    _entranceController.forward();
    _staggerController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _staggerController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);
    HapticFeedback.lightImpact();

    _refreshController.forward();

    try {
      final syncManager = locator<SyncManager>();
      await syncManager.triggerManualSync();

      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Sync error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
        _refreshController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(0.98),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(DesignTokens.radiusXXL),
                topRight: Radius.circular(DesignTokens.radiusXXL),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 25,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Drag Handle
                Positioned(
                  top: DesignTokens.spaceMD,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),

                // Main Content
                Positioned(
                  top: DesignTokens.spaceXL,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.all(DesignTokens.spaceLG)
                              .copyWith(bottom: DesignTokens.spaceXXXL),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header with Animation
                              FadeTransition(
                                opacity: _staggerAnimations[0],
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.2),
                                    end: Offset.zero,
                                  ).animate(_staggerAnimations[0]),
                                  child: _buildHeader(context),
                                ),
                              ),

                              SizedBox(height: DesignTokens.spaceLG),

                              // Refresh and Sync Section with Animation
                              FadeTransition(
                                opacity: _staggerAnimations[1],
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.2),
                                    end: Offset.zero,
                                  ).animate(_staggerAnimations[1]),
                                  child: _buildRefreshSection(context),
                                ),
                              ),

                              SizedBox(height: DesignTokens.spaceLG),

                              // User Grid with Animation
                              FadeTransition(
                                opacity: _staggerAnimations[2],
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.2),
                                    end: Offset.zero,
                                  ).animate(_staggerAnimations[2]),
                                  child: _buildUserGrid(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Close Button
                Positioned(
                  top: DesignTokens.spaceMD,
                  right: DesignTokens.spaceMD,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusSM),
                      child: Container(
                        padding: EdgeInsets.all(DesignTokens.spaceSM),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .scaffoldBackgroundColor
                              .withOpacity(0.9),
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusSM),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                            width: 0.5,
                          ),
                          boxShadow: DesignTokens.shadowLight,
                        ),
                        child: Icon(
                          Icons.close,
                          size: DesignTokens.iconMD,
                          color: Theme.of(context).iconTheme.color,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ValueListenableBuilder<Box<NearbyUser>>(
      valueListenable: widget.localCacheService.getNearbyUsersListenable(),
      builder: (context, nearbyBox, _) {
        final nearbyUsers = nearbyBox.values.toList();
        final userCount = nearbyUsers.length;

        return Container(
          padding: EdgeInsets.all(DesignTokens.spaceLG),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
            boxShadow: DesignTokens.shadowLight,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(DesignTokens.spaceMD),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                ),
                child: Icon(
                  Icons.people_outline,
                  size: DesignTokens.iconLG,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(width: DesignTokens.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nearby Users',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: DesignTokens.fontSizeXL,
                                letterSpacing: DesignTokens.letterSpacingTight,
                              ),
                    ),
                    SizedBox(height: DesignTokens.spaceXS),
                    Text(
                      userCount == 0
                          ? 'No users discovered yet'
                          : '$userCount ${userCount == 1 ? 'person' : 'people'} discovered nearby',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: DesignTokens.fontSizeMD,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMD,
                  vertical: DesignTokens.spaceSM,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '$userCount',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: DesignTokens.fontSizeLG,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRefreshSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.spaceLG),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
        boxShadow: DesignTokens.shadowLight,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.spaceMD),
            decoration: BoxDecoration(
              color: _isSyncing
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Theme.of(context).dividerColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            ),
            child: AnimatedBuilder(
              animation: _refreshController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _refreshController.value * 2 * 3.14159,
                  child: Icon(
                    _isSyncing ? Icons.sync : Icons.sync_outlined,
                    size: DesignTokens.iconLG,
                    color: _isSyncing
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).iconTheme.color?.withOpacity(0.6),
                  ),
                );
              },
            ),
          ),
          SizedBox(width: DesignTokens.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSyncing ? 'Syncing Profiles...' : 'Sync Profiles',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: DesignTokens.fontSizeMD,
                      ),
                ),
                SizedBox(height: DesignTokens.spaceXS),
                Text(
                  _isSyncing
                      ? 'Updating user information...'
                      : 'Refresh user profiles from server',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: DesignTokens.fontSizeSM,
                      ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isSyncing ? null : _handleRefresh,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceLG,
                  vertical: DesignTokens.spaceMD,
                ),
                decoration: BoxDecoration(
                  color: _isSyncing
                      ? Theme.of(context).dividerColor.withOpacity(0.3)
                      : Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                ),
                child: Text(
                  _isSyncing ? 'Syncing...' : 'Sync',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _isSyncing
                            ? Theme.of(context).textTheme.bodySmall?.color
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: DesignTokens.fontSizeSM,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGrid(BuildContext context) {
    return ValueListenableBuilder<Box<NearbyUser>>(
      valueListenable: widget.localCacheService.getNearbyUsersListenable(),
      builder: (context, nearbyBox, _) {
        final nearbyUsers = nearbyBox.values.toList()
          ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

        if (nearbyUsers.isEmpty) {
          return _buildEmptyState(context);
        }

        return _buildUserCards(nearbyUsers);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.spaceXXXL),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
        boxShadow: DesignTokens.shadowLight,
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.spaceXL),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: DesignTokens.iconXXL,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: DesignTokens.spaceLG),
          Text(
            'No Users Nearby',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: DesignTokens.fontSizeXL,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: DesignTokens.spaceMD),
          Text(
            'Keep scanning to discover people around you. Make sure Bluetooth is enabled and you\'re in a populated area.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: DesignTokens.fontSizeMD,
                  height: DesignTokens.lineHeightNormal,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: DesignTokens.spaceLG),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceLG,
                  vertical: DesignTokens.spaceMD,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                ),
                elevation: DesignTokens.elevation2,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                widget.onStartScanning();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.radar,
                    size: DesignTokens.iconSM,
                  ),
                  SizedBox(width: DesignTokens.spaceSM),
                  Text(
                    'Start Scanning',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: DesignTokens.fontSizeMD,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCards(List<NearbyUser> nearbyUsers) {
    final userCards = nearbyUsers.map((nearbyUser) {
      return ValueListenableBuilder<Box<UserProfile>>(
        valueListenable: Hive.box<UserProfile>('userProfiles').listenable(
          keys: nearbyUser.profileId != null ? [nearbyUser.profileId!] : null,
        ),
        builder: (context, profileBox, _) {
          final userProfile = nearbyUser.profileId != null
              ? widget.localCacheService.getUserProfile(nearbyUser.profileId!)
              : null;

          // Create temporary UserModel from combined local data
          final displayUser = ServerUserModel.UserModel(
            id: nearbyUser.profileId ?? nearbyUser.uidShort,
            username: userProfile?.name ?? 'User ${nearbyUser.uidShort}',
            email: '', // UserProfile doesn't have email
            photoUrl: userProfile?.photoUrl ?? '',
            age: 0, // UserProfile doesn't have age
            gender: userProfile?.gender ?? '',
            country: '', // UserProfile doesn't have country
            interests: userProfile?.interests ?? [],
            friends: userProfile?.friends ?? [],
            friendRequestsSent: userProfile?.friendRequestsSent ?? [],
            friendRequestsReceived: userProfile?.friendRequestsReceived ?? [],
            nearbyStatusMessage: userProfile?.nearbyStatusMessage ?? '',
            nearbyStatusEmoji: userProfile?.nearbyStatusEmoji ?? '',
            lastSeen: nearbyUser.lastSeen,
            createdAt: DateTime.now(),
            lastFreeSuperLike: DateTime.now(),
            lastNearbyDiscoveryDate: DateTime.now(),
          );

          // Calculate estimated RSSI based on last seen time
          final now = DateTime.now();
          final minutesSinceLastSeen =
              now.difference(nearbyUser.lastSeen).inMinutes;
          int estimatedRssi = -80; // Default poor signal
          if (minutesSinceLastSeen < 1) {
            estimatedRssi = -50; // Excellent
          } else if (minutesSinceLastSeen < 5) {
            estimatedRssi = -60; // Good
          } else if (minutesSinceLastSeen < 15) {
            estimatedRssi = -70; // Fair
          }

          // Check if profile is synced
          final isProfileSynced =
              nearbyUser.profileId != null && nearbyUser.profileId!.length > 8;

          // NEW badge: Recently found (last 60 seconds)
          final timeSinceFound = now.difference(nearbyUser.foundAt).inSeconds;
          bool isNew = (timeSinceFound < 60);

          // ACTIVE badge: Recently active (last 5 minutes)
          bool isRecentlyActive =
              (now.difference(nearbyUser.lastSeen).inMinutes < 5);

          return RepaintBoundary(
            child: ProfessionalUserCard(
              key: ValueKey(nearbyUser.uidShort),
              username: displayUser.username,
              photoUrl: displayUser.photoUrl,
              statusMessage: displayUser.nearbyStatusMessage,
              genderValue: nearbyUser.gender,
              isNew: isNew,
              isRecentlyActive: isRecentlyActive,
              isProfileSynced: isProfileSynced,
              rssi: estimatedRssi,
              userModel: displayUser,
              onTap: () => locator<NavigationService>().navigateTo(
                  ProfileScreen(userId: displayUser.id),
                  transition: PageTransition.slide),
              onDelete: () => widget.onDeleteUser(nearbyUser.uidShort),
            ),
          );
        },
      );
    }).toList();

    return ProfessionalResponsiveGrid(
      children: userCards,
      padding: EdgeInsets.all(DesignTokens.spaceLG),
    );
  }
}
