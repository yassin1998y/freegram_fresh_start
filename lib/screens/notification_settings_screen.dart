// lib/screens/notification_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/notification_preferences.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/services/fcm_token_service.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/widgets/island_popup.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _isLoading = true;
  bool _allNotifications = true;

  // Social
  bool _friendRequests = true;
  bool _friendAccepted = true;
  bool _messages = true;
  bool _nearbyWaves = true;
  bool _superLikes = true;

  // Posts
  bool _likesEnabled = true;
  bool _commentsEnabled = true;
  bool _mentionsEnabled = true;

  // Reels
  bool _reelLikesEnabled = true;
  bool _reelCommentsEnabled = true;

  // System
  bool _batchingEnabled = true;

  bool _notificationsEnabled = false;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: notification_settings_screen.dart');
    _loadPreferences();
    _checkNotificationStatus();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        final prefsData = doc.data()?['notificationPreferences'];
        if (prefsData != null) {
          final prefs = NotificationPreferences.fromMap(prefsData);
          setState(() {
            _allNotifications = prefs.allNotificationsEnabled;
            _friendRequests = prefs.friendRequestsEnabled;
            _friendAccepted = prefs.friendAcceptedEnabled;
            _messages = prefs.messagesEnabled;
            _nearbyWaves = prefs.nearbyWavesEnabled;
            _superLikes = prefs.superLikesEnabled;

            _likesEnabled = prefs.likesEnabled;
            _commentsEnabled = prefs.commentsEnabled;
            _mentionsEnabled = prefs.mentionsEnabled;

            _reelLikesEnabled = prefs.reelLikesEnabled;
            _reelCommentsEnabled = prefs.reelCommentsEnabled;

            _batchingEnabled = prefs.batchingEnabled;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading preferences: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkNotificationStatus() async {
    try {
      final fcmService = locator<FcmTokenService>();
      final enabled = await fcmService.areNotificationsEnabled();
      final token = await fcmService.getCurrentToken();

      setState(() {
        _notificationsEnabled = enabled;
        _fcmToken = token;
      });
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _savePreferences() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final prefs = NotificationPreferences(
        allNotificationsEnabled: _allNotifications,
        friendRequestsEnabled: _friendRequests,
        friendAcceptedEnabled: _friendAccepted,
        messagesEnabled: _messages,
        nearbyWavesEnabled: _nearbyWaves,
        superLikesEnabled: _superLikes,
        likesEnabled: _likesEnabled,
        commentsEnabled: _commentsEnabled,
        mentionsEnabled: _mentionsEnabled,
        reelLikesEnabled: _reelLikesEnabled,
        reelCommentsEnabled: _reelCommentsEnabled,
        batchingEnabled: _batchingEnabled,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'notificationPreferences': prefs.toMap()});

      if (mounted) {
        showIslandPopup(
          context: context,
          message: 'Preferences saved',
          icon: Icons.check_circle,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: AppProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              children: [
                // Notification Status Card
                _buildStatusCard(theme),

                const SizedBox(height: DesignTokens.spaceLG),

                // Master Switch
                _buildMasterSwitch(theme),

                const SizedBox(height: DesignTokens.spaceMD),

                // Social Section
                _buildSectionHeader(theme, 'Social'),
                _buildSocialSection(theme),

                const SizedBox(height: DesignTokens.spaceMD),

                // Posts Section
                _buildSectionHeader(theme, 'Posts'),
                _buildPostsSection(theme),

                const SizedBox(height: DesignTokens.spaceMD),

                // Reels Section
                _buildSectionHeader(theme, 'Reels'),
                _buildReelsSection(theme),

                const SizedBox(height: DesignTokens.spaceMD),

                // Advanced Section
                _buildSectionHeader(theme, 'Advanced'),
                _buildAdvancedSection(theme),

                const SizedBox(height: DesignTokens.spaceLG),

                // Debug Info (only in debug mode)
                if (_fcmToken != null) _buildDebugInfo(theme),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: DesignTokens.spaceSM,
        bottom: DesignTokens.spaceSM,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Row(
          children: [
            Icon(
              _notificationsEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: _notificationsEnabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
              size: DesignTokens.iconXXL,
            ),
            const SizedBox(width: DesignTokens.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _notificationsEnabled
                        ? 'Notifications Enabled'
                        : 'Notifications Disabled',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _notificationsEnabled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceSM),
                  Text(
                    _notificationsEnabled
                        ? 'You will receive push notifications'
                        : 'Enable notifications in your device settings',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterSwitch(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      ),
      child: SwitchListTile(
        title: Text(
          'All Notifications',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Enable or disable all push notifications',
          style: theme.textTheme.bodySmall,
        ),
        value: _allNotifications,
        onChanged: _notificationsEnabled
            ? (value) {
                setState(() => _allNotifications = value);
                _savePreferences();
              }
            : null,
        activeThumbColor: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildSocialSection(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      ),
      child: Column(
        children: [
          _buildNotificationTile(
            icon: Icons.person_add,
            title: 'Friend Requests',
            subtitle: 'New friend requests',
            value: _friendRequests,
            onChanged: (value) {
              setState(() => _friendRequests = value);
              _savePreferences();
            },
            theme: theme,
          ),
          const Divider(height: 1),
          _buildNotificationTile(
            icon: Icons.check_circle,
            title: 'Friend Accepted',
            subtitle: 'When someone accepts your request',
            value: _friendAccepted,
            onChanged: (value) {
              setState(() => _friendAccepted = value);
              _savePreferences();
            },
            theme: theme,
          ),
          const Divider(height: 1),
          _buildNotificationTile(
            icon: Icons.message,
            title: 'Messages',
            subtitle: 'New private messages',
            value: _messages,
            onChanged: (value) {
              setState(() => _messages = value);
              _savePreferences();
            },
            theme: theme,
          ),
          const Divider(height: 1),
          _buildNotificationTile(
            icon: Icons.radar,
            title: 'Nearby Waves',
            subtitle: 'When someone waves at you',
            value: _nearbyWaves,
            onChanged: (value) {
              setState(() => _nearbyWaves = value);
              _savePreferences();
            },
            theme: theme,
          ),
          const Divider(height: 1),
          _buildNotificationTile(
            icon: Icons.favorite,
            title: 'Super Likes',
            subtitle: 'When someone super likes you',
            value: _superLikes,
            onChanged: (value) {
              setState(() => _superLikes = value);
              _savePreferences();
            },
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildPostsSection(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      ),
      child: Column(
        children: [
          _buildNotificationTile(
            icon: Icons.thumb_up,
            title: 'Likes',
            subtitle: 'Likes on your posts',
            value: _likesEnabled,
            onChanged: (value) {
              setState(() => _likesEnabled = value);
              _savePreferences();
            },
            theme: theme,
          ),
          const Divider(height: 1),
          _buildNotificationTile(
            icon: Icons.comment,
            title: 'Comments',
            subtitle: 'Comments on your posts',
            value: _commentsEnabled,
            onChanged: (value) {
              setState(() => _commentsEnabled = value);
              _savePreferences();
            },
            theme: theme,
          ),
          const Divider(height: 1),
          _buildNotificationTile(
            icon: Icons.alternate_email,
            title: 'Mentions',
            subtitle: 'When you are mentioned in a post',
            value: _mentionsEnabled,
            onChanged: (value) {
              setState(() => _mentionsEnabled = value);
              _savePreferences();
            },
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildReelsSection(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      ),
      child: Column(
        children: [
          _buildNotificationTile(
            icon: Icons.favorite_border,
            title: 'Reel Likes',
            subtitle: 'Likes on your reels',
            value: _reelLikesEnabled,
            onChanged: (value) {
              setState(() => _reelLikesEnabled = value);
              _savePreferences();
            },
            theme: theme,
          ),
          const Divider(height: 1),
          _buildNotificationTile(
            icon: Icons.comment_bank,
            title: 'Reel Comments',
            subtitle: 'Comments on your reels',
            value: _reelCommentsEnabled,
            onChanged: (value) {
              setState(() => _reelCommentsEnabled = value);
              _savePreferences();
            },
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSection(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      ),
      child: Column(
        children: [
          _buildNotificationTile(
            icon: Icons.group_work,
            title: 'Smart Batching',
            subtitle:
                'Group notifications to reduce spam (e.g. "5 people liked...")',
            value: _batchingEnabled,
            onChanged: (value) {
              setState(() => _batchingEnabled = value);
              _savePreferences();
            },
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
  }) {
    final isEnabled = _allNotifications && _notificationsEnabled;

    return SwitchListTile(
      secondary: Icon(
        icon,
        color: isEnabled ? theme.colorScheme.primary : theme.disabledColor,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isEnabled ? null : theme.disabledColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isEnabled ? null : theme.disabledColor,
        ),
      ),
      value: value,
      onChanged: isEnabled ? onChanged : null,
      activeThumbColor: theme.colorScheme.primary,
    );
  }

  Widget _buildDebugInfo(ThemeData theme) {
    return Card(
      elevation: 1,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      ),
      child: ExpansionTile(
        title: Text(
          'Debug Information',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(DesignTokens.spaceMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FCM Token:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceSM),
                SelectableText(
                  _fcmToken ?? 'No token available',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceMD),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final userId = FirebaseAuth.instance.currentUser?.uid;
                      if (userId == null) {
                        if (mounted) {
                          showIslandPopup(
                            context: context,
                            message: 'User not authenticated',
                            icon: Icons.error,
                          );
                        }
                        return;
                      }
                      final fcmService = locator<FcmTokenService>();
                      await fcmService.updateTokenOnLogin(userId);
                      await _checkNotificationStatus();
                      if (mounted) {
                        showIslandPopup(
                          context: context,
                          message: 'FCM token refreshed',
                          icon: Icons.refresh,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error refreshing token: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.refresh, size: DesignTokens.iconMD),
                  label: const Text('Refresh Token'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
