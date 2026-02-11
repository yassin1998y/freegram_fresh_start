// lib/screens/main_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
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
import 'package:freegram/repositories/friend_repository.dart';
import 'package:freegram/screens/improved_chat_list_screen.dart';
import 'package:freegram/screens/friends_list_screen.dart';
import 'package:freegram/screens/menu_screen.dart';
import 'package:freegram/screens/nearby_screen.dart';
import 'package:freegram/screens/notifications_screen.dart';
import 'package:freegram/screens/feed_screen.dart';
import 'package:freegram/screens/feed/for_you_feed_tab.dart'
    show kForYouFeedTabKey;
import 'package:freegram/screens/random_chat/random_chat_screen.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/guided_overlay.dart';
import 'package:freegram/widgets/navigation/main_bottom_nav.dart';
import 'package:freegram/widgets/core/hide_on_scroll_wrapper.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/services/gift_notification_service.dart';
import 'package:freegram/services/daily_reward_service.dart';
import 'package:freegram/widgets/gamification/daily_reward_dialog.dart';
import 'package:hive/hive.dart';

const bool _enableBlurEffects = true;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String _currentScreenName = 'Nearby';

  // Showcase keys for guided overlay
  final GlobalKey _guideFeedKey = GlobalKey();
  final GlobalKey _guideNearbyKey = GlobalKey();
  final GlobalKey _guideFriendsKey = GlobalKey();
  final GlobalKey _guideMenuKey = GlobalKey();
  bool _showGuide = false;

  // Scroll direction notifier for HideOnScrollWrapper
  final ValueNotifier<bool> _isScrollingDownNotifier =
      ValueNotifier<bool>(false);

  // User photo URL for Menu tab avatar
  String? _userPhotoUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserPhotoUrl();
    _initializeGiftNotifications();
    // Check for daily reward after a short delay to ensure UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), _checkDailyReward);
    });
  }

  @override
  void dispose() {
    // Stop listening to gift notifications
    try {
      locator<GiftNotificationService>().stopListening();
    } catch (e) {
      debugPrint('MainScreen: Error stopping gift notification listener: $e');
    }
    _isScrollingDownNotifier.dispose();
    super.dispose();
  }

  Future<void> _fetchUserPhotoUrl() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userModel = await locator<UserRepository>().getUser(user.uid);
        if (mounted) {
          setState(() {
            _userPhotoUrl = userModel.photoUrl;
          });
        }
      }
    } catch (e) {
      debugPrint('MainScreen: Error fetching user photo: $e');
    }
  }

  Future<void> _initializeGiftNotifications() async {
    try {
      final giftNotificationService = locator<GiftNotificationService>();

      // Start listening for new notifications
      giftNotificationService.startListening();

      // Check for pending notifications (gifts received while app was closed)
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await giftNotificationService.checkPendingNotifications();
      }

      debugPrint('MainScreen: Gift notification service initialized');
    } catch (e) {
      debugPrint('MainScreen: Error initializing gift notifications: $e');
    }
  }

  Future<void> _checkDailyReward() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final service = locator<DailyRewardService>();
      final status = await service.checkRewardStatus(user.uid);

      if (status == DailyRewardStatus.available) {
        // Fetch full user model for streak info
        final userModel = await locator<UserRepository>().getUser(user.uid);

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => DailyRewardDialog(
              userId: user.uid,
              currentStreak: userModel.dailyLoginStreak,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("⚠️ Daily Reward Check Failed: $e");
    }
  }

  void _maybeStartGuide() {
    try {
      final settingsBox = Hive.box('settings');
      final user = FirebaseAuth.instance.currentUser;
      final key = 'hasSeenMainShowcase_${user?.uid ?? 'guest'}';
      final hasSeen = settingsBox.get(key, defaultValue: false) as bool;
      if (!hasSeen && !_showGuide) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _showGuide = true);
        });
      }
    } catch (_) {}
  }

  void _onItemTapped(int index) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint(
          'MainScreen: Ignoring navigation tap - user not authenticated');
      return;
    }

    if (index < 0 || index > 4) return;

    // If tapping Feed while already on Feed: scroll to top and refresh
    if (index == 1 && _selectedIndex == 1) {
      kForYouFeedTabKey.currentState?.scrollToTopAndRefresh();
      return;
    }

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
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 SCREEN: main_screen.dart');
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is! Authenticated) {
          debugPrint("MainScreen: AuthState changed to ${state.runtimeType}.");
        }
      },
      buildWhen: (previous, current) => true,
      builder: (context, authState) {
        if (authState is! Authenticated) {
          if (kDebugMode) {
            debugPrint(
                "MainScreen: AuthState is not Authenticated (${authState.runtimeType}). Returning empty scaffold.");
          }
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const SizedBox.shrink(),
          );
        }

        final currentUser = authState.user;

        if (FirebaseAuth.instance.currentUser == null) {
          debugPrint(
              "MainScreen: WARNING - Authenticated state but FirebaseAuth has no user.");
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const SizedBox.shrink(),
          );
        }
        _maybeStartGuide();

        // Calculate bottom nav height for HideOnScrollWrapper
        // Account for nav bar height (DesignTokens.bottomNavBarHeight) + bottom padding + spacing
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final bottomNavHeight = DesignTokens.bottomNavBarHeight +
            bottomPadding +
            DesignTokens.spaceSM;

        return Stack(
          children: [
            Scaffold(
              extendBody: true,
              resizeToAvoidBottomInset: true,
              extendBodyBehindAppBar: _selectedIndex == 1,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                toolbarHeight:
                    kToolbarHeight + MediaQuery.of(context).padding.top,
                flexibleSpace: _buildBlurredAppBarBackground(context),
                title: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Freegram',
                        style:
                            Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: SonarPulseTheme.primaryAccent,
                                  fontSize: DesignTokens.fontSizeDisplay,
                                  height: DesignTokens.lineHeightTight,
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
                                  ?.copyWith(
                                    height: DesignTokens.lineHeightTight,
                                    color: Colors.blueAccent,
                                  ),
                            );
                          } else {
                            subtitle = Text(
                              _currentScreenName,
                              key: ValueKey(_currentScreenName),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    height: DesignTokens.lineHeightTight,
                                  ),
                            );
                          }
                          return AnimatedSwitcher(
                            duration: AnimationTokens.normal,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                    opacity: animation, child: child),
                            child: subtitle,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  _AppBarAction(
                    icon: Icons.chat_bubble_outline,
                    stream: locator<ChatRepository>()
                        .getUnreadChatCountStream(currentUser.uid),
                    onPressed: () => locator<NavigationService>().navigateTo(
                      const ImprovedChatListScreen(),
                      transition: PageTransition.slide,
                    ),
                  ),
                  _AppBarAction(
                    icon: Icons.notifications_outlined,
                    stream: locator<NotificationRepository>()
                        .getUnreadNotificationCountStream(currentUser.uid),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(DesignTokens.radiusXL)),
                        ),
                        builder: (modalContext) {
                          return DraggableScrollableSheet(
                            initialChildSize: 0.75,
                            minChildSize: 0.5,
                            maxChildSize: 0.95,
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
                    },
                  ),
                  const SizedBox(width: DesignTokens.spaceSM),
                ],
              ),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: Container(
                padding: EdgeInsets.only(
                  bottom: _selectedIndex == 1 ? 0 : bottomNavHeight,
                ),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _VisibilityWrapper(
                      isVisible: _selectedIndex == 0,
                      child: const NearbyScreen(),
                    ),
                    _VisibilityWrapper(
                      isVisible: _selectedIndex == 1,
                      child: FeedScreen(
                        isVisible: _selectedIndex == 1,
                        onScrollDirectionChanged: (isScrollingDown) {
                          _isScrollingDownNotifier.value = isScrollingDown;
                        },
                      ),
                    ),
                    _VisibilityWrapper(
                      isVisible: _selectedIndex == 2,
                      child: const RandomChatScreen(),
                    ),
                    _VisibilityWrapper(
                      isVisible: _selectedIndex == 3,
                      child: BlocProvider(
                        create: (_) => FriendsBloc(
                            userRepository: locator<UserRepository>(),
                            friendRepository: locator<FriendRepository>())
                          ..add(LoadFriends()),
                        child: const FriendsListScreen(hideBackButton: true),
                      ),
                    ),
                    _VisibilityWrapper(
                      isVisible: _selectedIndex == 4,
                      child: const MenuScreen(),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom navigation bar with HideOnScrollWrapper
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: HideOnScrollWrapper(
                scrollDirection: _isScrollingDownNotifier,
                height: bottomNavHeight,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: MainBottomNav(
                    selectedIndex: _selectedIndex,
                    onItemTapped: _onItemTapped,
                    userPhotoUrl: _userPhotoUrl,
                    showcaseKeys: {
                      0: _guideNearbyKey,
                      1: _guideFeedKey,
                      3: _guideFriendsKey,
                      4: _guideMenuKey,
                    },
                    enableBlurEffects: _enableBlurEffects,
                  ),
                ),
              ),
            ),
            if (_showGuide)
              GuidedOverlay(
                steps: [
                  GuideStep(
                    targetKey: _guideNearbyKey,
                    description: 'Discover people around you with Nearby.',
                    fallbackAlignment: Alignment.bottomCenter,
                  ),
                  GuideStep(
                    targetKey: _guideFeedKey,
                    description: 'See updates in your Feed.',
                    fallbackAlignment: Alignment.bottomCenter,
                  ),
                  GuideStep(
                    targetKey: _guideFriendsKey,
                    description: 'Manage your friends and requests here.',
                    fallbackAlignment: Alignment.bottomCenter,
                  ),
                  GuideStep(
                    targetKey: _guideMenuKey,
                    description: 'Access your profile and settings.',
                    fallbackAlignment: Alignment.bottomCenter,
                  ),
                ],
                onFinish: () {
                  setState(() => _showGuide = false);
                  final settingsBox = Hive.box('settings');
                  final user = FirebaseAuth.instance.currentUser;
                  final key = 'hasSeenMainShowcase_${user?.uid ?? 'guest'}';
                  settingsBox.put(key, true);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildBlurredAppBarBackground(BuildContext context) {
    final appBarColor =
        Theme.of(context).appBarTheme.backgroundColor ?? Colors.white;
    if (!_enableBlurEffects) return Container(color: appBarColor);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: DesignTokens.blurMedium, sigmaY: DesignTokens.blurMedium),
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
}

// AppBar action widget
class _AppBarAction extends StatefulWidget {
  final Stream<int>? stream;
  final IconData icon;
  final VoidCallback onPressed;

  const _AppBarAction({
    this.stream,
    required this.icon,
    required this.onPressed,
  });

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
      iconSize: DesignTokens.iconLG,
      color: Theme.of(context).iconTheme.color,
      onPressed: () {
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
    );

    if (widget.stream != null) {
      return Padding(
        padding:
            const EdgeInsets.all(DesignTokens.spaceSM - DesignTokens.spaceXS),
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

    return Padding(
      padding:
          const EdgeInsets.all(DesignTokens.spaceSM - DesignTokens.spaceXS),
      child: iconButton,
    );
  }
}

// Visibility wrapper to manage screen lifecycle
class _VisibilityWrapper extends StatefulWidget {
  final bool isVisible;
  final Widget child;

  const _VisibilityWrapper({
    required this.isVisible,
    required this.child,
  });

  @override
  State<_VisibilityWrapper> createState() => _VisibilityWrapperState();
}

class _VisibilityWrapperState extends State<_VisibilityWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.isVisible;

  @override
  void didUpdateWidget(_VisibilityWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      updateKeepAlive();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.isVisible || wantKeepAlive) {
      return Visibility(
        visible: widget.isVisible,
        maintainState: true,
        child: widget.child,
      );
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const SizedBox.shrink(),
    );
  }
}
