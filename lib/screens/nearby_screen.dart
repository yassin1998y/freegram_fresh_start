// lib/screens/nearby_screen.dart
import 'dart:async';
import 'dart:io'; // For Platform check
import 'package:app_settings/app_settings.dart';
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
import 'package:freegram/repositories/friend_repository.dart';
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
import 'package:freegram/models/user_model.dart' as server_user_model; // Alias
import 'package:freegram/services/navigation_service.dart';
// Screens
import 'package:freegram/screens/profile_screen.dart';
// Widgets
import 'package:freegram/widgets/sonar_view.dart';
import 'package:freegram/widgets/sonar_user_card.dart';
import 'package:freegram/widgets/core/user_avatar.dart';
import 'package:freegram/widgets/responsive_system.dart';
import 'package:freegram/theme/app_theme.dart'; // For SonarPulseTheme
import 'package:freegram/theme/design_tokens.dart';
// Other Utils
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// --- Main StatelessWidget Wrapper ---
// Provides BLoCs needed by this screen and its children
class NearbyScreen extends StatelessWidget {
  final bool isVisible;
  const NearbyScreen({super.key, this.isVisible = true});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // NearbyBloc listens to BluetoothStatusService for UI state
        BlocProvider(create: (context) => NearbyBloc()),
        // FriendsBloc needed for actions within NearbyUserCard's modal
        BlocProvider(
          create: (context) => FriendsBloc(
              userRepository: locator<UserRepository>(),
              friendRepository: locator<FriendRepository>())
            ..add(LoadFriends()),
        ),
      ],
      child:
          _NearbyScreenView(isVisible: isVisible), // The main stateful widget
    );
  }
}

// --- Main StatefulWidget View ---
// Handles UI state, animations, and interacts with services/Blocs
class _NearbyScreenView extends StatefulWidget {
  final bool isVisible;
  const _NearbyScreenView({required this.isVisible});
  @override
  State<_NearbyScreenView> createState() => _NearbyScreenViewState();
}

