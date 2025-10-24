import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/blocs/auth_bloc.dart'; // Keep if used indirectly
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart'; // Keep
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/chat_repository.dart'; // Keep
import 'package:freegram/repositories/notification_repository.dart'; // Keep
import 'package:freegram/repositories/user_repository.dart'; // Keep
import 'package:freegram/routes.dart'; // Keep all routes based on correction
import 'package:freegram/screens/chat_list_screen.dart'; // Keep
// import 'package:freegram/screens/create_post_screen.dart'; // Remove
import 'package:freegram/screens/friends_list_screen.dart'; // Keep
import 'package:freegram/screens/match_screen.dart'; // Keep
import 'package:freegram/screens/menu_screen.dart'; // Keep
import 'package:freegram/screens/nearby_screen.dart'; // Keep
import 'package:freegram/screens/notifications_screen.dart'; // Keep
import 'package:freegram/screens/profile_screen.dart'; // Keep
import 'package:freegram/screens/settings_screen.dart'; // Keep
import 'package:freegram/theme/app_theme.dart'; // Keep
import 'package:freegram/widgets/island_popup.dart'; // Keep
import 'package:freegram/widgets/offline_overlay.dart'; // Keep
// import 'package:image_picker/image_picker.dart'; // Remove if not used here
import 'package:freegram/screens/nearby_chat_list_screen.dart'; // Keep

