// lib/screens/notification_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/notification_preferences.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/services/fcm_token_service.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/widgets/island_popup.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/theme/app_theme.dart';

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
        left: 4,
        bottom: DesignTokens.spaceSM,
      ),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: SemanticColors.textSecondary(context),
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Row(
          children: [
            Icon(
              _notificationsEnabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: _notificationsEnabled
                  ? SonarPulseTheme.primaryAccent
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
                        ? 'Notifications Active'
                        : 'Notifications Restricted',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _notificationsEnabled
                          ? SonarPulseTheme.primaryAccent
                          : theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _notificationsEnabled
                        ? 'System notifications are currently enabled'
                        : 'Enable notifications in device settings',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: SemanticColors.textSecondary(context),
                    ),
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
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: SwitchListTile.adaptive(
        title: Text(
          'Master Shield',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Enable or disable all notifications',
          style: theme.textTheme.bodySmall?.copyWith(
            color: SemanticColors.textSecondary(context),
          ),
        ),
        value: _allNotifications,
        onChanged: _notificationsEnabled
            ? (value) {
                HapticFeedback.selectionClick();
                setState(() => _allNotifications = value);
                _savePreferences();
              }
            : null,
        activeColor: SonarPulseTheme.primaryAccent,
        activeTrackColor: SonarPulseTheme.primaryAccent.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildSocialSection(ThemeData theme) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          _buildNotificationTile(
            icon: Icons.person_add_outlined,
            title: 'Friend Requests',
            subtitle: 'New incoming friend requests',
            value: _friendRequests,
            onChanged: (value) {
              setState(() => _friendRequests = value);
              _savePreferences();
            },
            theme: theme,
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
          _buildNotificationTile(
            icon: Icons.check_circle_outline,
            title: 'Request Accepted',
            subtitle: 'When someone accepts your request',
            value: _friendAccepted,
            onChanged: (value) {
              setState(() => _friendAccepted = value);
              _savePreferences();
            },
            theme: theme,
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
          _buildNotificationTile(
            icon: Icons.chat_bubble_outline,
            title: 'Direct Messages',
            subtitle: 'New private messages',
            value: _messages,
            onChanged: (value) {
              setState(() => _messages = value);
              _savePreferences();
            },
            theme: theme,
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
          _buildNotificationTile(
            icon: Icons.radar,
            title: 'Nearby Waves',
            subtitle: 'When someone waves at you nearby',
            value: _nearbyWaves,
            onChanged: (value) {
              setState(() => _nearbyWaves = value);
              _savePreferences();
            },
            theme: theme,
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
          _buildNotificationTile(
            icon: Icons.favorite_outline,
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          _buildNotificationTile(
            icon: Icons.thumb_up_outlined,
            title: 'Likes',
            subtitle: 'Likes on your posts',
            value: _likesEnabled,
            onChanged: (value) {
              setState(() => _likesEnabled = value);
              _savePreferences();
            },
            theme: theme,
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
          _buildNotificationTile(
            icon: Icons.mode_comment_outlined,
            title: 'Comments',
            subtitle: 'Comments on your posts',
            value: _commentsEnabled,
            onChanged: (value) {
              setState(() => _commentsEnabled = value);
              _savePreferences();
            },
            theme: theme,
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
          _buildNotificationTile(
            icon: Icons.alternate_email,
            title: 'Mentions',
            subtitle: 'When tagged in a post',
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          _buildNotificationTile(
            icon: Icons.video_library_outlined,
            title: 'Reel Likes',
            subtitle: 'Likes on your reels',
            value: _reelLikesEnabled,
            onChanged: (value) {
              setState(() => _reelLikesEnabled = value);
              _savePreferences();
            },
            theme: theme,
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
          _buildNotificationTile(
            icon: Icons.comment_bank_outlined,
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
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: _buildNotificationTile(
        icon: Icons.auto_awesome_outlined,
        title: 'Smart Digest',
        subtitle: 'Batch notifications to reduce frequency',
        value: _batchingEnabled,
        onChanged: (value) {
          setState(() => _batchingEnabled = value);
          _savePreferences();
        },
        theme: theme,
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

    return SwitchListTile.adaptive(
      secondary: Icon(
        icon,
        color: isEnabled ? SonarPulseTheme.primaryAccent : theme.disabledColor,
        size: DesignTokens.iconLG,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isEnabled ? null : theme.disabledColor,
          fontWeight: FontWeight.w600,
          fontSize: DesignTokens.fontSizeMD,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isEnabled
              ? SemanticColors.textSecondary(context)
              : theme.disabledColor,
          fontSize: DesignTokens.fontSizeXS,
        ),
      ),
      value: value,
      onChanged: isEnabled
          ? (val) {
              HapticFeedback.lightImpact();
              onChanged(val);
            }
          : null,
      activeColor: SonarPulseTheme.primaryAccent,
      activeTrackColor: SonarPulseTheme.primaryAccent.withValues(alpha: 0.2),
    );
  }

  Widget _buildDebugInfo(ThemeData theme) {
    return Card(
      elevation: 1,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
