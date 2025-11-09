import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/navigation/app_routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/screens/moderation_dashboard_screen.dart';
import 'package:freegram/screens/feature_discovery_screen.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _isAdmin = false;
  bool _checkingAdmin = true;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: menu_screen.dart');
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _checkingAdmin = false;
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final isAdmin = userData['isAdmin'] == true ||
            userData['role'] == 'admin' ||
            userData['admin'] == true;

        if (mounted) {
          setState(() {
            _isAdmin = isAdmin;
            _checkingAdmin = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _checkingAdmin = false;
          });
        }
      }
    } catch (e) {
      debugPrint('MenuScreen: Error checking admin: $e');
      if (mounted) {
        setState(() {
          _checkingAdmin = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // CRITICAL: Explicit background color to prevent black screen during transitions
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        children: [
          _MenuTile(
            icon: Icons.person_outline,
            title: 'My Profile',
            onTap: () {
              locator<NavigationService>().navigateNamed(
                AppRoutes.profile,
                arguments: {'userId': FirebaseAuth.instance.currentUser!.uid},
              );
            },
          ),
          _MenuTile(
              icon: Icons.storefront_outlined,
              title: 'Store',
              onTap: () {
                locator<NavigationService>().navigateNamed(AppRoutes.store);
              }),
          _MenuTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              locator<NavigationService>().navigateNamed(AppRoutes.settings);
            },
          ),
          _MenuTile(
            icon: Icons.school_outlined,
            title: 'Feature Discovery',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FeatureDiscoveryScreen(),
                ),
              );
            },
          ),
          if (_isAdmin && !_checkingAdmin) ...[
            const Divider(height: 32),
            _MenuTile(
              icon: Icons.gavel,
              title: 'Moderation Dashboard',
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ModerationDashboardScreen(),
                  ),
                );
              },
            ),
          ],
          const Divider(height: 32),
          // Keep Logout
          _MenuTile(
            icon: Icons.logout,
            title: 'Logout',
            color: Theme.of(context).colorScheme.error,
            onTap: () async {
              // Store a reference to the AuthBloc before showing the dialog
              final authBloc = context.read<AuthBloc>();

              // Show confirmation dialog with professional animation
              final confirmed =
                  await locator<NavigationService>().showDialogWithFade<bool>(
                child: AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          locator<NavigationService>().goBack(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () =>
                          locator<NavigationService>().goBack(true),
                      child: Text(
                        'Logout',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                // Show spinner immediately by emitting Unauthenticated first
                authBloc.add(SignOut());

                // Show immediate feedback with a spinner overlay
                // The dialog will be automatically closed when AuthWrapper navigates
                if (context.mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => WillPopScope(
                      onWillPop: () async => false, // Prevent closing
                      child: BlocListener<AuthBloc, AuthState>(
                        listener: (context, state) {
                          // Close dialog when sign out completes
                          if (state is Unauthenticated) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Center(
                          child: AppProgressIndicator(),
                        ),
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

// _MenuTile widget remains the same
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = color ?? Theme.of(context).textTheme.bodyLarge?.color;
    return ListTile(
      leading: Icon(icon, color: tileColor),
      title: Text(
        title,
        style:
            Theme.of(context).textTheme.titleMedium?.copyWith(color: tileColor),
      ),
      onTap: onTap,
    );
  }
}
