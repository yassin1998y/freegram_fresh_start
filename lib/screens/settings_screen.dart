import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/widgets/freegram_app_bar.dart';
import 'package:freegram/widgets/common/keyboard_safe_area.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/screens/notification_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.updatePassword(_newPasswordController.text);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully!'),
            backgroundColor: SemanticColors.success,
          ),
        );
        navigator.pop();
      } else {
        throw Exception("You are not logged in.");
      }
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.message ?? "Could not update password."}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 SCREEN: settings_screen.dart');
    return Scaffold(
      // CRITICAL: Explicit background color to prevent black screen during transitions
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: const FreegramAppBar(
        title: 'Settings',
        showBackButton: true,
      ),
      body: KeyboardSafeArea(
        child: ListView(
          padding: const EdgeInsets.all(DesignTokens.spaceMD),
          children: [
            _buildSectionHeader(context, 'Account'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Change Password',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: DesignTokens.spaceMD),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New Password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: DesignTokens.spaceMD),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm New Password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value != _newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: DesignTokens.spaceMD),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: DesignTokens.spaceMD,
                          ),
                        ),
                        child: _isLoading
                            ? const AppProgressIndicator(
                                size: DesignTokens.iconLG,
                                strokeWidth: 2,
                              )
                            : const Text('Update Password'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: DesignTokens.spaceXL),
            _buildSectionHeader(context, 'Preferences'),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Manage Notifications',
              subtitle: 'Control push notification preferences',
              onTap: () {
                locator<NavigationService>().navigateTo(
                  const NotificationSettingsScreen(),
                  transition: PageTransition.slide,
                );
              },
            ),
            _SettingsTile(
              icon: Icons.palette_outlined,
              title: 'Appearance',
              subtitle: 'Light / Dark Mode',
              onTap: () {
                // Placeholder for future implementation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Theme settings coming soon!')),
                );
              },
            ),
            const Divider(height: DesignTokens.spaceXL),
            _buildSectionHeader(context, 'About'),
            _SettingsTile(
              icon: Icons.shield_outlined,
              title: 'Privacy Policy',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spaceSM),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
