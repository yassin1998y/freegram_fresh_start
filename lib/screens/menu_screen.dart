import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/screens/settings_screen.dart';

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
              // Navigate to Profile screen using root navigator
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                    userId: FirebaseAuth.instance.currentUser!.uid,
                  ),
                ),
              );
            },
          ),
          _MenuTile(icon: Icons.storefront_outlined, title: 'Store', onTap: () {/* Navigate to StoreScreen */}),
          _MenuTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              // Navigate to Settings screen using root navigator
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          const Divider(height: 32),
          // Keep Logout
          _MenuTile(
            icon: Icons.logout,
            title: 'Logout',
            color: Theme.of(context).colorScheme.error,
            onTap: () {
              // Store a reference to the AuthBloc before showing the dialog
              final authBloc = context.read<AuthBloc>();
              
              // Show confirmation dialog before logging out
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        // Dismiss the dialog
                        Navigator.of(dialogContext).pop();
                        // Trigger the AuthBloc's SignOut event using the stored reference
                        // The AuthWrapper will automatically show LoginScreen when state becomes Unauthenticated
                        authBloc.add(SignOut());
                      },
                      child: Text(
                        'Logout',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              );
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
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: tileColor),
      ),
      onTap: onTap,
    );
  }
}