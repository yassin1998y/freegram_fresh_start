// lib/widgets/reels/reels_settings_tab.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

class ReelsSettingsTab extends StatelessWidget {
  const ReelsSettingsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      color: Colors.black,
      child: ListView(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        children: [
          // Settings Header
          Padding(
            padding: const EdgeInsets.only(bottom: DesignTokens.spaceLG),
            child: Text(
              'Reels Settings',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Playback Settings
          _SettingsSection(
            title: 'Playback',
            children: [
              _SettingsSwitchTile(
                title: 'Auto-play videos',
                subtitle: 'Automatically play videos when scrolled into view',
                value: true,
                onChanged: (value) {
                  // TODO: Implement settings persistence
                },
              ),
              _SettingsSwitchTile(
                title: 'Mute by default',
                subtitle: 'Start videos muted',
                value: false,
                onChanged: (value) {
                  // TODO: Implement settings persistence
                },
              ),
              _SettingsSwitchTile(
                title: 'Loop videos',
                subtitle: 'Automatically replay videos',
                value: true,
                onChanged: (value) {
                  // TODO: Implement settings persistence
                },
              ),
            ],
          ),

          // Privacy Settings
          _SettingsSection(
            title: 'Privacy',
            children: [
              _SettingsSwitchTile(
                title: 'Allow comments',
                subtitle: 'Let others comment on your reels',
                value: true,
                onChanged: (value) {
                  // TODO: Implement settings persistence
                },
              ),
              _SettingsSwitchTile(
                title: 'Allow duets/remixes',
                subtitle: 'Let others create duets with your reels',
                value: true,
                onChanged: (value) {
                  // TODO: Implement settings persistence
                },
              ),
            ],
          ),

          // Data & Storage
          _SettingsSection(
            title: 'Data & Storage',
            children: [
              _SettingsListTile(
                title: 'Video quality',
                subtitle: 'High (recommended)',
                onTap: () {
                  // TODO: Implement quality selection
                },
              ),
              _SettingsListTile(
                title: 'Clear cache',
                subtitle: 'Free up storage space',
                onTap: () {
                  // TODO: Implement cache clearing
                },
              ),
            ],
          ),

          // About
          _SettingsSection(
            title: 'About',
            children: [
              _SettingsListTile(
                title: 'Reels guidelines',
                subtitle: 'Community standards and rules',
                onTap: () {
                  // TODO: Implement guidelines view
                },
              ),
              _SettingsListTile(
                title: 'Report a problem',
                subtitle: 'Help us improve Reels',
                onTap: () {
                  // TODO: Implement problem reporting
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: DesignTokens.spaceLG,
            bottom: DesignTokens.spaceMD,
          ),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(DesignTokens.opacityMedium),
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SwitchListTile(
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.white.withOpacity(DesignTokens.opacityHigh),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: SonarPulseTheme.primaryAccent,
    );
  }
}

class _SettingsListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsListTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListTile(
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.white.withOpacity(DesignTokens.opacityHigh),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.white.withOpacity(DesignTokens.opacityMedium),
      ),
      onTap: onTap,
    );
  }
}

