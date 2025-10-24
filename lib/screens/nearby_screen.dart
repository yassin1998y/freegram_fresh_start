// lib/screens/nearby_screen.dart
import 'dart:async';
import 'dart:io'; // Keep for Platform check
import 'package:app_settings/app_settings.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/nearby_bloc.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/hive/nearby_user.dart';
import 'package:freegram/models/hive/user_profile.dart';
// Alias ServerUserModel to avoid conflict with local variables named 'user'
import 'package:freegram/models/user_model.dart' as ServerUserModel;
import 'package:freegram/repositories/user_repository.dart';
// import 'package:freegram/screens/local_leaderboard_screen.dart'; // Keep if Leaderboard button stays
import 'package:freegram/screens/nearby_chat_list_screen.dart'; // Keep for Chats button
import 'package:freegram/services/sonar/local_cache_service.dart';
import 'package:freegram/services/sonar/sonar_controller.dart';
import 'package:freegram/services/sonar/bluetooth_service.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/widgets/sonar_view.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:freegram/widgets/nearby_user_card.dart';
import 'package:freegram/screens/main_screen.dart'; // For RouteObserver
// Import the extension containing getNearbyUserByProfileId etc.
import 'package:freegram/services/sync_manager.dart' show LocalCacheServiceHelper;
import 'package:collection/collection.dart'; // For firstWhereOrNull


// Main StatelessWidget Wrapper
class NearbyScreen extends StatelessWidget {
  const NearbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Keep MultiBlocProvider for NearbyBloc and FriendsBloc
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => NearbyBloc(), // NearbyBloc manages its own state now
        ),
        BlocProvider(
          // FriendsBloc needed for NearbyUserCard actions
          create: (context) => FriendsBloc(
            userRepository: locator<UserRepository>(),
          )..add(LoadFriends()), // Load friends data
        ),
      ],
      child: const _NearbyScreenView(),
    );
  }
}

// Main StatefulWidget View
class _NearbyScreenView extends StatefulWidget {
  const _NearbyScreenView();

  @override
  State<_NearbyScreenView> createState() => _NearbyScreenViewState();
}

class _NearbyScreenViewState extends State<_NearbyScreenView>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {

  // Keep state variables and controllers
  final SonarController _sonarController = locator<SonarController>();
  final LocalCacheService _localCacheService = locator<LocalCacheService>();
  final UserRepository _userRepository = locator<UserRepository>();
  final Box _settingsBox = Hive.box('settings'); // Keep settings box
  bool _isBluetoothEnabled = false; // Tracks UI state based on Service status
  late AnimationController _unleashController;
  late AnimationController _discoveryController;
  String? _currentUserPhotoUrl;
  final bool _isWeb = kIsWeb; // Keep web check
  StreamSubscription? _statusSubscription; // Subscription to StatusService

