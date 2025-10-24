import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/routes.dart'; // Keep routes import

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the NavigatorState from the main shell's Navigator.
    // Use RootNavigator=false to push within the nested navigator.
    final shellNavigator = Navigator.of(context, rootNavigator: false);

    return Scaffold(
      // Keep AppBar for consistency, or remove if not desired in menu
      appBar: AppBar(
        title: const Text('Menu'),
        automaticallyImplyLeading: false, // No back button needed here
      ),
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
          // Remove Tiles for deleted features:
          // _MenuTile(icon: Icons.inventory_2_outlined, title: 'Inventory', onTap: () {/* Navigate to InventoryScreen */}),
          // _MenuTile(icon: Icons.leaderboard_outlined, title: 'Leaderboard', onTap: () {/* Navigate to LeaderboardScreen */}),
          // _MenuTile(icon: Icons.task_alt_outlined, title: 'Tasks', onTap: () {/* Navigate to TasksScreen */}),
          // _MenuTile(icon: Icons.military_tech_outlined, title: 'Season Pass', onTap: () {/* Navigate to LevelPassScreen */}),
          _MenuTile(icon: Icons.storefront_outlined, title: 'Store', onTap: () {/* Navigate to StoreScreen */}),
          // Keep Settings
          _MenuTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              // Navigate to the Settings screen within the main shell
              shellNavigator.pushNamed(settingsRoute);
            },
          ),
          const Divider(height: 32),
          // Keep Logout
          _MenuTile(
            icon: Icons.logout,
            title: 'Logout',
            color: Theme.of(context).colorScheme.error,
            onTap: () {
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
                        // Trigger the AuthBloc's SignOut event
                        // Use read for context available actions
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