// Keep WidgetsBindingObserver for app lifecycle and battery optimization check
class _NearbyScreenViewState extends State<_NearbyScreenView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Get service instances via locator
  late final SonarController _sonarController;
  late final LocalCacheService _localCacheService;
  final UserRepository _userRepository = locator<UserRepository>();
  late final SyncManager _syncManager;
  final Box _settingsBox = Hive.box('settings');

  // UI State Variables
  bool _isBluetoothHardwareEnabled =
      false; // Tracks UI state based on Service status
  late AnimationController
      _unleashController; // Animation for sonar start pulse
  late AnimationController
      _discoveryController; // Animation for user found pulse
  late AnimationController
      _radarRotationController; // Animation for rotating radar glow
  String? _currentUserPhotoUrl; // For the center avatar
  String? _currentUserBadgeUrl; // For the center avatar
  final bool _isWeb = kIsWeb; // Check if running on web
  StreamSubscription?
      _statusSubscription; // Subscription to shared BluetoothStatusService
  int _lastUserCount = 0; // State to track user count for haptic feedback

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
    debugPrint('📱 SCREEN: nearby_screen.dart');
    if (!_isWeb) {
      _sonarController = locator<SonarController>();
      _localCacheService = locator<LocalCacheService>();
      _syncManager = locator<SyncManager>();
      WidgetsBinding.instance.addObserver(this); // Observe app lifecycle

      // Initialize animation controllers
      _unleashController = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 800));
      _discoveryController = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 600));
      _radarRotationController =
          AnimationController(vsync: this, duration: const Duration(seconds: 4))
            ..repeat();

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

      _localCacheService
          .getNearbyUsersListenable()
          .addListener(_onNearbyUsersChanged);
      _lastUserCount = _getUserCount();
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
      _radarRotationController.dispose();
      _statusSubscription?.cancel(); // Cancel status listener
      _syncTimer?.cancel(); // Cancel auto-sync timer
      _connectivitySubscription?.cancel(); // Cancel connectivity listener
      _localCacheService
          .getNearbyUsersListenable()
          .removeListener(_onNearbyUsersChanged);
    }
    super.dispose();
  }

  void _onNearbyUsersChanged() {
    final currentCount = _getUserCount();
    if (currentCount > _lastUserCount) {
      HapticFeedback.mediumImpact();
    }
    _lastUserCount = currentCount;
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
        final server_user_model.UserModel userModel =
            await _userRepository.getUser(user.uid);
        if (mounted) {
          setState(() {
            _currentUserPhotoUrl = userModel.photoUrl;
            _currentUserBadgeUrl = userModel.equippedBadgeUrl;
          });
        }
      } catch (e) {
        debugPrint("NearbyScreen: Error fetching current user photo: $e");
        if (mounted) {
          setState(() {
            _currentUserPhotoUrl = '';
            _currentUserBadgeUrl = null;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _currentUserPhotoUrl = '';
          _currentUserBadgeUrl = null;
        });
      }
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

  Future<void> _checkAndShowBatteryOptimizationDialog() async {
    if (!mounted ||
        kIsWeb ||
        !Platform.isAndroid ||
        _settingsBox.get('hasSeenBatteryDialog', defaultValue: false)) {
      return;
    }

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
  @override
  void didUpdateWidget(_NearbyScreenView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (!widget.isVisible) {
        // Pause active discovery tasks when screen is not visible
        if (_sonarController.isRunning) {
          _sonarController.stopSonar();
        }
      } else {
        // Optionally resume if it was running before?
        // For now, let user manually restart to save battery
      }
    }
  }

  String _getStatusMessage(NearbyState state) {
    // Prioritize hardware/permission issues reported by the StatusService
    final currentServiceStatus = BluetoothStatusService().currentStatus;
    if (currentServiceStatus == NearbyStatus.permissionsPermanentlyDenied) {
      return "Enable Permissions in Settings.";
    }
    if (currentServiceStatus == NearbyStatus.permissionsDenied) {
      return "Enable Permissions to start.";
    }
    if (currentServiceStatus == NearbyStatus.adapterOff) {
      return "Enable Bluetooth to start.";
    }

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
      if (currentServiceStatus == NearbyStatus.userFound) {
        return "Discovery active..."; // Use service status
      }
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

          // Build UI based on permission/hardware status first
          if (currentServiceStatus ==
              NearbyStatus.permissionsPermanentlyDenied) {
            return const _PermissionDeniedState(isPermanentlyDenied: true);
          } else if (currentServiceStatus == NearbyStatus.permissionsDenied) {
            return _PermissionDeniedState(onRetry: _handlePermissionRequest);
          }
          // Handle BLoC error state (unless it's already covered by hardware/permission state)
          else if (state is NearbyError &&
              currentServiceStatus != NearbyStatus.adapterOff) {
            return _ErrorState(
              message: state.message,
              onRetry: () async {
                await _sonarController.startSonar(); // Retry starting
                _handleStatusUpdate(
                    BluetoothStatusService().currentStatus); // Update UI
              },
            );
          }

          return _buildSliverDiscoveryView(context, state);
        },
      ),
    );
  }

  // --- Helper Build Methods ---

  Widget _buildSliverDiscoveryView(BuildContext context, NearbyState state) {
    bool isScanningActive = state is NearbyActive;
    int userCount = _getUserCount();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 1. Radar Badge Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: DesignTokens.spaceLG),
            child: _buildRadarBadge(),
          ),
        ),

        // 2. Sonar Scan Area
        SliverToBoxAdapter(
          child: Container(
            height:
                MediaQuery.of(context).size.width - (DesignTokens.spaceLG * 2),
            margin: const EdgeInsets.all(DesignTokens.spaceLG),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                width: 1.0,
              ),
            ),
            child: GestureDetector(
              onTap: () => _handleSonarToggle(isScanningActive),
              child: SonarView(
                isScanning: isScanningActive,
                unleashController: _unleashController,
                discoveryController: _discoveryController,
                centerAvatar: _buildCenterAvatar(isScanningActive),
                foundUserAvatars: const [], // Avatars pop in the grid below
              ),
            ),
          ),
        ),

        // 3. Status Information
        SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
            child: Column(
              children: [
                Text(
                  _getStatusMessage(state),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.8),
                        fontSize: DesignTokens.fontSizeMD,
                        fontWeight: FontWeight.w500,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.spaceLG),
              ],
            ),
          ),
        ),

        // 4. Recently Found Users (Sub-List)
        if (userCount > 0)
          SliverToBoxAdapter(
            child: _buildProfessionalFoundUsersSection(),
          ),

        // 5. Main Discovery Grid (Historical + New)
        _buildDiscoveredUsersGrid(isScanningActive),

        // Bottom Padding for Nav
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Widget _buildRadarBadge() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
          border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar, color: SonarPulseTheme.primaryAccent, size: 18),
            SizedBox(width: 8),
            Text(
              "Local Bluetooth Discovery",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCenterAvatar(bool isScanning) {
    return _buildProfessionalCenterAvatar(isScanning);
  }

  Widget _buildDiscoveredUsersGrid(bool isScanningActive) {
    return ValueListenableBuilder<Box<NearbyUser>>(
      valueListenable: _localCacheService.getNearbyUsersListenable(),
      builder: (context, nearbyBox, _) {
        final nearbyUsers = nearbyBox.values.toList()
          ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

        if (nearbyUsers.isEmpty) {
          if (isScanningActive) {
            return SliverToBoxAdapter(
              child: ProfessionalResponsiveGrid(
                padding: const EdgeInsets.all(DesignTokens.spaceLG),
                children:
                    List.generate(4, (index) => const SonarShimmerUserCard()),
              ),
            );
          }
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(),
          );
        }

        return SliverToBoxAdapter(
          child: ProfessionalResponsiveGrid(
            padding: const EdgeInsets.all(DesignTokens.spaceLG),
            children: nearbyUsers.map((user) {
              return _ProfessionalUserCardWrapper(
                user: user,
                onDelete: () => _deleteFoundUser(user.uidShort),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: DesignTokens.iconXXL,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          Text(
            "No nearby users found yet.",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: DesignTokens.spaceSM),
          Text(
            "Start scanning to discover people around you!",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Build professional center avatar with enhanced glassmorphism
  Widget _buildProfessionalCenterAvatar(bool isScanningActive) {
    return Container(
      width: AvatarSize.large.size,
      height: AvatarSize.large.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: isScanningActive
            ? [
                BoxShadow(
                  color: SonarPulseTheme.primaryAccent.withValues(alpha: 0.6),
                  blurRadius: DesignTokens.elevation4,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: SonarPulseTheme.primaryAccent.withValues(alpha: 0.3),
                  blurRadius: DesignTokens.elevation4 * 2,
                  spreadRadius: 6,
                ),
              ]
            : [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                  blurRadius: DesignTokens.elevation2,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Scanning Glow (Rotating)
          if (isScanningActive)
            RepaintBoundary(
              child: RotationTransition(
                turns: _radarRotationController,
                child: Container(
                  width: AvatarSize.large.size + 60,
                  height: AvatarSize.large.size + 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFF00BFA5).withValues(alpha: 0.05),
                        const Color(0xFF00BFA5).withValues(alpha: 0.3),
                        Colors.transparent
                      ],
                      stops: const [0.0, 0.3, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),

          // Use the standardized UserAvatar widget
          UserAvatar(
            url: _currentUserPhotoUrl,
            badgeUrl: _currentUserBadgeUrl,
            size: AvatarSize.large,
            borderWidth: 2,
            borderColor: Colors.white.withValues(alpha: 0.4),
            backgroundColor: Theme.of(context).colorScheme.surface,
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
              padding: const EdgeInsets.symmetric(
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
                      const SizedBox(width: DesignTokens.spaceSM),
                      Text(
                        'Found ${nearbyUsers.length} User${nearbyUsers.length > 1 ? 's' : ''}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: DesignTokens.fontSizeLG,
                            ),
                      ),
                      if (_unsyncedCount > 0) ...[
                        const SizedBox(width: DesignTokens.spaceSM),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceSM,
                            vertical: DesignTokens.spaceXS,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary, // Use secondary for sync indicator
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusSM),
                          ),
                          child: Text(
                            '$_unsyncedCount syncing...',
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
                      padding: const EdgeInsets.all(DesignTokens.spaceSM),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusXL),
                        border: Border.all(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.1),
                          width: 1.0,
                        ),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceLG),
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
                      margin:
                          const EdgeInsets.only(right: DesignTokens.spaceMD),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Professional avatar with indicators
                          SizedBox(
                            width: DesignTokens.spaceXXXL,
                            height: DesignTokens.spaceXXXL,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                UserAvatar(
                                  url: userProfile?.photoUrl,
                                  badgeUrl: userProfile?.equippedBadgeUrl,
                                  size: AvatarSize.medium,
                                  backgroundColor:
                                      Theme.of(context).colorScheme.surface,
                                ),
                                // Online Pulse (Brand Green)
                                if (isProfileSynced)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: SonarPulseTheme.primaryAccent
                                              .withValues(alpha: 0.3),
                                          width: 2,
                                        ),
                                      ),
                                    ),
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
                                      child: const Icon(
                                        Icons.cloud_download_outlined,
                                        size: DesignTokens.iconXS,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                // New indicator (Brand Green)
                                if (isNew)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: DesignTokens.spaceMD,
                                      height: DesignTokens.spaceMD,
                                      decoration: BoxDecoration(
                                        color: SonarPulseTheme.primaryAccent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.fiber_new,
                                        size: DesignTokens.iconSM,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceXS),
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
                    SizedBox(height: DesignTokens.spaceSM),
                    Text('1. Keep devices within 1-2 meters'),
                    Text('2. Wait 10-15 seconds for discovery'),
                    Text('3. Try moving devices closer together'),
                    Text('4. Ensure both devices are scanning'),
                    SizedBox(height: DesignTokens.spaceSM),
                    Text(
                        'Note: Some devices may have limited discoverability due to manufacturer restrictions.'),
                    SizedBox(height: DesignTokens.spaceSM),
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
        });
  }

  Widget _ProfessionalUserCardWrapper({
    required NearbyUser user,
    required VoidCallback onDelete,
  }) {
    return ValueListenableBuilder<Box<UserProfile>>(
      valueListenable: Hive.box<UserProfile>('userProfiles').listenable(
        keys: user.profileId != null ? [user.profileId!] : null,
      ),
      builder: (context, profileBox, _) {
        final userProfile = user.profileId != null
            ? _localCacheService.getUserProfile(user.profileId!)
            : null;

        // Create temporary UserModel from combined local data
        final displayUser = server_user_model.UserModel(
          id: user.profileId ?? user.uidShort,
          username:
              userProfile?.name ?? "User ${user.uidShort.substring(0, 4)}",
          email: '',
          photoUrl: userProfile?.photoUrl ?? '',
          age: 0,
          gender: userProfile?.gender ?? '',
          country: '',
          interests: userProfile?.interests ?? [],
          friends: userProfile?.friends ?? [],
          friendRequestsSent: userProfile?.friendRequestsSent ?? [],
          friendRequestsReceived: userProfile?.friendRequestsReceived ?? [],
          nearbyStatusMessage: userProfile?.nearbyStatusMessage ?? '',
          nearbyStatusEmoji: userProfile?.nearbyStatusEmoji ?? '',
          lastSeen: user.lastSeen,
          createdAt: DateTime.now(),
          lastFreeSuperLike: DateTime.now(),
          lastNearbyDiscoveryDate: DateTime.now(),
          lastDailyRewardClaim: DateTime(1970),
          equippedBadgeUrl: userProfile?.equippedBadgeUrl,
        );

        final now = DateTime.now();
        int estimatedRssi = -80;
        final mins = now.difference(user.lastSeen).inMinutes;
        if (mins < 1) {
          estimatedRssi = -50;
        } else if (mins < 5) {
          estimatedRssi = -60;
        } else if (mins < 15) {
          estimatedRssi = -70;
        }

        final isProfileSynced =
            user.profileId != null && user.profileId!.length > 8;
        final isNew = now.difference(user.foundAt).inSeconds < 60;
        final isRecentlyActive = mins < 5;

        return SonarUserCard(
          key: ValueKey(user.uidShort),
          username: displayUser.username,
          photoUrl: displayUser.photoUrl,
          statusMessage: displayUser.nearbyStatusMessage,
          genderValue: user.gender == 1
              ? 'male'
              : (user.gender == 2 ? 'female' : 'unknown'),
          isNew: isNew,
          isRecentlyActive: isRecentlyActive,
          isProfileSynced: isProfileSynced,
          rssi: estimatedRssi,
          userModel: displayUser,
          badgeUrl: displayUser.equippedBadgeUrl,
          onTap: () => locator<NavigationService>().navigateTo(
              ProfileScreen(userId: displayUser.id),
              transition: PageTransition.slide),
          onDelete: onDelete,
        );
      },
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
      duration: AnimationTokens.slow,
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
      curve: AnimationTokens.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: AnimationTokens.easeOut,
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
          curve: AnimationTokens.easeOut,
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
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(DesignTokens.radiusXXL),
                topRight: Radius.circular(DesignTokens.radiusXXL),
              ),
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
                      width: DesignTokens.bottomSheetHandleWidth,
                      height: DesignTokens.bottomSheetHandleHeight,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(
                            DesignTokens.bottomSheetHandleHeight / 2),
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
                          padding: const EdgeInsets.all(DesignTokens.spaceLG)
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

                              const SizedBox(height: DesignTokens.spaceLG),

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

                              const SizedBox(height: DesignTokens.spaceLG),

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
                        padding: const EdgeInsets.all(DesignTokens.spaceSM),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .scaffoldBackgroundColor
                              .withValues(alpha: 0.9),
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusSM),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                            width: DesignTokens.borderWidthHairline,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: DesignTokens.elevation1,
                              offset: const Offset(0, 1),
                            ),
                          ],
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
          padding: const EdgeInsets.all(DesignTokens.spaceLG),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: DesignTokens.borderWidthHairline,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: DesignTokens.elevation1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                ),
                child: Icon(
                  Icons.people_outline,
                  size: DesignTokens.iconLG,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: DesignTokens.spaceMD),
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
                    const SizedBox(height: DesignTokens.spaceXS),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMD,
                  vertical: DesignTokens.spaceSM,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2),
                    width: DesignTokens.borderWidthHairline,
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
      padding: const EdgeInsets.all(DesignTokens.spaceLG),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: DesignTokens.borderWidthHairline,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: DesignTokens.elevation1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DesignTokens.spaceMD),
            decoration: BoxDecoration(
              color: _isSyncing
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Theme.of(context).dividerColor.withValues(alpha: 0.3),
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
                        : Theme.of(context)
                            .iconTheme
                            .color
                            ?.withValues(alpha: 0.6),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: DesignTokens.spaceMD),
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
                const SizedBox(height: DesignTokens.spaceXS),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceLG,
                  vertical: DesignTokens.spaceMD,
                ),
                decoration: BoxDecoration(
                  color: _isSyncing
                      ? Theme.of(context).dividerColor.withValues(alpha: 0.3)
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
          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: DesignTokens.spaceXXL),
            child: _buildEmptyState(context),
          );
        }

        return _buildUserCards(nearbyUsers);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceXXXL),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(DesignTokens.spaceXL),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: DesignTokens.iconXXL,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLG),
          Text(
            'No Users Nearby',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: DesignTokens.fontSizeXL,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          Text(
            'Keep scanning to discover people around you. Make sure Bluetooth is enabled and you\'re in a populated area.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: DesignTokens.fontSizeMD,
                  height: DesignTokens.lineHeightNormal,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.spaceLG),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceLG,
                  vertical: DesignTokens.spaceMD,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                ),
                elevation: 0, // Pure aesthetic
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                widget.onStartScanning();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.radar, size: DesignTokens.iconSM),
                  const SizedBox(width: DesignTokens.spaceSM),
                  Text(
                    'Start Scanning',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: DesignTokens.fontSizeMD,
                          color: Colors.white,
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

          final displayUser = server_user_model.UserModel(
            id: nearbyUser.profileId ?? nearbyUser.uidShort,
            username: userProfile?.name ?? 'User ${nearbyUser.uidShort}',
            email: '',
            photoUrl: userProfile?.photoUrl ?? '',
            age: 0,
            gender: userProfile?.gender ?? '',
            country: '',
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
            lastDailyRewardClaim: DateTime(1970),
            equippedBadgeUrl: userProfile?.equippedBadgeUrl,
          );

          final now = DateTime.now();
          int estimatedRssi = -80;
          final mins = now.difference(nearbyUser.lastSeen).inMinutes;
          if (mins < 1) {
            estimatedRssi = -50;
          } else if (mins < 5)
            estimatedRssi = -60;
          else if (mins < 15) estimatedRssi = -70;

          final isProfileSynced =
              nearbyUser.profileId != null && nearbyUser.profileId!.length > 8;
          final isNew = now.difference(nearbyUser.foundAt).inSeconds < 60;
          final isRecentlyActive = mins < 5;

          return RepaintBoundary(
            child: SonarUserCard(
              key: ValueKey(nearbyUser.uidShort),
              username: displayUser.username,
              photoUrl: displayUser.photoUrl,
              statusMessage: displayUser.nearbyStatusMessage,
              genderValue: nearbyUser.gender == 1
                  ? 'male'
                  : (nearbyUser.gender == 2 ? 'female' : 'unknown'),
              isNew: isNew,
              isRecentlyActive: isRecentlyActive,
              isProfileSynced: isProfileSynced,
              rssi: estimatedRssi,
              userModel: displayUser,
              badgeUrl: displayUser.equippedBadgeUrl,
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
      padding: const EdgeInsets.all(DesignTokens.spaceLG),
      children: userCards,
    );
  }
}
