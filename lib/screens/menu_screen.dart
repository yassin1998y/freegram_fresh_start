import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/screens/settings_screen.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/locator.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        children: [
          _MenuTile(
            icon: Icons.person_outline,
            title: 'My Profile',
            onTap: () {
              // Navigate to Profile screen with professional transition
              locator<NavigationService>().navigateTo(
                ProfileScreen(
                  userId: FirebaseAuth.instance.currentUser!.uid,
                ),
                transition: PageTransition.slide,
              );
            },
          ),
          _MenuTile(
              icon: Icons.storefront_outlined,
              title: 'Store',
              onTap: () {/* Navigate to StoreScreen */}),
          _MenuTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              // Navigate to Settings screen with professional transition
              locator<NavigationService>().navigateTo(
                const SettingsScreen(),
                transition: PageTransition.slide,
              );
            },
          ),
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
                // Trigger the AuthBloc's SignOut event
                // The AuthWrapper will automatically handle navigation
                authBloc.add(SignOut());
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