  @override
  void initState() {
    super.initState();
    if (!_isWeb) {
      WidgetsBinding.instance.addObserver(this); // Observe app lifecycle
      // Initialize animation controllers
      _unleashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
      _discoveryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

      // Initialize user data for SonarController
      _sonarController.initializeUser().then((initialized) {
        if (initialized && mounted) {
          _fetchCurrentUserPhoto(); // Get current user's photo for avatar
        }
      });

      // Listen to status updates from the shared BluetoothStatusService
      _statusSubscription = BluetoothStatusService().statusStream.listen(_handleStatusUpdate);
      // Set initial state based on current status
      _handleStatusUpdate(BluetoothStatusService().currentStatus);

      // Check for battery optimization settings after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndShowBatteryOptimizationDialog();
      });
    }
  }

  // Handle status updates from BluetoothStatusService
  void _handleStatusUpdate(NearbyStatus status) {
    if (mounted) {
      setState(() {
        // Update UI enable state based on service status
        _isBluetoothEnabled = status != NearbyStatus.adapterOff &&
            status != NearbyStatus.permissionsDenied &&
            status != NearbyStatus.permissionsPermanentlyDenied &&
            status != NearbyStatus.error; // Include error state
        // Trigger discovery ripple animation
        if(status == NearbyStatus.userFound) {
          _discoveryController.forward(from: 0.0);
        }
      });
    }
  }

  // RouteAware setup
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isWeb) {
      // Subscribe to route changes for pausing/resuming sonar
      routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
    }
  }

  @override
  void dispose() {
    if (!_isWeb) {
      routeObserver.unsubscribe(this); // Unsubscribe RouteAware
      WidgetsBinding.instance.removeObserver(this); // Unsubscribe lifecycle observer
      _sonarController.stopSonar(); // Ensure sonar stops on dispose
      _unleashController.dispose();
      _discoveryController.dispose();
      _statusSubscription?.cancel(); // Cancel status listener
    }
    super.dispose();
  }

  // RouteAware methods to stop/start sonar when navigating away/back
  @override
  void didPushNext() { if (!_isWeb) _sonarController.stopSonar(); debugPrint("NearbyScreen: didPushNext - Stopping Sonar"); }
  @override
  void didPop() { if (!_isWeb) _sonarController.stopSonar(); debugPrint("NearbyScreen: didPop - Stopping Sonar"); }
  // When returning to the screen, sync state and potentially restart sonar if needed
  @override
  void didPush() { if (!_isWeb) _syncPermissionsAndHardwareState(); debugPrint("NearbyScreen: didPush - Syncing State"); }
  @override
  void didPopNext() { if (!_isWeb) _syncPermissionsAndHardwareState(); debugPrint("NearbyScreen: didPopNext - Syncing State"); }

  // App lifecycle handling
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("NearbyScreen: AppLifecycleState changed to $state");
    if (_isWeb) return; // Ignore on web
    if (state == AppLifecycleState.resumed) {
      // When app resumes, check permissions and adapter state
      _syncPermissionsAndHardwareState();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      // If app is paused/inactive/detached, stop sonar if it's running
      final currentStatus = BluetoothStatusService().currentStatus;
      if (currentStatus == NearbyStatus.scanning || currentStatus == NearbyStatus.userFound) {
        debugPrint("NearbyScreen: App Paused/Inactive/Detached - Stopping Sonar");
        _sonarController.stopSonar();
      }
    }
  }

  // _checkAndShowBatteryOptimizationDialog remains the same
  Future<void> _checkAndShowBatteryOptimizationDialog() async {
    if (!mounted || !Platform.isAndroid || _settingsBox.get('hasSeenBatteryDialog', defaultValue: false)) {
      return;
    }
    // Check manufacturer using device_info_plus
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    List<String> problematicManufacturers = ['xiaomi', 'huawei', 'oppo', 'vivo']; // Add others as needed
    if (problematicManufacturers.contains(androidInfo.manufacturer.toLowerCase())) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Important Setting for ${androidInfo.manufacturer}'),
            content: const Text(
                'For the Nearby feature to work correctly, please set the Battery saver for Freegram to "No restrictions". This prevents the system from stopping the Bluetooth scan.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Later')),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Use app_settings to open relevant settings page
                  AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
    // Mark dialog as seen
    await _settingsBox.put('hasSeenBatteryDialog', true);
  }


  // Sync state when app resumes or returns to screen
  Future<void> _syncPermissionsAndHardwareState() async {
    if (_isWeb) return;
    debugPrint("NearbyScreen: _syncPermissionsAndHardwareState called");
    // Check permission status without requesting
    bool granted = await _checkPermissionsStatusOnly();
    // Get current adapter status from the service
    final adapterState = BluetoothStatusService().currentStatus;
    debugPrint("NearbyScreen: Post-Sync - Permissions Granted: $granted, Adapter Status: $adapterState");

    // Update UI state based on the fetched status
    _handleStatusUpdate(adapterState);

    // Optional: Auto-restart sonar if permissions/adapter are now OK and it should be running
    // This depends on whether you want sonar to automatically resume.
    // final nearbyState = context.read<NearbyBloc>().state;
    // if (granted && adapterState == NearbyStatus.idle && nearbyState is NearbyActive) {
    //   debugPrint("NearbyScreen: Permissions/Adapter OK, attempting auto-restart...");
    //   context.read<NearbyBloc>().add(StartNearbyServices());
    // }
  }

  // Check permissions without requesting them
  Future<bool> _checkPermissionsStatusOnly() async {
    debugPrint("NearbyScreen: Checking permission status...");
    Map<Permission, PermissionStatus> statuses = {};
    // Check necessary permissions using permission_handler
    statuses[Permission.locationWhenInUse] = await Permission.locationWhenInUse.status;
    statuses[Permission.bluetoothScan] = await Permission.bluetoothScan.status;
    statuses[Permission.bluetoothConnect] = await Permission.bluetoothConnect.status;
    statuses[Permission.bluetoothAdvertise] = await Permission.bluetoothAdvertise.status;

    bool allGranted = statuses.values.every((status) => status.isGranted);
    debugPrint("NearbyScreen: Permission Statuses - $statuses, All Granted: $allGranted");

    // Update status service if permissions are denied
    if (!allGranted) {
      if (statuses.values.any((s) => s.isPermanentlyDenied)) {
        debugPrint("NearbyScreen: Permissions permanently denied detected.");
        BluetoothStatusService().updateStatus(NearbyStatus.permissionsPermanentlyDenied);
      } else {
        debugPrint("NearbyScreen: Permissions denied detected.");
        BluetoothStatusService().updateStatus(NearbyStatus.permissionsDenied);
      }
    } else {
      // If permissions are now granted, ensure status isn't stuck on denied
      final currentStatus = BluetoothStatusService().currentStatus;
      if(currentStatus == NearbyStatus.permissionsDenied || currentStatus == NearbyStatus.permissionsPermanentlyDenied) {
        debugPrint("NearbyScreen: Permissions seem granted now, resetting status from denied to idle.");
        // Reset status to idle so user can start sonar
        BluetoothStatusService().updateStatus(NearbyStatus.idle);
      }
    }
    return allGranted;
  }

  // Trigger permission request via NearbyBloc
  Future<void> _handlePermissionRequest() async {
    debugPrint("NearbyScreen: Handling permission request via BLoC.");
    // Let the BLoC handle the permission request and start flow
    context.read<NearbyBloc>().add(StartNearbyServices());
  }

  // Fetch current user photo for avatar
  Future<void> _fetchCurrentUserPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final ServerUserModel.UserModel userModel = await _userRepository.getUser(user.uid);
        if (mounted) {
          setState(() {
            _currentUserPhotoUrl = userModel.photoUrl;
          });
        }
      } catch (e) {
        debugPrint("NearbyScreen: Error fetching current user photo: $e");
        if(mounted) setState(() { _currentUserPhotoUrl = ''; }); // Fallback
      }
    } else {
      if(mounted) setState(() { _currentUserPhotoUrl = ''; }); // Fallback
    }
  }


  // Get appropriate status message based on state
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

    // Otherwise, use the BLoC state
    if (state is NearbyError) return state.message;
    if (state is NearbyActive) {
      if(state.status == NearbyStatus.scanning) return "Actively searching...";
      if(state.status == NearbyStatus.userFound) return "Discovery active..."; // More generic active message
    }
    // Default/Idle state message
    return "Ready to scan! Tap your picture to begin.";
  }

  // Delete user confirmation dialog
  void _deleteFoundUser(String uidShort) {
    // Fetch potential profile info for display name
    String? profileId = _localCacheService.getNearbyUser(uidShort)?.profileId;
    String username = "User (${uidShort.substring(0, 4)})"; // Default name
    if (profileId != null) {
      username = _localCacheService.getUserProfile(profileId)?.name ?? username;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Remove $username?"),
        content: const Text("Are you sure? This user can be discovered again in a future scan."),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              _localCacheService.pruneSpecificUser(uidShort); // Remove from Hive
              Navigator.of(ctx).pop();
            },
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    if (_isWeb) return const _WebPlaceholder(); // Show placeholder on web

    return Scaffold(
      // Use BlocConsumer to react to state changes (e.g., show errors) and build UI
      body: BlocConsumer<NearbyBloc, NearbyState>(
        listener: (context, state) {
          // Optional: Add listeners for specific state transitions if needed
          // e.g., show a snackbar on error
        },
        builder: (context, state) {
          final currentServiceStatus = BluetoothStatusService().currentStatus;
          Widget bodyContent;

          // Build UI based on permission/hardware status first
          if (currentServiceStatus == NearbyStatus.permissionsPermanentlyDenied) {
            bodyContent = _PermissionDeniedState(isPermanentlyDenied: true);
          } else if (currentServiceStatus == NearbyStatus.permissionsDenied) {
            bodyContent = _PermissionDeniedState(onRetry: _handlePermissionRequest);
          }
          // If BLoC reports error, show error state (unless it's a permission/adapter issue already handled)
          else if (state is NearbyError && currentServiceStatus != NearbyStatus.adapterOff) {
            bodyContent = _ErrorState(message: state.message, onRetry: () => context.read<NearbyBloc>().add(StartNearbyServices()));
          }
          // Otherwise, build the main Nearby UI
          else {
            bodyContent = Column(
              children: [
                SafeArea( // Keep controls within safe area
                  bottom: false,
                  child: _buildControlSection(context, state),
                ),
                const Divider(height: 1, thickness: 1), // Separator
                Expanded(
                  // Use ValueListenableBuilder to listen directly to Hive box changes
                  child: ValueListenableBuilder<Box<NearbyUser>>(
                    valueListenable: _localCacheService.getNearbyUsersListenable(),
                    builder: (context, nearbyBox, _) {
                      debugPrint("NearbyScreen: NearbyUserBox ValueListenableBuilder triggered. Box size: ${nearbyBox.length}");
                      final nearbyUsers = nearbyBox.values.toList();
                      // Sort users by last seen time (most recent first)
                      nearbyUsers.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

                      if (nearbyUsers.isEmpty && state is NearbyActive && currentServiceStatus == NearbyStatus.scanning) {
                        // Show searching indicator only if actively scanning and no users found yet
                        return const _SearchingState();
                      }
                      if (nearbyUsers.isEmpty) {
                        // Show empty state if no users found (and not actively scanning)
                        return const _EmptyState();
                      }

                      // Build the grid of found users
                      // Ensure FriendsBloc is available via BlocProvider.value for NearbyUserCard
                      return BlocProvider.value(
                        value: BlocProvider.of<FriendsBloc>(context),
                        child: _buildFoundUsersGrid(nearbyUsers),
                      );
                    },
                  ),
                ),
              ],
            );
          }
          // Use AnimatedSwitcher for smooth transitions between states (permissions/error/main UI)
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: bodyContent,
          );
        },
      ),
    );
  }


  // --- Helper Build Methods ---

  // Build top control section (buttons, status, sonar view)
  Widget _buildControlSection(BuildContext context, NearbyState state) {
    // Determine scanning state from BLoC state
    bool isScanning = state is NearbyActive; // Active includes scanning and userFound

    // Determine enabled state from Status Service
    final currentServiceStatus = BluetoothStatusService().currentStatus;
    _isBluetoothEnabled = currentServiceStatus != NearbyStatus.adapterOff &&
        currentServiceStatus != NearbyStatus.permissionsDenied &&
        currentServiceStatus != NearbyStatus.permissionsPermanentlyDenied &&
        currentServiceStatus != NearbyStatus.error;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), // Adjust padding as needed
      child: Column(
        children: [
          // Row for Bluetooth toggle and action chips
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                Expanded( // Bluetooth Status/Toggle Chip
                  child: _buildToggleChip(
                    label: "Bluetooth",
                    icon: Icons.bluetooth,
                    isEnabled: _isBluetoothEnabled,
                    // Open Bluetooth settings on tap
                    onChanged: () => AppSettings.openAppSettings(type: AppSettingsType.bluetooth),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded( // Nearby Chats Chip
                  child: _buildActionChip(
                    label: "Chats",
                    icon: Icons.forum_outlined,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const NearbyChatListScreen())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded( // Nearby Rankings Chip (conditionally enabled)
                  child: _buildActionChip(
                    label: "Rankings",
                    icon: Icons.leaderboard_outlined,
                    onPressed: null, // Disabled
                  ),
                ),
              ],
            ),
          ),
          // Status Message Text
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              _getStatusMessage(state), // Get dynamic status message
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ),
          // Sonar Animation View
          SizedBox(
            height: 200, // Fixed height for sonar animation area
            child: SonarView(
              isScanning: isScanning, // Pass scanning state
              unleashController: _unleashController, // Pass unleash animation controller
              discoveryController: _discoveryController, // Pass discovery animation controller
              centerAvatar: _buildCenterAvatar(isScanning), // Pass center avatar widget
              foundUserAvatars: const [], // Keep empty, grid handles users
            ),
          ),
        ],
      ),
    );
  }

  // Build Bluetooth toggle chip
  Widget _buildToggleChip({ required String label, required IconData icon, required bool isEnabled, required VoidCallback onChanged}) {
    return InkWell(
      onTap: onChanged,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          // Use green when enabled, grey when disabled
            color: isEnabled ? Colors.green : Colors.grey[200],
            borderRadius: BorderRadius.circular(20)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isEnabled ? Colors.white : Colors.grey[600], size: 18),
            const SizedBox(width: 4),
            Flexible( // Allow text to wrap/ellipsis if needed
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: isEnabled ? Colors.white : Colors.black87, fontSize: 12)
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build action chip (Chats, Rankings)
  Widget _buildActionChip({required String label, required IconData icon, required VoidCallback? onPressed}) {
    // Determine if button is disabled
    bool isDisabled = onPressed == null;
    return InkWell(
      onTap: isDisabled ? null : onPressed, // Disable tap if onPressed is null
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          // Use different background colors based on enabled state
            color: isDisabled ? Colors.grey[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(20)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isDisabled ? Colors.grey[400] : Colors.grey[800], size: 18), // Dim icon when disabled
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: isDisabled ? Colors.grey[400] : Colors.grey[800], fontSize: 12) // Dim text when disabled
              ),
            ),
          ],
        ),
      ),
    );
  }


  // Build the central avatar (current user)
  Widget _buildCenterAvatar(bool isScanning) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact(); // Haptic feedback on tap
        // If not scanning/active, trigger start animation and BLoC event
        if (!isScanning) {
          _unleashController.forward(from: 0.0); // Play unleash animation
          context.read<NearbyBloc>().add(StartNearbyServices()); // Tell BLoC to start
        } else {
          // If scanning/active, tell BLoC to stop
          context.read<NearbyBloc>().add(StopNearbyServices());
        }
      },
      child: CircleAvatar(
        radius: 30, // Avatar size
        backgroundColor: Colors.grey[300], // Background if no image
        backgroundImage: _currentUserPhotoUrl != null && _currentUserPhotoUrl!.isNotEmpty
            ? CachedNetworkImageProvider(_currentUserPhotoUrl!) // Load user image
            : null,
        // Show person icon placeholder if no image
        child: _currentUserPhotoUrl == null || _currentUserPhotoUrl!.isEmpty
            ? const Icon(Icons.person, size: 30, color: Colors.white)
            : null,
      ),
    );
  }


  // Build the grid displaying found users
  Widget _buildFoundUsersGrid(List<NearbyUser> users) {
    final friendsBloc = BlocProvider.of<FriendsBloc>(context); // Get FriendsBloc for actions

    return AnimatedSwitcher( // Animate grid changes
      duration: const Duration(milliseconds: 500),
      child: GridView.builder(
        key: ValueKey('nearby_grid_${users.length}'), // Key to help animation
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, // 4 columns
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.8, // Adjust aspect ratio for card appearance
        ),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final nearbyUser = users[index];

          // Use ValueListenableBuilder scoped to each grid item to listen
          // for updates to the specific UserProfile this NearbyUser links to.
          return ValueListenableBuilder<Box<UserProfile>>(
            // Listen only to changes for the relevant profileId (if it exists)
              valueListenable: Hive.box<UserProfile>('userProfiles').listenable(keys: nearbyUser.profileId != null ? [nearbyUser.profileId!] : null),
              builder: (context, profileBox, _) {
                // Fetch the UserProfile from cache using the profileId
                final userProfile = nearbyUser.profileId != null
                    ? _localCacheService.getUserProfile(nearbyUser.profileId!)
                    : null;

                debugPrint("NearbyScreen GridItemBuilder: User ${nearbyUser.uidShort}, Profile ID: ${nearbyUser.profileId}, Profile Found: ${userProfile != null}, Profile Name: ${userProfile?.name}");

                // Create a temporary ServerUserModel to pass to NearbyUserCard.
                // Populate with profile data if available, otherwise use nearby data/defaults.
                final displayUser = ServerUserModel.UserModel(
                  // Use full ID if profile exists, otherwise use short ID (card handles actions based on ID type)
                    id: userProfile?.profileId ?? nearbyUser.uidShort,
                    username: userProfile?.name ?? "User ${nearbyUser.uidShort.substring(0, 4)}", // Use profile name or generate default
                    photoUrl: userProfile?.photoUrl ?? '', // Use profile photo or empty
                    lastSeen: nearbyUser.lastSeen, // Use nearby lastSeen
                    // Use profile gender if available, otherwise derive from nearbyUser or default
                    gender: userProfile?.gender ?? (nearbyUser.gender == 1 ? 'Male' : nearbyUser.gender == 2 ? 'Female' : ''),
                    // Use profile data if available, otherwise defaults
                    // level: userProfile?.level ?? 0, // Removed field
                    // xp: userProfile?.xp ?? 0, // Removed field
                    interests: userProfile?.interests ?? [],
                    friends: userProfile?.friends ?? [],
                    friendRequestsSent: userProfile?.friendRequestsSent ?? [],
                    friendRequestsReceived: userProfile?.friendRequestsReceived ?? [],
                    blockedUsers: userProfile?.blockedUsers ?? [],
                    nearbyStatusMessage: userProfile?.nearbyStatusMessage ?? '',
                    nearbyStatusEmoji: userProfile?.nearbyStatusEmoji ?? '',
                    // ---- Required UserModel fields with defaults ----
                    email: '', createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                    lastFreeSuperLike: DateTime.fromMillisecondsSinceEpoch(0),
                    lastNearbyDiscoveryDate: DateTime.fromMillisecondsSinceEpoch(0), age: 0,
                    nearbyDiscoveryStreak: 0, // Default for streak
                    // currentSeasonId: '', // Removed field
                    // seasonLevel: 0, // Removed field
                    // seasonXp: 0, // Removed field
                    // claimedSeasonRewards: [], // Removed field
                    pictureVersion: 0, bio: '', fcmToken: '',
                    presence: false, coins: 0, superLikes: 0, // Defaults for coins/superlikes
                    // equippedBadgeId: null, // Removed field
                    // equippedProfileFrameId: null, // Removed field
                    sharedMusicTrack: null, nearbyDataVersion: 0
                );

                // Estimate RSSI based on distance for proximity bars (rough estimate)
                // Assuming TXPower around -59dBm, adjust if needed
                int estimatedRssi = -59 - (nearbyUser.distance * 10).toInt().clamp(-40, 0);

                // Provide FriendsBloc to the card for actions
                return BlocProvider.value(
                  value: friendsBloc,
                  child: NearbyUserCard(
                    key: ValueKey(nearbyUser.uidShort), // Use unique key
                    user: displayUser, // Pass the created display user
                    genderValue: nearbyUser.gender, // Pass raw gender for placeholder
                    rssi: estimatedRssi, // Pass estimated RSSI
                    lastSeen: nearbyUser.lastSeen, // Pass last seen time
                    // Navigate to full profile on tap (action handled by card's internal modal now)
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: displayUser.id))),
                    // Handle deletion
                    onDelete: () => _deleteFoundUser(nearbyUser.uidShort),
                    // deviceAddress: nearbyUser.deviceAddress, // If address is stored in NearbyUser
                  ),
                );
              }
          );
        },
      ),
    );
  }
}