const bool _enableBlurEffects = true;

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class BottomAppBarClipper extends CustomClipper<Path> {
  final CircularNotchedRectangle shape;
  final double notchMargin;

  const BottomAppBarClipper({
    required this.shape,
    required this.notchMargin,
  });

  @override
  Path getClip(Size size) {
    final Rect host = Offset.zero & size;
    final Rect guest = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: 38, // Adjust if FAB size changes
    );
    // Use the shape's method to get the path
    return shape.getOuterPath(host, guest);
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with RouteAware {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  int _selectedIndex = 0;
  String _currentScreenName = 'Nearby'; // Default

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // didPush, didPopNext, _updateStateFromNavigator, _updateStateFromRoute remain the same
  @override
  void didPush() {
    _updateStateFromNavigator();
  }

  @override
  void didPopNext() {
    _updateStateFromNavigator();
  }

  void _updateStateFromNavigator() {
    _navigatorKey.currentState?.popUntil((route) {
      _updateStateFromRoute(route.settings.name);
      return true; // We always return true to stop popping immediately
    });
  }

  void _updateStateFromRoute(String? routeName) {
    int newIndex = -1;
    String newScreenName = '';

    switch (routeName) {
      case nearbyRoute:
        newIndex = 0;
        newScreenName = 'Nearby';
        break;
      case feedRoute: // Keep Feed
        newIndex = 1;
        newScreenName = 'Feed';
        break;
      case matchRoute: // Keep Match
        newIndex = 2;
        newScreenName = 'Match';
        break;
      case friendsRoute:
        newIndex = 3;
        newScreenName = 'Friends';
        break;
      case menuRoute:
        newIndex = 4;
        newScreenName = 'Menu';
        break;
    // Handle other routes pushed onto the stack
      case profileRoute: newScreenName = 'Profile'; break;
      case settingsRoute: newScreenName = 'Settings'; break;
      case notificationsRoute: newScreenName = 'Notifications'; break;
      case chatListRoute: newScreenName = 'Messages'; break;
    // Add cases for other non-tab routes if needed
    }
    // Update state only if a valid index or name was found
    if (newIndex != -1 || newScreenName.isNotEmpty) {
      setState(() {
        if (newIndex != -1) {
          _selectedIndex = newIndex;
        }
        if (newScreenName.isNotEmpty) {
          _currentScreenName = newScreenName;
        }
      });
    }
  }


  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; // Don't reload if already selected

    String routeName;
    switch (index) {
      case 0:
        routeName = nearbyRoute;
        break;
      case 1: // Keep Feed
        routeName = feedRoute;
        break;
      case 2: // Keep Match
        routeName = matchRoute;
        break;
      case 3:
        routeName = friendsRoute;
        break;
      case 4:
        routeName = menuRoute;
        break;
      default:
        return; // Should not happen
    }
    // Use pushNamedAndRemoveUntil to clear the stack for the selected tab
    _navigatorKey.currentState?.pushNamedAndRemoveUntil(routeName, (route) => false);
    // The RouteAware logic will update _selectedIndex and _currentScreenName
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // This should ideally not happen if AuthWrapper is working correctly
      return const Scaffold(body: Center(child: Text("Authenticating...")));
    }

    return Scaffold(
      extendBody: true, // Allows body to go behind bottom bar
      appBar: AppBar(
        // Conditional back button
        leading: _navigatorKey.currentState?.canPop() == true
            ? BackButton(onPressed: () => _navigatorKey.currentState?.pop())
            : null,
        backgroundColor: Colors.transparent, // For blur effect
        elevation: 0,
        flexibleSpace: _buildBlurredAppBarBackground(context),
        title: Column( // Keep title structure
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text( // App Title
              'Freegram',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: SonarPulseTheme.primaryAccent,
                fontSize: 24, // Slightly smaller perhaps
                height: 1.0, // Adjust line height
              ),
            ),
            BlocBuilder<ConnectivityBloc, ConnectivityState>( // Keep subtitle logic
              builder: (context, state) {
                Widget subtitle;
                if (state is Offline) {
                  subtitle = Text(
                    "Bluetooth Only Mode",
                    key: const ValueKey('offline_mode'), // Key for AnimatedSwitcher
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.0, color: Colors.blueAccent),
                  );
                } else {
                  subtitle = Text(
                    _currentScreenName,
                    key: ValueKey(_currentScreenName), // Key for AnimatedSwitcher
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.0),
                  );
                }
                // Animate subtitle changes
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: subtitle,
                );
              },
            ),
          ],
        ),
        actions: [ // Keep actions
          _AppBarAction(
            icon: Icons.chat_bubble_outline,
            stream: locator<ChatRepository>().getUnreadChatCountStream(currentUser.uid),
            onPressed: () {
              _navigatorKey.currentState?.pushNamed(chatListRoute);
            },
          ),
          _AppBarAction(
              icon: Icons.add_box_outlined, // Keep Add icon
              onPressed: () {
                // Remove Post/Reel creation logic, show placeholder
                showIslandPopup(
                  context: context,
                  message: "Create feature coming soon!", // Updated message
                  icon: Icons.add_box_outlined,
                );
              }),
          _AppBarAction(
            icon: Icons.notifications_outlined,
            stream: locator<NotificationRepository>().getUnreadNotificationCountStream(currentUser.uid),
            onPressed: () {
              _navigatorKey.currentState?.pushNamed(notificationsRoute);
            },
          ),
          const SizedBox(width: 8), // Keep padding
        ],
      ),
      // Use the nested Navigator
      body: Navigator(
        key: _navigatorKey,
        initialRoute: nearbyRoute, // Start on Nearby
        onGenerateRoute: _onGenerateRoute,
        observers: [routeObserver], // Add observer here
      ),
      floatingActionButton: FloatingActionButton( // Keep FAB for Nearby
        onPressed: () => _onItemTapped(0), // Always navigates to Nearby
        elevation: 2,
        backgroundColor: _selectedIndex == 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
        foregroundColor: _selectedIndex == 0 ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).iconTheme.color,
        child: const Icon(Icons.radar), // Sonar icon
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar( // Keep BottomAppBar
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        elevation: 0,
        padding: EdgeInsets.zero, // Important for blur clipper
        color: Theme.of(context).bottomAppBarTheme.color?.withOpacity(_enableBlurEffects ? 0.85 : 1.0), // Apply opacity for blur
        child: _buildBlurredBottomNavBar(context), // Use blur wrapper
      ),
    );
  }

  // _onGenerateRoute needs update to remove deleted screens but keep Feed/Match
  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case nearbyRoute:
        page = const NearbyScreen();
        break;
      case feedRoute: // Keep Feed route, point to placeholder
        page = const SimplifiedFeedWidget(); // Use the existing placeholder
        break;
      case matchRoute: // Keep Match route
        page = const MatchScreen();
        break;
      case friendsRoute:
        page = BlocProvider( // Keep Friends Bloc setup
          create: (_) => FriendsBloc(userRepository: locator<UserRepository>())..add(LoadFriends()),
          child: const FriendsListScreen(),
        );
        break;
      case menuRoute:
        page = const MenuScreen();
        break;
    // Keep routes pushed onto the stack
      case profileRoute:
        page = ProfileScreen(userId: (settings.arguments as String?) ?? FirebaseAuth.instance.currentUser!.uid);
        break;
      case settingsRoute:
        page = const SettingsScreen();
        break;
      case notificationsRoute:
        page = const NotificationsScreen();
        break;
      case chatListRoute:
        page = const ChatListScreen();
        break;
    // Add case for NearbyChatListScreen if needed, or handle its push separately
    // case '/nearbyChatList': page = const NearbyChatListScreen(); break;
      default:
      // Fallback to Nearby screen if route is unknown
        page = const NearbyScreen();
    }
    // Update state after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateStateFromRoute(settings.name);
    });
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }

  // _buildBlurredAppBarBackground remains the same
  Widget _buildBlurredAppBarBackground(BuildContext context) {
    Color appBarColor = Theme.of(context).appBarTheme.backgroundColor ?? Colors.white;
    if (!_enableBlurEffects) {
      return Container(color: appBarColor); // Solid color if blur disabled
    }
    return ClipRect( // Clip to prevent blur extending beyond AppBar bounds
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          // Use AppBar color with opacity
          decoration: BoxDecoration(
            color: appBarColor.withOpacity(0.85),
            // Optional: Add a subtle gradient if desired
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                appBarColor.withOpacity(0.85),
                appBarColor.withOpacity(0.95), // Slightly less transparent at the top
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  // _buildBlurredBottomNavBar remains the same
  Widget _buildBlurredBottomNavBar(BuildContext context) {
    Widget content = _buildBottomNavBarContent(context); // Get the actual icons/labels

    if (!_enableBlurEffects) {
      return content; // Return plain content if blur disabled
    }

    // Apply clipping and blur if enabled
    return ClipPath(
      clipper: const BottomAppBarClipper( // Use the custom clipper
        shape: CircularNotchedRectangle(),
        notchMargin: 8.0,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Stack(
          children: [
            // This container ensures the BackdropFilter has something to blur
            Container(color: Colors.transparent),
            content, // Place the actual content on top of the blur
          ],
        ),
      ),
    );
  }

  // _buildBottomNavBarContent needs update for items
  Widget _buildBottomNavBarContent(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final bool isLandscape = constraints.maxWidth > 500; // Example breakpoint
      // Keep Feed (index 1) and Match (index 2)
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _BottomNavIcon(icon: Icons.public, label: 'Feed', isSelected: _selectedIndex == 1, isLandscape: isLandscape, onTap: () => _onItemTapped(1)), // Index 1
          _BottomNavIcon(icon: Icons.whatshot_outlined, label: 'Match', isSelected: _selectedIndex == 2, isLandscape: isLandscape, onTap: () => _onItemTapped(2)), // Index 2
          const SizedBox(width: 48), // Spacer for FAB notch
          _BottomNavIcon(icon: Icons.people_outline, label: 'Friends', isSelected: _selectedIndex == 3, isLandscape: isLandscape, onTap: () => _onItemTapped(3)), // Index 3
          _BottomNavIcon(icon: Icons.menu, label: 'Menu', isSelected: _selectedIndex == 4, isLandscape: isLandscape, onTap: () => _onItemTapped(4)), // Index 4
        ],
      );
    });
  }

}

