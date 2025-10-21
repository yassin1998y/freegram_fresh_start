// lib/screens/nearby_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:app_settings/app_settings.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/nearby_bloc.dart'; // BLoC import for status
import 'package:freegram/locator.dart';
// Import Hive models needed for UI display
import 'package:freegram/models/hive/nearby_user.dart';
import 'package:freegram/models/hive/user_profile.dart';
import 'package:freegram/models/user_model.dart' as ServerUserModel; // Alias to avoid name clash
import 'package:freegram/repositories/user_repository.dart'; // Still needed for current user photo
import 'package:freegram/screens/local_leaderboard_screen.dart'; // Keep if used
import 'package:freegram/screens/nearby_chat_list_screen.dart'; // Keep if used
// Import Sonar services
import 'package:freegram/services/sonar/local_cache_service.dart';
import 'package:freegram/services/sonar/sonar_controller.dart';
import 'package:freegram/services/sonar/bluetooth_service.dart'; // For status enum
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/widgets/sonar_view.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:freegram/widgets/nearby_user_card.dart'; // Keep this widget
import 'package:freegram/screens/main_screen.dart'; // For RouteObserver

class NearbyScreen extends StatelessWidget {
  const NearbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // NearbyBloc reflects the *status* (Idle, Active, Error)
    return BlocProvider(
      create: (context) => NearbyBloc(), // Bloc uses SonarController internally
      child: const _NearbyScreenView(),
    );
  }
}

class _NearbyScreenView extends StatefulWidget {
  const _NearbyScreenView();

  @override
  State<_NearbyScreenView> createState() => _NearbyScreenViewState();
}

