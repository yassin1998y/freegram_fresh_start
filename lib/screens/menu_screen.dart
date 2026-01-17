import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/navigation/app_routes.dart';
import 'package:freegram/services/user_stream_provider.dart';
import 'package:freegram/screens/moderation_dashboard_screen.dart';
import 'package:freegram/screens/feature_discovery_screen.dart';
import 'package:freegram/screens/referral_screen.dart';
import 'package:freegram/screens/qr_display_screen.dart';
import 'package:freegram/screens/create_page_screen.dart';
import 'package:freegram/screens/page_profile_screen.dart';
import 'package:freegram/repositories/page_repository.dart';
import 'package:freegram/models/page_model.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  // OPTIMIZATION: Use stream instead of one-time Firestore call for admin check
  // This allows real-time updates if admin status changes
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _userStreamSubscription;
  bool _isAdmin = false;
  bool _isLoadingUser = true;

  // Pages management
  final PageRepository _pageRepository = locator<PageRepository>();
  List<PageModel> _myPages = [];
  bool _loadingPages = false;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: menu_screen.dart');
    _listenToUserStream();
    _loadMyPages();
  }

  // OPTIMIZATION: Load pages once on init
  Future<void> _loadMyPages() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _loadingPages = true);
    try {
      final pages = await _pageRepository.getUserPages(currentUser.uid);
      if (mounted) {
        setState(() {
          _myPages = pages;
          _loadingPages = false;
        });
      }
    } catch (e) {
      debugPrint('MenuScreen: Error loading pages: $e');
      if (mounted) setState(() => _loadingPages = false);
    }
  }

  // OPTIMIZATION: Listen to user stream to get admin status and user data
  void _listenToUserStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoadingUser = false;
      });
      return;
    }

    // Listen to Firestore document directly for admin status
    // This is more efficient than separate getUserStream + admin check
    _userStreamSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((docSnapshot) {
      if (mounted) {
        if (docSnapshot.exists) {
          final userData = docSnapshot.data()!;
          final isAdmin = userData['isAdmin'] == true ||
              userData['role'] == 'admin' ||
              userData['admin'] == true;
          setState(() {
            _isAdmin = isAdmin;
            _isLoadingUser = false;
          });
        } else {
          setState(() {
            _isAdmin = false;
            _isLoadingUser = false;
          });
        }
      }
    }, onError: (error) {
      debugPrint('MenuScreen: Error listening to user stream: $error');
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _userStreamSubscription?.cancel();
    // CRITICAL: Release user stream subscription
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      UserStreamProvider().releaseUserStream(currentUser.uid);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<UserModel>(
        stream: currentUser != null
            ? UserStreamProvider().getUserStream(currentUser.uid)
            : null,
        builder: (context, snapshot) {
          final user = snapshot.data;
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          return CustomScrollView(
            slivers: [
              // UX IMPROVEMENT: User profile header with avatar and info
              SliverToBoxAdapter(
                child: _buildUserHeader(context, user, isLoading),
              ),

              // Main menu items in cards
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMD,
                  vertical: DesignTokens.spaceSM,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildMenuSection(
                      context,
                      title: 'Account',
                      children: [
                        _MenuTile(
                          icon: Icons.person_outline,
                          title: 'My Profile',
                          subtitle: 'View and edit your profile',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            locator<NavigationService>().navigateNamed(
                              AppRoutes.profile,
                              arguments: {
                                'userId': currentUser!.uid,
                              },
                            );
                          },
                        ),
                        _MenuTile(
                          icon: Icons.qr_code_2_outlined,
                          title: 'My QR Code',
                          subtitle: 'Share your profile QR code',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (user != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      QrDisplayScreen(user: user),
                                ),
                              );
                            }
                          },
                        ),
                        _MenuTile(
                          icon: Icons.person_add_alt_1_outlined,
                          title: 'Invite Friends',
                          subtitle: 'Earn coins by referring friends',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: Colors.amber.withOpacity(0.5)),
                            ),
                            child: const Text("New",
                                style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ReferralScreen(),
                              ),
                            );
                          },
                        ),
                        _MenuTile(
                          icon: Icons.settings_outlined,
                          title: 'Settings',
                          subtitle: 'App preferences and privacy',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            locator<NavigationService>()
                                .navigateNamed(AppRoutes.settings);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spaceMD),
                    _buildMenuSection(
                      context,
                      title: 'Pages',
                      children: [
                        if (_loadingPages)
                          const Padding(
                            padding: EdgeInsets.all(DesignTokens.spaceMD),
                            child: Center(
                              child: AppProgressIndicator(
                                size: DesignTokens.iconMD,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        else if (_myPages.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(DesignTokens.spaceMD),
                            child: Text(
                              'No pages yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color:
                                        SemanticColors.textSecondary(context),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ..._myPages.take(3).map((page) => _MenuTile(
                                icon: Icons.storefront_outlined,
                                title: page.pageName,
                                subtitle: '@${page.pageHandle}',
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PageProfileScreen(
                                          pageId: page.pageId),
                                    ),
                                  );
                                },
                              )),
                        _MenuTile(
                          icon: Icons.add_circle_outline,
                          title: _myPages.isEmpty
                              ? 'Create Page'
                              : 'View All Pages',
                          subtitle: _myPages.isEmpty
                              ? 'Start your first page'
                              : '${_myPages.length} page${_myPages.length != 1 ? 's' : ''}',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (_myPages.isEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CreatePageScreen(),
                                ),
                              );
                            } else {
                              _showAllPages(context);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spaceMD),
                    _buildMenuSection(
                      context,
                      title: 'Explore',
                      children: [
                        _MenuTile(
                          icon: Icons.storefront_outlined,
                          title: 'Store',
                          subtitle: 'Premium features and coins',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            locator<NavigationService>()
                                .navigateNamed(AppRoutes.store);
                          },
                        ),
                        _MenuTile(
                          icon: Icons.school_outlined,
                          title: 'Feature Discovery',
                          subtitle: 'Learn about app features',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const FeatureDiscoveryScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    if (_isAdmin && !_isLoadingUser) ...[
                      const SizedBox(height: DesignTokens.spaceMD),
                      _buildMenuSection(
                        context,
                        title: 'Admin',
                        children: [
                          _MenuTile(
                            icon: Icons.gavel,
                            title: 'Moderation Dashboard',
                            subtitle: 'Manage content and users',
                            color: SemanticColors.warning,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ModerationDashboardScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: DesignTokens.spaceMD),
                    _buildMenuSection(
                      context,
                      children: [
                        _MenuTile(
                          icon: Icons.logout,
                          title: 'Logout',
                          subtitle: 'Sign out of your account',
                          color: theme.colorScheme.error,
                          onTap: () => _handleLogout(context),
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // UX IMPROVEMENT: Modern user header with avatar and info
  Widget _buildUserHeader(
    BuildContext context,
    UserModel? user,
    bool isLoading,
  ) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      margin: const EdgeInsets.all(DesignTokens.spaceMD),
      padding: const EdgeInsets.all(DesignTokens.spaceLG),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        boxShadow: DesignTokens.shadowLight,
      ),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (currentUser != null) {
                locator<NavigationService>().navigateNamed(
                  AppRoutes.profile,
                  arguments: {'userId': currentUser.uid},
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: AvatarSize.medium.radius,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage:
                    (user?.photoUrl != null && user!.photoUrl.isNotEmpty)
                        ? CachedNetworkImageProvider(user.photoUrl)
                        : null,
                child: (user?.photoUrl == null || user!.photoUrl.isEmpty)
                    ? Icon(
                        Icons.person,
                        size: DesignTokens.iconLG,
                        color: theme.colorScheme.onSurface.withOpacity(
                          DesignTokens.opacityMedium,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.spaceMD),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoading)
                  SizedBox(
                    height: DesignTokens.fontSizeLG,
                    width: 120,
                    child: LinearProgressIndicator(
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  )
                else
                  Text(
                    user?.username ?? 'User',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: DesignTokens.fontSizeXXL,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: DesignTokens.spaceXS),
                if (!isLoading && user != null)
                  Text(
                    user.email.isNotEmpty
                        ? user.email
                        : (currentUser?.email ?? ''),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: SemanticColors.textSecondary(context),
                      fontSize: DesignTokens.fontSizeSM,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Profile arrow
          Icon(
            Icons.chevron_right,
            color: SemanticColors.iconDefault(context),
            size: DesignTokens.iconMD,
          ),
        ],
      ),
    );
  }

  // UX IMPROVEMENT: Grouped menu sections with cards
  Widget _buildMenuSection(
    BuildContext context, {
    String? title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spaceMD,
                DesignTokens.spaceMD,
                DesignTokens.spaceMD,
                DesignTokens.spaceSM,
              ),
              child: Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: SemanticColors.textSecondary(context),
                  fontSize: DesignTokens.fontSizeSM,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: theme.dividerColor,
            ),
          ],
          ...children,
        ],
      ),
    );
  }

  // UX IMPROVEMENT: Better logout dialog with design tokens
  Future<void> _handleLogout(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final theme = Theme.of(context);
    final authBloc = context.read<AuthBloc>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
        ),
        title: Text(
          'Confirm Logout',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: theme.textTheme.labelLarge,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text(
              'Logout',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      authBloc.add(SignOut());

      // Show loading overlay
      if (context.mounted) {
        showDialog(
          context: context,
          useRootNavigator:
              false, // CRITICAL FIX: Use inner navigator to access AuthBloc provider
          barrierDismissible: false,
          barrierColor: Theme.of(context).colorScheme.scrim.withOpacity(0.5),
          builder: (context) => PopScope(
            canPop: false,
            child: BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is Unauthenticated) {
                  Navigator.of(context).pop();
                }
              },
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(DesignTokens.spaceXL),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
                    boxShadow: DesignTokens.shadowFloating,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppProgressIndicator(),
                      const SizedBox(height: DesignTokens.spaceMD),
                      Text(
                        'Signing out...',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
  }

  // UX IMPROVEMENT: Show all pages in a bottom sheet
  void _showAllPages(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusXL),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin:
                    const EdgeInsets.symmetric(vertical: DesignTokens.spaceSM),
                width: DesignTokens.bottomSheetHandleWidth,
                height: DesignTokens.bottomSheetHandleHeight,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
                child: Row(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: DesignTokens.spaceSM),
                    Text(
                      'Your Pages',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(DesignTokens.spaceMD),
                  itemCount: _myPages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _myPages.length) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(top: DesignTokens.spaceSM),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreatePageScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Create New Page'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: DesignTokens.spaceMD,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusMD),
                            ),
                          ),
                        ),
                      );
                    }
                    final page = _myPages[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        backgroundImage: page.profileImageUrl.isNotEmpty
                            ? CachedNetworkImageProvider(page.profileImageUrl)
                            : null,
                        child: page.profileImageUrl.isEmpty
                            ? Icon(
                                Icons.flag_outlined,
                                color: SemanticColors.textSecondary(context),
                              )
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(page.pageName)),
                          if (page.verificationStatus ==
                              VerificationStatus.verified) ...[
                            const SizedBox(width: DesignTokens.spaceSM),
                            const Icon(
                              Icons.verified,
                              size: 18,
                              color: SemanticColors.info,
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text('@${page.pageHandle}'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PageProfileScreen(pageId: page.pageId),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// UX IMPROVEMENT: Modern menu tile with better visual design
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;
  final Widget? trailing;

  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor = color ?? SemanticColors.textPrimary(context);
    final isDestructive = color == theme.colorScheme.error;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMD,
            vertical: DesignTokens.spaceSM,
          ),
          child: Row(
            children: [
              // Icon container with background
              Container(
                width: DesignTokens.iconXXL,
                height: DesignTokens.iconXXL,
                decoration: BoxDecoration(
                  color: (isDestructive
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                ),
                child: Icon(
                  icon,
                  color: tileColor,
                  size: DesignTokens.iconMD,
                ),
              ),
              const SizedBox(width: DesignTokens.spaceMD),
              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: tileColor,
                        fontWeight: FontWeight.w600,
                        fontSize: DesignTokens.fontSizeMD,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: DesignTokens.spaceXS / 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: SemanticColors.textSecondary(context),
                          fontSize: DesignTokens.fontSizeXS,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: DesignTokens.spaceSM),
                trailing!,
              ],
              // Chevron
              Icon(
                Icons.chevron_right,
                color: SemanticColors.iconDefault(context),
                size: DesignTokens.iconMD,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