// _AppBarAction remains the same
class _AppBarAction extends StatefulWidget {
  final Stream<int>? stream; // Optional stream for badge count
  final IconData icon;
  final VoidCallback onPressed;
  const _AppBarAction({this.stream, required this.icon, required this.onPressed});

  @override
  State<_AppBarAction> createState() => _AppBarActionState();
}
class _AppBarActionState extends State<_AppBarAction> {
  StreamSubscription? _subscription;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    if (widget.stream != null) {
      _subscription = widget.stream!.listen((count) {
        if (mounted) setState(() => _count = count);
      });
    }
  }
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget iconButton = IconButton(
      icon: Icon(widget.icon),
      iconSize: 26,
      color: Theme.of(context).iconTheme.color, // Use theme color
      onPressed: () {
        HapticFeedback.lightImpact(); // Add haptic feedback
        widget.onPressed();
      },
    );

    // If a stream is provided, wrap with Badge
    if (widget.stream != null) {
      return Padding(
        padding: const EdgeInsets.all(6.0), // Consistent padding
        child: GestureDetector( // Allow tapping the badge area too
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onPressed();
          },
          child: Badge(
            label: Text(_count.toString()),
            isLabelVisible: _count > 0,
            backgroundColor: Theme.of(context).colorScheme.primary, // Use theme color
            child: iconButton,
          ),
        ),
      );
    }
    // Otherwise, just return the button with padding
    return Padding(padding: const EdgeInsets.all(6.0), child: iconButton);
  }
}