class _NearbyScreenViewState extends State<_NearbyScreenView>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  // Get services from locator
  final SonarController _sonarController = locator<SonarController>();
  final LocalCacheService _localCacheService = locator<LocalCacheService>();
  final UserRepository _userRepository = locator<UserRepository>(); // Keep for photo

  // Hive boxes (accessed via LocalCacheService now)
  final Box<UserProfile> _profileBox = Hive.box<UserProfile>('userProfiles');
  final Box _settingsBox = Hive.box('settings');

  // Hardware state variables (updated via status listener)
  bool _isBluetoothEnabled = false;

  // Animation controllers
  late AnimationController _unleashController;
  late AnimationController _discoveryController;
  String? _currentUserPhotoUrl;

  final bool _isWeb = kIsWeb;
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    if (!_isWeb) {
      WidgetsBinding.instance.addObserver(this);
      _unleashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
      _discoveryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

      // Initialize user data in SonarController (important after login)
      _sonarController.initializeUser().then((initialized) {
        if (initialized && mounted) { // Check mounted
          _fetchCurrentUserPhoto(); // Fetch photo after initialization
        }
        // else: Handle error if user couldn't be initialized
      });

      // Listen to status for updating local _isBluetoothEnabled etc.
      _statusSubscription = BluetoothStatusService().statusStream.listen(_handleStatusUpdate);
      _handleStatusUpdate(BluetoothStatusService().currentStatus); // Handle initial status

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndShowBatteryOptimizationDialog();
      });
    }
  }

  // Handle status updates to refresh UI elements if needed
  void _handleStatusUpdate(NearbyStatus status) {
    if (mounted) {
      setState(() {
        // Update Bluetooth toggle based on status
        _isBluetoothEnabled = status != NearbyStatus.adapterOff &&
            status != NearbyStatus.permissionsDenied && // Assume off if permissions denied
            status != NearbyStatus.permissionsPermanentlyDenied;

        // Trigger discovery ripple animation
        if(status == NearbyStatus.userFound) {
          _discoveryController.forward(from: 0.0);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isWeb) {
      // Subscribe RouteAware in didChangeDependencies
      routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
    }
  }

  @override
  void dispose() {
    if (!_isWeb) {
      routeObserver.unsubscribe(this); // Unsubscribe RouteAware
      WidgetsBinding.instance.removeObserver(this);
      _sonarController.stopSonar(); // Ensure sonar stops when screen is disposed
      _unleashController.dispose();
      _discoveryController.dispose();
      _statusSubscription?.cancel();
    }
    super.dispose();
  }

  // --- RouteAware Methods ---
  @override
  void didPushNext() { // Navigating away from this screen
    if (!_isWeb) _sonarController.stopSonar();
  }

  @override
  void didPop() { // Popping this screen itself
    if (!_isWeb) _sonarController.stopSonar();
  }

  @override
  void didPush() { // Navigating *to* this screen (initial push)
    // Start check or sync on entering
    if (!_isWeb) _syncPermissionsAndHardwareState(); // Check permissions/hardware
  }

  @override
  void didPopNext() { // Returning *to* this screen from another
    // Optionally auto-restart sonar when returning
    // if (!_isWeb) _sonarController.startSonar();
    if (!_isWeb) _syncPermissionsAndHardwareState(); // Re-check state
  }
  // --- End RouteAware ---


  // --- AppLifecycleState ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isWeb) return;
    // SonarController should ideally handle pause/resume internally based on service lifecycle
    // This check is mainly to refresh the permission/hardware state display
    if (state == AppLifecycleState.resumed) {
      _syncPermissionsAndHardwareState();
    }
  }
  // --- End AppLifecycleState ---

  Future<void> _checkAndShowBatteryOptimizationDialog() async {
    if (!mounted || !Platform.isAndroid || _settingsBox.get('hasSeenBatteryDialog', defaultValue: false)) {
      return;
    }
    // Only show for specific manufacturers known to cause issues
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    // Example: Check for Xiaomi, add others if needed (e.g., 'huawei', 'oppo')
    List<String> problematicManufacturers = ['xiaomi', 'huawei', 'oppo', 'vivo']; // Add more as needed

    if (problematicManufacturers.contains(androidInfo.manufacturer.toLowerCase())) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Important Setting for ${androidInfo.manufacturer}'), // Dynamic title
            content: const Text(
                'For the Nearby feature to work correctly, please set the Battery saver for Freegram to "No restrictions". This prevents the system from stopping the Bluetooth scan.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Later')),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Use AppSettings to open battery optimization settings
                  AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
    // Mark as seen regardless of manufacturer to avoid asking again
    await _settingsBox.put('hasSeenBatteryDialog', true);
  }

  // Check hardware state
  Future<void> _syncPermissionsAndHardwareState() async {
    if (_isWeb) return;
    // Refresh the status via the service, triggers _handleStatusUpdate
    _handleStatusUpdate(BluetoothStatusService().currentStatus);
  }

  // Request permissions by attempting to start sonar
  Future<void> _handlePermissionRequest() async {
    // Dispatch event to BLoC which calls SonarController
    context.read<NearbyBloc>().add(StartNearbyServices());
  }

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
      }
    }
  }

  // Get status message based on BLoC state
  String _getStatusMessage(NearbyState state) {
    if (state is NearbyError) return state.message;
    if (state is NearbyActive) {
      if(state.status == NearbyStatus.scanning) return "Actively searching...";
      if(state.status == NearbyStatus.userFound) return "Discovery active...";
    }
    // If Idle or Initial
    if (_isBluetoothEnabled) {
      return "Ready to scan! Tap your picture to begin.";
    }
    // Check specific error messages if possible
    final currentServiceStatus = BluetoothStatusService().currentStatus;
    if(currentServiceStatus == NearbyStatus.permissionsDenied ||
        currentServiceStatus == NearbyStatus.permissionsPermanentlyDenied) {
      return "Enable Permissions to start.";
    }
    if(currentServiceStatus == NearbyStatus.adapterOff) {
      return "Enable Bluetooth to start.";
    }
    return "Tap your picture to begin."; // Default idle message
  }

  void _deleteFoundUser(String uidShort) {
    // Get profileId first if available, to show correct name in dialog
    String? profileId = _localCacheService.getNearbyUser(uidShort)?.profileId;
    String username = "User (${uidShort.substring(0, 4)})"; // Default
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
              // Use LocalCacheService to delete
              _localCacheService.pruneSpecificUser(uidShort);
              Navigator.of(ctx).pop();
            },
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isWeb) return const _WebPlaceholder();

    // Use BlocConsumer to listen for state changes AND build UI based on state
    return Scaffold(
      body: BlocConsumer<NearbyBloc, NearbyState>(
        listener: (context, state) {
          // Status listener (_handleStatusUpdate) now handles discovery animation trigger
        },
        builder: (context, state) {
          // Handle specific error states for permissions/errors
          if (state is NearbyError) {
            if (state.message.contains("permanently")) {
              return _PermissionDeniedState(isPermanentlyDenied: true);
            }
            if (state.message.contains("Permissions")) {
              return _PermissionDeniedState(onRetry: _handlePermissionRequest);
            }
            return _ErrorState(message: state.message, onRetry: () {
              context.read<NearbyBloc>().add(StartNearbyServices());
            });
          }

          // Main UI structure
          return Column(
            children: [
              // Wrap Control Section in SafeArea to avoid notch/status bar overlap
              SafeArea(
                bottom: false, // Only apply padding to the top
                child: _buildControlSection(context, state), // Pass BLoC state
              ),
              const Divider(height: 1, thickness: 1), // Make divider visible
              Expanded(
                // Listen directly to Hive for the user list
                child: ValueListenableBuilder<Box<NearbyUser>>(
                  // Use the method from LocalCacheService
                  valueListenable: _localCacheService.getNearbyUsersListenable(),
                  builder: (context, box, _) {
                    final nearbyUsers = box.values.toList();
                    nearbyUsers.sort((a, b) => b.lastSeen.compareTo(a.lastSeen)); // Sort by most recent

                    if (nearbyUsers.isEmpty && state is NearbyActive) {
                      return const _SearchingState(); // Show searching if active but no users yet
                    }
                    if (nearbyUsers.isEmpty) {
                      return const _EmptyState(); // Show empty state if idle/initial and no users
                    }
                    return _buildFoundUsersGrid(nearbyUsers); // Pass NearbyUser list
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControlSection(BuildContext context, NearbyState state) {
    bool isScanning = state is NearbyActive;

    return Container(
      // Removed fixed height constraint, let Column size itself
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), // Keep padding
      child: Column(
        children: [
          Padding( // Keep padding for top controls
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleChip(
                    label: "Bluetooth",
                    icon: Icons.bluetooth,
                    isEnabled: _isBluetoothEnabled, // Use state variable
                    onChanged: () => AppSettings.openAppSettings(type: AppSettingsType.bluetooth),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionChip( // Keep Chat chip
                    label: "Chats",
                    icon: Icons.forum_outlined,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const NearbyChatListScreen())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // Listen directly to the box for enabling Rankings
                  child: ValueListenableBuilder<Box<NearbyUser>>(
                      valueListenable: _localCacheService.getNearbyUsersListenable(),
                      builder: (context, box, _) {
                        return _buildActionChip(
                          label: "Rankings",
                          icon: Icons.leaderboard_outlined,
                          // Disable if no users found
                          onPressed: box.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const LocalLeaderboardScreen())),
                        );
                      }
                  ),
                ),
              ],
            ),
          ),
          // Status Message below controls, above Sonar
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              _getStatusMessage(state), // Get message based on BLoC state
              style: TextStyle(color: Colors.grey[700], fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          // Give SonarView a specific size or let AspectRatio handle it
          SizedBox(
            height: 200, // Explicit height for Sonar area
            child: SonarView(
              isScanning: isScanning, // Controlled by BLoC state
              unleashController: _unleashController,
              discoveryController: _discoveryController,
              centerAvatar: _buildCenterAvatar(isScanning), // Pass BLoC state
              foundUserAvatars: const [], // Grid handles users
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildToggleChip({ required String label, required IconData icon, required bool isEnabled, required VoidCallback onChanged}) {
    // Using InkWell for better layout control than FilterChip sometimes
    return InkWell(
      onTap: onChanged,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
            color: isEnabled ? Colors.green : Colors.grey[200],
            borderRadius: BorderRadius.circular(20)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isEnabled ? Colors.white : Colors.grey[600], size: 18),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: isEnabled ? Colors.white : Colors.black87, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({required String label, required IconData icon, required VoidCallback? onPressed}) {
    // Using InkWell for consistency
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
            color: onPressed == null ? Colors.grey[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(20)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: onPressed == null ? Colors.grey[400] : Colors.grey[800], size: 18),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: onPressed == null ? Colors.grey[400] : Colors.grey[800], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterAvatar(bool isScanning) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (!isScanning) {
          _unleashController.forward(from: 0.0);
          context.read<NearbyBloc>().add(StartNearbyServices());
        } else {
          context.read<NearbyBloc>().add(StopNearbyServices());
        }
      },
      child: CircleAvatar(
        radius: 30,
        backgroundColor: Colors.grey[300],
        // Use CachedNetworkImageProvider here
        backgroundImage: _currentUserPhotoUrl != null && _currentUserPhotoUrl!.isNotEmpty
            ? CachedNetworkImageProvider(_currentUserPhotoUrl!)
            : null,
        child: _currentUserPhotoUrl == null || _currentUserPhotoUrl!.isEmpty
            ? const Icon(Icons.person, size: 30, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _buildFoundUsersGrid(List<NearbyUser> users) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: GridView.builder(
        key: ValueKey('nearby_grid_${users.length}'), // Key for animation
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.8,
        ),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final nearbyUser = users[index];

          // Listen directly to profileBox for reactive updates
          return ValueListenableBuilder<Box<UserProfile>>(
            valueListenable: _profileBox.listenable(), // Listen to the whole box
            builder: (context, profileBoxListenable, _) {
              // Get profile using profileId stored in nearbyUser
              final userProfile = nearbyUser.profileId != null
                  ? profileBoxListenable.get(nearbyUser.profileId!)
                  : null;

              // Construct a ServerUserModel for the card
              final displayUser = ServerUserModel.UserModel(
                id: nearbyUser.profileId ?? nearbyUser.uidShort,
                username: userProfile?.name ?? "User ${nearbyUser.uidShort.substring(0, 4)}",
                email: '',
                photoUrl: userProfile?.photoUrl ?? '',
                lastSeen: nearbyUser.lastSeen,
                createdAt: DateTime.fromMillisecondsSinceEpoch(0), // Placeholder
                lastFreeSuperLike: DateTime.fromMillisecondsSinceEpoch(0), // Placeholder
                lastNearbyDiscoveryDate: DateTime.fromMillisecondsSinceEpoch(0), // Placeholder
                gender: nearbyUser.gender == 1 ? 'Male' : nearbyUser.gender == 2 ? 'Female' : '',
                // Add other fields with default values if NearbyUserCard needs them
                age: 0, // Placeholder
                level: 1, // Placeholder - You might want to fetch this if needed
                xp: 0, // Placeholder

              );

              // Estimate RSSI
              int estimatedRssi = -59 - (nearbyUser.distance * 10).toInt().clamp(-40, 0); // Clamp range


              return NearbyUserCard(
                key: ValueKey(nearbyUser.uidShort), // Use stable key
                user: displayUser,
                rssi: estimatedRssi,
                lastSeen: nearbyUser.lastSeen,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: displayUser.id))), // Use displayUser.id
                onDelete: () => _deleteFoundUser(nearbyUser.uidShort),
              );
            },
          );
        },
      ),
    );
  }
}

// --- Helper Widgets for States ---

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding( // Added padding for better spacing
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

class _PermissionDeniedState extends StatelessWidget {
  final VoidCallback? onRetry;
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
            if (!isPermanentlyDenied && onRetry != null)
              ElevatedButton(onPressed: onRetry, child: const Text('Grant Permissions')),
            TextButton(onPressed: () => AppSettings.openAppSettings(), child: const Text('Open Settings')),
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
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
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