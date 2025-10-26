// lib/screens/main_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/blocs/auth_bloc.dart'; // Keep for context if needed
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/repositories/notification_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
// Import Screens
import 'package:freegram/screens/chat_list_screen.dart';
import 'package:freegram/screens/friends_list_screen.dart';
import 'package:freegram/screens/match_screen.dart';
import 'package:freegram/screens/menu_screen.dart';
import 'package:freegram/screens/nearby_screen.dart';
import 'package:freegram/screens/notifications_screen.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/island_popup.dart';
import 'package:freegram/widgets/offline_overlay.dart';

const bool _enableBlurEffects = true; // Keep blur toggle

// BottomAppBarClipper remains the same
class BottomAppBarClipper extends CustomClipper<Path> {
  final CircularNotchedRectangle shape;
  final double notchMargin;
  const BottomAppBarClipper({required this.shape, required this.notchMargin});
  @override
  Path getClip(Size size) {
    final Rect host = Offset.zero & size;
    final Rect guest = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2), radius: 38);
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

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String _currentScreenName = 'Nearby'; // Default screen name

  // Simplified _onItemTapped for IndexedStack
  void _onItemTapped(int index) {
    debugPrint(
        'MainScreen: _onItemTapped called with index: $index, current _selectedIndex: $_selectedIndex');
    
    if (index < 0 || index > 4) return;
    
    setState(() {
      _selectedIndex = index;
      switch (index) {
        case 0:
          _currentScreenName = 'Nearby';
          break;
        case 1:
          _currentScreenName = 'Feed';
          break;
        case 2:
          _currentScreenName = 'Match';
          break;
        case 3:
          _currentScreenName = 'Friends';
          break;
        case 4:
          _currentScreenName = 'Menu';
          break;
      }
    });

    debugPrint(
        'MainScreen: Updated _selectedIndex to $_selectedIndex, _currentScreenName to $_currentScreenName');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is Unauthenticated) {
          // Show loading state while AuthWrapper handles the transition
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Signing out..."),
                ],
              ),
            ),
          );
        }
        
        if (authState is! Authenticated) {
          return const Scaffold(body: Center(child: Text("Authenticating...")));
        }
        
        final currentUser = authState.user;

    // Simplified Scaffold structure
    return Scaffold(
        extendBody: true, // Body behind bottom bar
        appBar: AppBar(
          // No back button - use device hardware back button
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent, // For blur effect
          elevation: 0,
            flexibleSpace:
                _buildBlurredAppBarBackground(context), // Blurred background
            title: Column(
              // Title/Subtitle structure
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                Text('Freegram',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: SonarPulseTheme.primaryAccent,
                        fontSize: 24,
                        height: 1.0)),
                BlocBuilder<ConnectivityBloc, ConnectivityState>(
                  // Connectivity/Screen Name subtitle
              builder: (context, state) {
                Widget subtitle;
                if (state is Offline) {
                      subtitle = Text("Bluetooth Only Mode",
                          key: const ValueKey('offline_mode'),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  height: 1.0, color: Colors.blueAccent));
                } else {
                      subtitle = Text(_currentScreenName,
                          key: ValueKey(_currentScreenName),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(height: 1.0));
                    }
                    return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: subtitle);
              },
            ),
          ],
        ),
            actions: [
              // AppBar actions
              _AppBarAction(
                // Chat action
            icon: Icons.chat_bubble_outline,
                stream: locator<ChatRepository>()
                    .getUnreadChatCountStream(currentUser.uid),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ChatListScreen(),
              ),
            ),
          ),
              _AppBarAction(
                  // Add action (placeholder)
              icon: Icons.add_box_outlined,
                  onPressed: () => showIslandPopup(
                      context: context,
                      message: "Create feature coming soon!",
                      icon: Icons.add_box_outlined)),
          // --- START: Notification Action Update (Fix #5) ---
              _AppBarAction(
                // Notification action
            icon: Icons.notifications_outlined,
                stream: locator<NotificationRepository>()
                    .getUnreadNotificationCountStream(currentUser.uid),
            onPressed: () {
              // --- Use showModalBottomSheet ---
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (modalContext) {
                  return DraggableScrollableSheet(
                    initialChildSize: 0.75, // Start at 75% height
                        minChildSize: 0.5, // Allow shrinking to 50%
                        maxChildSize: 0.95, // Allow expanding to 95%
                    expand: false,
                    builder: (_, scrollController) {
                      return NotificationsScreen(
                        isModal: true,
                        scrollController: scrollController,
                      );
                    },
                  );
                },
              );
              // --- Old Navigation (Removed): ---
              // _navigatorKey.currentState?.pushNamed(notificationsRoute);
            },
          ),
          // --- END: Notification Action Update ---
          const SizedBox(width: 8), // Padding
        ],
      ),
      // Simplified content area using IndexedStack
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const NearbyScreen(),
          const SimplifiedFeedWidget(),
          const MatchScreen(),
          BlocProvider(
                create: (_) =>
                    FriendsBloc(userRepository: locator<UserRepository>())
                      ..add(LoadFriends()),
            child: const FriendsListScreen(),
          ),
          const MenuScreen(),
        ],
      ),
          // Bottom Navigation Bar - Flat design with 5 buttons
          bottomNavigationBar: _buildFlatBottomNavBar(context, currentUser),
    );
      },
    );
  }

  // --- Helper Build Methods remain the same ---
  Widget _buildBlurredAppBarBackground(BuildContext context) {
    Color appBarColor =
        Theme.of(context).appBarTheme.backgroundColor ?? Colors.white;
    if (!_enableBlurEffects) return Container(color: appBarColor);
    return ClipRect(
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
                decoration: BoxDecoration(
                    color: appBarColor.withOpacity(0.85),
                    gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          appBarColor.withOpacity(0.85),
                          appBarColor.withOpacity(0.95)
                        ],
                        stops: const [
                          0.0,
                          1.0
                        ])))));
  }

  Widget _buildFlatBottomNavBar(BuildContext context, User currentUser) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        constraints: const BoxConstraints(minHeight: 65),
        decoration: BoxDecoration(
          color: _enableBlurEffects
              ? Theme.of(context).bottomAppBarTheme.color?.withOpacity(0.85)
              : Theme.of(context).bottomAppBarTheme.color,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
              width: 0.5,
            ),
          ),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: _enableBlurEffects
                ? ImageFilter.blur(sigmaX: 15, sigmaY: 15)
                : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _FlatBottomNavIcon(
                  icon: Icons.public,
                  label: 'Feed',
                  isSelected: _selectedIndex == 1,
                  onTap: () => _onItemTapped(1),
                ),
                _FlatBottomNavIcon(
                  icon: Icons.whatshot_outlined,
                  label: 'Match',
                  isSelected: _selectedIndex == 2,
                  onTap: () => _onItemTapped(2),
                ),
                _GlassmorphicCenterButton(
                  icon: Icons.radar,
                  label: 'Nearby',
                  isSelected: _selectedIndex == 0,
                  onTap: () => _onItemTapped(0),
                ),
                _FlatBottomNavIcon(
                  icon: Icons.people_outline,
                  label: 'Friends',
                  isSelected: _selectedIndex == 3,
                  onTap: () => _onItemTapped(3),
                ),
                _FlatBottomNavIcon(
                  icon: Icons.menu,
                  label: 'Menu',
                  isSelected: _selectedIndex == 4,
                  onTap: () => _onItemTapped(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} // End _MainScreenState

// _AppBarAction remains the same
class _AppBarAction extends StatefulWidget {
  final Stream<int>? stream;
  final IconData icon;
  final VoidCallback onPressed;
  const _AppBarAction(
      {this.stream, required this.icon, required this.onPressed});
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
        color: Theme.of(context).iconTheme.color,
        onPressed: () {
          HapticFeedback.lightImpact();
          widget.onPressed();
        });
    if (widget.stream != null) {
      return Padding(
          padding: const EdgeInsets.all(6.0),
          child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onPressed();
              },
              child: Badge(
                  label: Text(_count.toString()),
                  isLabelVisible: _count > 0,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: iconButton)));
    }
    return Padding(padding: const EdgeInsets.all(6.0), child: iconButton);
  }
}

