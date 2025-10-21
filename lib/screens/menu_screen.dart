import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/routes.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the NavigatorState from the main shell's Navigator.
    // We use RootNavigator=false to ensure we push within our nested navigator.
    final shellNavigator = Navigator.of(context, rootNavigator: false);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        children: [
          _MenuTile(
            icon: Icons.person_outline,
            title: 'My Profile',
            onTap: () {
              // Navigate to the Profile screen within the main shell
              shellNavigator.pushNamed(profileRoute);
            },
          ),
          _MenuTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              // Navigate to the Settings screen within the main shell
              shellNavigator.pushNamed(settingsRoute);
            },
          ),
          const Divider(height: 32),
          _MenuTile(
            icon: Icons.logout,
            title: 'Logout',
            color: Theme.of(context).colorScheme.error,
            onTap: () {
              // Show a confirmation dialog before logging out
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
                        // Trigger the AuthBloc's SignOut event
                        context.read<AuthBloc>().add(SignOut());
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