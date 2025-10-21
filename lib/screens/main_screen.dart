import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/repositories/notification_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/routes.dart';
import 'package:freegram/screens/chat_list_screen.dart';
import 'package:freegram/screens/create_post_screen.dart';
import 'package:freegram/screens/friends_list_screen.dart';
import 'package:freegram/screens/match_screen.dart';
import 'package:freegram/screens/menu_screen.dart';
import 'package:freegram/screens/nearby_screen.dart';
import 'package:freegram/screens/notifications_screen.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/screens/settings_screen.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/island_popup.dart';
import 'package:freegram/widgets/offline_overlay.dart';
import 'package:image_picker/image_picker.dart';
import 'package:freegram/screens/nearby_chat_list_screen.dart';

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
      radius: 38,
    );
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
  String _currentScreenName = 'Nearby';

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
      return true;
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
      case feedRoute:
        newIndex = 1;
        newScreenName = 'Feed';
        break;
      case matchRoute:
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
    }
    setState(() {
      if (newIndex != -1) {
        _selectedIndex = newIndex;
      }
      if (newScreenName.isNotEmpty) {
        _currentScreenName = newScreenName;
      }
    });
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    String routeName;
    switch (index) {
      case 0:
        routeName = nearbyRoute;
        break;
      case 1:
        routeName = feedRoute;
        break;
      case 2:
        routeName = matchRoute;
        break;
      case 3:
        routeName = friendsRoute;
        break;
      case 4:
        routeName = menuRoute;
        break;
      default:
        return;
    }
    _navigatorKey.currentState
        ?.pushNamedAndRemoveUntil(routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Authenticating...")));
    }

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        leading: _navigatorKey.currentState?.canPop() == true
            ? BackButton(onPressed: () => _navigatorKey.currentState?.pop())
            : null,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: _buildBlurredAppBarBackground(context),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Freegram',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: SonarPulseTheme.primaryAccent,
                fontSize: 24,
                height: 1.0,
              ),
            ),
            BlocBuilder<ConnectivityBloc, ConnectivityState>(
              builder: (context, state) {
                Widget subtitle;
                if (state is Offline) {
                  subtitle = Text(
                    "Bluetooth Only Mode",
                    key: const ValueKey('offline_mode'),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(height: 1.0, color: Colors.blueAccent),
                  );
                } else {
                  subtitle = Text(
                    _currentScreenName,
                    key: ValueKey(_currentScreenName),
                    style:
                    Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.0),
                  );
                }
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: subtitle,
                );
              },
            ),
          ],
        ),
        actions: [
          _AppBarAction(
            icon: Icons.chat_bubble_outline,
            stream:
            locator<ChatRepository>().getUnreadChatCountStream(currentUser.uid),
            onPressed: () {
              _navigatorKey.currentState?.pushNamed(chatListRoute);
            },
          ),
          _AppBarAction(
            icon: Icons.add_box_outlined,
            onPressed: () {
              showIslandPopup(
                context: context,
                message: "Feature coming soon!",
                icon: Icons.add_box_outlined,
              );
            },
          ),
          _AppBarAction(
            icon: Icons.notifications_outlined,
            stream: locator<NotificationRepository>()
                .getUnreadNotificationCountStream(currentUser.uid),
            onPressed: () {
              _navigatorKey.currentState?.pushNamed(notificationsRoute);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Navigator(
        key: _navigatorKey,
        initialRoute: nearbyRoute,
        onGenerateRoute: _onGenerateRoute,
        observers: [routeObserver],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onItemTapped(0),
        elevation: 2,
        backgroundColor: _selectedIndex == 0
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
        child: Icon(
          Icons.radar,
          color: _selectedIndex == 0
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).iconTheme.color,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        elevation: 0,
        padding: EdgeInsets.zero,
        color: Theme.of(context)
            .bottomAppBarTheme
            .color
            ?.withOpacity(_enableBlurEffects ? 0.85 : 1.0),
        child: _buildBlurredBottomNavBar(context),
      ),
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case nearbyRoute:
        page = const NearbyScreen();
        break;
      case feedRoute:
        page = const SimplifiedFeedWidget();
        break;
      case matchRoute:
        page = const MatchScreen();
        break;
      case friendsRoute:
        page = BlocProvider(
          create: (_) =>
          FriendsBloc(userRepository: locator<UserRepository>())..add(LoadFriends()),
          child: const FriendsListScreen(),
        );
        break;
      case menuRoute:
        page = const MenuScreen();
        break;
      case profileRoute:
        page = ProfileScreen(
            userId: (settings.arguments as String?) ??
                FirebaseAuth.instance.currentUser!.uid);
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
      default:
        page = const NearbyScreen();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateStateFromRoute(settings.name);
    });
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }

  Widget _buildBlurredAppBarBackground(BuildContext context) {
    Color appBarColor =
        Theme.of(context).appBarTheme.backgroundColor ?? Colors.white;
    if (!_enableBlurEffects) {
      return Container(color: appBarColor);
    }
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
                appBarColor.withOpacity(0.95),
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlurredBottomNavBar(BuildContext context) {
    Widget content = _buildBottomNavBarContent(context);

    if (!_enableBlurEffects) {
      return content;
    }

    return ClipPath(
      clipper: const BottomAppBarClipper(
        shape: CircularNotchedRectangle(),
        notchMargin: 8.0,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Stack(
          children: [
            Container(color: Colors.transparent),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBarContent(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final bool isLandscape = constraints.maxWidth > 500;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _BottomNavIcon(
              icon: Icons.public,
              label: 'Feed',
              isSelected: _selectedIndex == 1,
              isLandscape: isLandscape,
              onTap: () => _onItemTapped(1)),
          _BottomNavIcon(
              icon: Icons.whatshot_outlined,
              label: 'Match',
              isSelected: _selectedIndex == 2,
              isLandscape: isLandscape,
              onTap: () => _onItemTapped(2)),
          const SizedBox(width: 48),
          _BottomNavIcon(
              icon: Icons.people_outline,
              label: 'Friends',
              isSelected: _selectedIndex == 3,
              isLandscape: isLandscape,
              onTap: () => _onItemTapped(3)),
          _BottomNavIcon(
              icon: Icons.menu,
              label: 'Menu',
              isSelected: _selectedIndex == 4,
              isLandscape: isLandscape,
              onTap: () => _onItemTapped(4)),
        ],
      );
    });
  }
}

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
      },
    );

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
            child: iconButton,
          ),
        ),
      );
    }
    return Padding(padding: const EdgeInsets.all(6.0), child: iconButton);
  }
}

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
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).iconTheme.color;
    final fontWeight = isSelected ? FontWeight.bold : FontWeight.normal;
    const duration = Duration(milliseconds: 200);

    Widget content = isLandscape
        ? Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(fontSize: 12, fontWeight: fontWeight)),
      ],
    )
        : Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 26),
        const SizedBox(height: 1),
        Text(label,
            style: TextStyle(fontSize: 11, fontWeight: fontWeight)),
      ],
    );

    return Expanded(
      child: Tooltip(
        message: label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            customBorder: const CircleBorder(),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
              child: AnimatedTheme(
                data: ThemeData(
                  iconTheme: IconThemeData(color: color),
                  textTheme: TextTheme(bodySmall: TextStyle(color: color)),
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

class SimplifiedFeedWidget extends StatelessWidget {
  const SimplifiedFeedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityBloc, ConnectivityState>(
      builder: (context, state) {
        return Stack(
          children: [
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
                          Icon(Icons.public, size: 60, color: Colors.grey),
                          SizedBox(height: 16),
                          Text("Feed Feature Coming Soon",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                              "This is where you'll see posts from friends.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (state is Offline) const OfflineOverlay(),
          ],
        );
      },
    );
  }
}