// --- UI State Placeholder Widgets ---

// Displayed when no users are found yet (and not actively scanning)
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.radar, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text("Ready to Discover", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Tap the sonar to start finding people!", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// Displayed when actively scanning but no users found yet
class _SearchingState extends StatelessWidget {
  const _SearchingState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Looking for users nearby...", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// Displayed when permissions are denied
class _PermissionDeniedState extends StatelessWidget {
  final VoidCallback? onRetry; // Callback to request permissions again
  final bool isPermanentlyDenied;
  const _PermissionDeniedState({this.onRetry, this.isPermanentlyDenied = false});
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
            const Text("Permissions Required", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                isPermanentlyDenied
                    ? "You've permanently denied permissions. Please enable them in your device settings to use this feature."
                    : "This feature needs Bluetooth and Location permissions to discover people.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)
            ),
            const SizedBox(height: 24),
            // Show "Grant Permissions" button only if not permanently denied
            if (!isPermanentlyDenied && onRetry != null)
              ElevatedButton(onPressed: onRetry, child: const Text('Grant Permissions')),
            // Always show "Open Settings" button
            TextButton(onPressed: () => AppSettings.openAppSettings(), child: const Text('Open Settings')),
          ],
        ),
      ),
    );
  }
}

// Displayed on generic BLoC errors (not permission/adapter related)
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
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

// Placeholder for Web platform
class _WebPlaceholder extends StatelessWidget {
  const _WebPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Scaffold( // Needs Scaffold parent
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.radar_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              const Text('Feature Not Available on Web', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('The Nearby feature uses device Bluetooth and is only available on the mobile app.', style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}