// _BottomNavIcon remains the same
class _BottomNavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isLandscape;
  final VoidCallback onTap;

  const _BottomNavIcon({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isLandscape,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).iconTheme.color;
    final fontWeight = isSelected ? FontWeight.bold : FontWeight.normal;
    const duration = Duration(milliseconds: 200); // Animation duration

    // Different layout for landscape
    Widget content = isLandscape
        ? Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22), // Slightly smaller icon
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: fontWeight)),
      ],
    )
        : Column( // Portrait layout
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 26),
        const SizedBox(height: 1), // Minimal spacing
        Text(label, style: TextStyle(fontSize: 11, fontWeight: fontWeight)),
      ],
    );

    return Expanded( // Ensure icons take up equal space
      child: Tooltip(
        message: label,
        child: Material(
          type: MaterialType.transparency, // Allows ink splash
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact(); // Haptic feedback
              onTap();
            },
            customBorder: const CircleBorder(), // Nice ripple effect
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
              // Animate theme changes (color)
              child: AnimatedTheme(
                data: ThemeData(
                  iconTheme: IconThemeData(color: color),
                  textTheme: TextTheme(bodySmall: TextStyle(color: color)), // Apply color to text via theme
                ),
                duration: duration,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// SimplifiedFeedWidget remains the same (Placeholder)
class SimplifiedFeedWidget extends StatelessWidget {
  const SimplifiedFeedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityBloc, ConnectivityState>(
      builder: (context, state) {
        return Stack( // Keep stack for offline overlay
          children: [
            RefreshIndicator(
              onRefresh: () async {
                // Placeholder refresh
                await Future.delayed(const Duration(seconds: 1));
              },
              child: SingleChildScrollView( // Ensure content is scrollable for RefreshIndicator
                physics: const AlwaysScrollableScrollPhysics(), // Always allow scroll
                child: ConstrainedBox( // Ensure minimum height for centering
                  constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - (Scaffold.of(context).appBarMaxHeight ?? 0)),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.public, size: 60, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            "Feed Feature Coming Soon", // Message
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "This is where you'll see posts from friends.", // Sub message
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (state is Offline) const OfflineOverlay(), // Show overlay if offline
          ],
        );
      },
    );
  }
}