// New Flat Bottom Nav Icon Widget
class _FlatBottomNavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FlatBottomNavIcon({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).iconTheme.color?.withOpacity(0.7);

    final fontWeight = isSelected ? FontWeight.w600 : FontWeight.normal;

    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: fontWeight,
                    color: color,
                    height: 1.0,
                  ),
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Glassmorphic Center Button for Nearby
class _GlassmorphicCenterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GlassmorphicCenterButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = SonarPulseTheme.primaryAccent;

    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glassmorphic container with animated glow
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentColor.withOpacity(0.4),
                              primaryColor.withOpacity(0.3),
                            ],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primaryColor.withOpacity(0.15),
                              primaryColor.withOpacity(0.08),
                            ],
                          ),
                    border: Border.all(
                      color: isSelected
                          ? accentColor.withOpacity(0.6)
                          : primaryColor.withOpacity(0.3),
                      width: isSelected ? 2 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: accentColor.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 22,
                      color: isSelected
                          ? Colors.white
                          : primaryColor.withOpacity(0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? accentColor
                        : primaryColor.withOpacity(0.9),
                    height: 1.0,
                  ),
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// SimplifiedFeedWidget placeholder remains the same
class SimplifiedFeedWidget extends StatelessWidget {
  const SimplifiedFeedWidget({super.key});
  @override
  Widget build(BuildContext context) {
    /* ... Placeholder UI ... */
    return BlocBuilder<ConnectivityBloc, ConnectivityState>(
        builder: (context, state) {
      return Stack(children: [
        RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 1));
            },
            child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height -
                            (Scaffold.of(context).appBarMaxHeight ?? 0)),
                    child: const Center(
                        child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.public,
                                      size: 60, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text("Feed Feature Coming Soon",
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      "This is where you'll see posts from friends.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey))
                                ])))))),
        if (state is Offline) const OfflineOverlay()
      ]);
    });
  }
}
