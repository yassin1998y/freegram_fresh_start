// lib/screens/nearby_screen.dart
import 'dart:async';
import 'dart:io';
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
import 'package:freegram/models/user_model.dart' as ServerUserModel;
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/local_leaderboard_screen.dart';
import 'package:freegram/screens/nearby_chat_list_screen.dart';
import 'package:freegram/services/sonar/local_cache_service.dart';
import 'package:freegram/services/sonar/sonar_controller.dart';
import 'package:freegram/services/sonar/bluetooth_service.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/widgets/sonar_view.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:freegram/widgets/nearby_user_card.dart';
import 'package:freegram/screens/main_screen.dart'; // For RouteObserver
import 'package:collection/collection.dart';


class NearbyScreen extends StatelessWidget {
  const NearbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => NearbyBloc(),
        ),
        BlocProvider(
          create: (context) => FriendsBloc(
            userRepository: locator<UserRepository>(),
          )..add(LoadFriends()),
        ),
      ],
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

  final SonarController _sonarController = locator<SonarController>();
  final LocalCacheService _localCacheService = locator<LocalCacheService>();
  final UserRepository _userRepository = locator<UserRepository>();
  // Removed direct reference to _profileBox here, will access via localCacheService
  final Box _settingsBox = Hive.box('settings');
  bool _isBluetoothEnabled = false;
  late AnimationController _unleashController;
  late AnimationController _discoveryController;
  String? _currentUserPhotoUrl;
  final bool _isWeb = kIsWeb;
  StreamSubscription? _statusSubscription;

  // --- initState, dispose, lifecycle methods remain the same ---
  @override
  void initState() {
    super.initState();
    if (!_isWeb) {
      WidgetsBinding.instance.addObserver(this);
      _unleashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
      _discoveryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

      _sonarController.initializeUser().then((initialized) {
        if (initialized && mounted) {
          _fetchCurrentUserPhoto();
        }
      });

      _statusSubscription = BluetoothStatusService().statusStream.listen(_handleStatusUpdate);
      _handleStatusUpdate(BluetoothStatusService().currentStatus);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndShowBatteryOptimizationDialog();
      });
    }
  }

  void _handleStatusUpdate(NearbyStatus status) {
    if (mounted) {
      setState(() {
        _isBluetoothEnabled = status != NearbyStatus.adapterOff &&
            status != NearbyStatus.permissionsDenied &&
            status != NearbyStatus.permissionsPermanentlyDenied;
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
      routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
    }
  }

  @override
  void dispose() {
    if (!_isWeb) {
      routeObserver.unsubscribe(this);
      WidgetsBinding.instance.removeObserver(this);
      _sonarController.stopSonar();
      _unleashController.dispose();
      _discoveryController.dispose();
      _statusSubscription?.cancel();
    }
    super.dispose();
  }

  @override
  void didPushNext() { if (!_isWeb) _sonarController.stopSonar(); debugPrint("NearbyScreen: didPushNext - Stopping Sonar"); }
  @override
  void didPop() { if (!_isWeb) _sonarController.stopSonar(); debugPrint("NearbyScreen: didPop - Stopping Sonar"); }
  @override
  void didPush() { if (!_isWeb) _syncPermissionsAndHardwareState(); debugPrint("NearbyScreen: didPush - Syncing State"); }
  @override
  void didPopNext() { if (!_isWeb) _syncPermissionsAndHardwareState(); debugPrint("NearbyScreen: didPopNext - Syncing State"); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("NearbyScreen: AppLifecycleState changed to $state");
    if (_isWeb) return;
    if (state == AppLifecycleState.resumed) {
      _syncPermissionsAndHardwareState();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      if (BluetoothStatusService().currentStatus == NearbyStatus.scanning ||
          BluetoothStatusService().currentStatus == NearbyStatus.userFound) {
        debugPrint("NearbyScreen: App Paused/Inactive/Detached - Stopping Sonar");
        _sonarController.stopSonar();
      }
    }
  }

  // --- Other methods (_checkAndShowBatteryOptimizationDialog, _syncPermissionsAndHardwareState, etc.) remain the same ---
  Future<void> _checkAndShowBatteryOptimizationDialog() async {
    if (!mounted || !Platform.isAndroid || _settingsBox.get('hasSeenBatteryDialog', defaultValue: false)) {
      return;
    }
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    List<String> problematicManufacturers = ['xiaomi', 'huawei', 'oppo', 'vivo'];
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
                  AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
    await _settingsBox.put('hasSeenBatteryDialog', true);
  }

  Future<void> _syncPermissionsAndHardwareState() async {
    if (_isWeb) return;
    debugPrint("NearbyScreen: _syncPermissionsAndHardwareState called");
    bool granted = await _checkPermissionsStatusOnly();
    final adapterState = BluetoothStatusService().currentStatus;
    debugPrint("NearbyScreen: Post-Sync - Permissions Granted: $granted, Adapter Status: $adapterState");

    _handleStatusUpdate(adapterState);
  }

  Future<bool> _checkPermissionsStatusOnly() async {
    debugPrint("NearbyScreen: Checking permission status...");
    Map<Permission, PermissionStatus> statuses = {};
    statuses[Permission.locationWhenInUse] = await Permission.locationWhenInUse.status;
    statuses[Permission.bluetoothScan] = await Permission.bluetoothScan.status;
    statuses[Permission.bluetoothConnect] = await Permission.bluetoothConnect.status;
    statuses[Permission.bluetoothAdvertise] = await Permission.bluetoothAdvertise.status;

    bool allGranted = statuses.values.every((status) => status.isGranted);
    debugPrint("NearbyScreen: Permission Statuses - $statuses, All Granted: $allGranted");

    if(!allGranted) {
      if (statuses.values.any((s) => s.isPermanentlyDenied)) {
        debugPrint("NearbyScreen: Permissions permanently denied detected.");
        BluetoothStatusService().updateStatus(NearbyStatus.permissionsPermanentlyDenied);
        return false;
      }
      debugPrint("NearbyScreen: Permissions denied detected.");
      BluetoothStatusService().updateStatus(NearbyStatus.permissionsDenied);
    } else {
      final currentStatus = BluetoothStatusService().currentStatus;
      if(currentStatus == NearbyStatus.permissionsDenied || currentStatus == NearbyStatus.permissionsPermanentlyDenied) {
        debugPrint("NearbyScreen: Permissions seem granted now, resetting status from denied.");
      }
    }
    return allGranted;
  }


  Future<void> _handlePermissionRequest() async {
    debugPrint("NearbyScreen: Handling permission request via BLoC.");
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
        if(mounted) setState(() { _currentUserPhotoUrl = ''; });
      }
    } else {
      if(mounted) setState(() { _currentUserPhotoUrl = ''; });
    }
  }

  String _getStatusMessage(NearbyState state) {
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

    if (state is NearbyError) return state.message;
    if (state is NearbyActive) {
      if(state.status == NearbyStatus.scanning) return "Actively searching...";
      if(state.status == NearbyStatus.userFound) return "Discovery active...";
    }

    return "Ready to scan! Tap your picture to begin.";
  }

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
        content: const Text("Are you sure? This user can be discovered again in a future scan."),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              _localCacheService.pruneSpecificUser(uidShort);
              Navigator.of(ctx).pop();
            },
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- build Method ---
  @override
  Widget build(BuildContext context) {
    if (_isWeb) return const _WebPlaceholder();

    return Scaffold(
      body: BlocConsumer<NearbyBloc, NearbyState>(
        listener: (context, state) {},
        builder: (context, state) {
          final currentServiceStatus = BluetoothStatusService().currentStatus;
          Widget bodyContent;

          if (currentServiceStatus == NearbyStatus.permissionsPermanentlyDenied) {
            bodyContent = _PermissionDeniedState(isPermanentlyDenied: true);
          } else if (currentServiceStatus == NearbyStatus.permissionsDenied) {
            bodyContent = _PermissionDeniedState(onRetry: _handlePermissionRequest);
          } else if (state is NearbyError) {
            bodyContent = _ErrorState(message: state.message, onRetry: () => context.read<NearbyBloc>().add(StartNearbyServices()));
          } else {
            // Main UI
            bodyContent = Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: _buildControlSection(context, state),
                ),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  // --- MODIFICATION START ---
                  // Listen to the NearbyUser box directly here
                  child: ValueListenableBuilder<Box<NearbyUser>>(
                    valueListenable: _localCacheService.getNearbyUsersListenable(),
                    builder: (context, nearbyBox, _) {
                      // --- DEBUG ---
                      debugPrint("NearbyScreen: NearbyUserBox ValueListenableBuilder triggered. Box size: ${nearbyBox.length}");
                      // --- END DEBUG ---
                      final nearbyUsers = nearbyBox.values.toList();
                      nearbyUsers.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

                      // --- DEBUG ---
                      if (nearbyUsers.isNotEmpty) {
                        debugPrint("NearbyScreen: First user uidShort: ${nearbyUsers.first.uidShort}, profileId: ${nearbyUsers.first.profileId}");
                      }
                      // --- END DEBUG ---

                      if (nearbyUsers.isEmpty && state is NearbyActive && currentServiceStatus == NearbyStatus.scanning) {
                        return const _SearchingState();
                      }
                      if (nearbyUsers.isEmpty) {
                        return const _EmptyState();
                      }

                      // Ensure FriendsBloc is available
                      return BlocProvider.value(
                        value: BlocProvider.of<FriendsBloc>(context),
                        // Pass the list of NearbyUsers to the grid builder
                        child: _buildFoundUsersGrid(nearbyUsers),
                      );
                    },
                  ),
                  // --- MODIFICATION END ---
                ),
              ],
            );
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: bodyContent,
          );
        },
      ),
    );
  }


  // --- _buildControlSection and other helper methods remain the same ---
  Widget _buildControlSection(BuildContext context, NearbyState state) {
    bool isScanning = state is NearbyActive &&
        state.status != NearbyStatus.idle &&
        state.status != NearbyStatus.error;

    final currentServiceStatus = BluetoothStatusService().currentStatus;
    _isBluetoothEnabled = currentServiceStatus != NearbyStatus.adapterOff &&
        currentServiceStatus != NearbyStatus.permissionsDenied &&
        currentServiceStatus != NearbyStatus.permissionsPermanentlyDenied &&
        currentServiceStatus != NearbyStatus.error;


    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleChip(
                    label: "Bluetooth",
                    icon: Icons.bluetooth,
                    isEnabled: _isBluetoothEnabled,
                    onChanged: () => AppSettings.openAppSettings(type: AppSettingsType.bluetooth),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionChip(
                    label: "Chats",
                    icon: Icons.forum_outlined,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const NearbyChatListScreen())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ValueListenableBuilder<Box<NearbyUser>>(
                      valueListenable: _localCacheService.getNearbyUsersListenable(),
                      builder: (context, box, _) {
                        return _buildActionChip(
                          label: "Rankings",
                          icon: Icons.leaderboard_outlined,
                          onPressed: box.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const LocalLeaderboardScreen())),
                        );
                      }
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              _getStatusMessage(state),
              style: TextStyle(color: Colors.grey[700], fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            height: 200,
            child: SonarView(
              isScanning: isScanning,
              unleashController: _unleashController,
              discoveryController: _discoveryController,
              centerAvatar: _buildCenterAvatar(isScanning),
              foundUserAvatars: const [],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip({ required String label, required IconData icon, required bool isEnabled, required VoidCallback onChanged}) {
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
            Flexible(
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

  Widget _buildActionChip({required String label, required IconData icon, required VoidCallback? onPressed}) {
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
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: onPressed == null ? Colors.grey[400] : Colors.grey[800], fontSize: 12)
              ),
            ),
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
        backgroundImage: _currentUserPhotoUrl != null && _currentUserPhotoUrl!.isNotEmpty
            ? CachedNetworkImageProvider(_currentUserPhotoUrl!)
            : null,
        child: _currentUserPhotoUrl == null || _currentUserPhotoUrl!.isEmpty
            ? const Icon(Icons.person, size: 30, color: Colors.white)
            : null,
      ),
    );
  }


  // --- MODIFIED: _buildFoundUsersGrid now takes List<NearbyUser> ---
  Widget _buildFoundUsersGrid(List<NearbyUser> users) {
    final friendsBloc = BlocProvider.of<FriendsBloc>(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: GridView.builder(
        key: ValueKey('nearby_grid_${users.length}'),
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.8,
        ),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final nearbyUser = users[index];

          // Fetch the profile directly using the profileId from nearbyUser
          // Use ValueListenableBuilder scoped to this item for efficient updates
          return ValueListenableBuilder<Box<UserProfile>>(
              valueListenable: Hive.box<UserProfile>('userProfiles').listenable(keys: nearbyUser.profileId != null ? [nearbyUser.profileId!] : null),
              builder: (context, profileBox, _) {
                final userProfile = nearbyUser.profileId != null
                    ? _localCacheService.getUserProfile(nearbyUser.profileId!) // Use service getter
                    : null;

                // --- DEBUG ---
                debugPrint("NearbyScreen GridItemBuilder: User ${nearbyUser.uidShort}, Profile ID: ${nearbyUser.profileId}, Profile Found: ${userProfile != null}, Profile Name: ${userProfile?.name}");
                // --- END DEBUG ---

                final displayUser = ServerUserModel.UserModel(
                    id: userProfile?.profileId ?? nearbyUser.uidShort,
                    username: userProfile?.name ?? "User ${nearbyUser.uidShort.substring(0, 4)}",
                    photoUrl: userProfile?.photoUrl ?? '',
                    lastSeen: nearbyUser.lastSeen,
                    gender: userProfile?.gender ?? (nearbyUser.gender == 1 ? 'Male' : nearbyUser.gender == 2 ? 'Female' : ''),
                    level: userProfile?.level ?? 1,
                    xp: userProfile?.xp ?? 0,
                    interests: userProfile?.interests ?? [],
                    friends: userProfile?.friends ?? [],
                    friendRequestsSent: userProfile?.friendRequestsSent ?? [],
                    friendRequestsReceived: userProfile?.friendRequestsReceived ?? [],
                    blockedUsers: userProfile?.blockedUsers ?? [],
                    nearbyStatusMessage: userProfile?.nearbyStatusMessage ?? '',
                    nearbyStatusEmoji: userProfile?.nearbyStatusEmoji ?? '',
                    // Placeholders...
                    email: '', createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                    lastFreeSuperLike: DateTime.fromMillisecondsSinceEpoch(0),
                    lastNearbyDiscoveryDate: DateTime.fromMillisecondsSinceEpoch(0), age: 0,
                    currentSeasonId: '', seasonLevel: 0, seasonXp: 0,
                    claimedSeasonRewards: [], pictureVersion: 0, bio: '', fcmToken: '',
                    presence: false, coins: 0, superLikes: 0, equippedBadgeId: null,
                    equippedProfileFrameId: null, sharedMusicTrack: null, nearbyDataVersion: 0
                );

                int estimatedRssi = -59 - (nearbyUser.distance * 10).toInt().clamp(-40, 0);

                return BlocProvider.value(
                  value: friendsBloc,
                  child: NearbyUserCard(
                    key: ValueKey(nearbyUser.uidShort),
                    user: displayUser,
                    genderValue: nearbyUser.gender,
                    rssi: estimatedRssi,
                    lastSeen: nearbyUser.lastSeen,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: displayUser.id))),
                    onDelete: () => _deleteFoundUser(nearbyUser.uidShort),
                  ),
                );
              }
          );
        },
      ),
    );
  }
}

// --- Helper Widgets (_EmptyState, _SearchingState, etc.) remain the same ---
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


// Extension moved to sync_manager.dart where it's used
// extension LocalCacheServiceHelper on LocalCacheService { ... }