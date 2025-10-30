import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/improved_chat_screen.dart';
import 'package:freegram/screens/edit_profile_screen.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/screens/qr_display_screen.dart';
import 'package:freegram/utils/mutual_friends_helper.dart';

class ProfileScreen extends StatelessWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Keep FriendsBloc for friend status actions
    return BlocProvider(
      create: (context) => FriendsBloc(
        userRepository: locator<UserRepository>(),
      )..add(LoadFriends()),
      child: _ProfileScreenView(userId: userId),
    );
  }
}

class _ProfileScreenView extends StatefulWidget {
  final String userId;
  const _ProfileScreenView({required this.userId});

  @override
  State<_ProfileScreenView> createState() => _ProfileScreenViewState();
}

// Removed SingleTickerProviderStateMixin as TabController is removed
class _ProfileScreenViewState extends State<_ProfileScreenView> {
  // Removed TabController initialization and disposal

  Future<void> _startChat(BuildContext context, UserModel user) async {
    final chatId = await locator<ChatRepository>().startOrGetChat(
      user.id,
      user.username,
    );
    if (mounted) {
      locator<NavigationService>().navigateTo(
        ImprovedChatScreen(
          chatId: chatId,
          otherUsername: user.username,
        ),
        transition: PageTransition.slide,
      );
    }
  }

  void _showProfileOptions(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.block_outlined,
                      color: theme.colorScheme.error,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Block User',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(bottomSheetContext);
                    _confirmBlockUser(context, user);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmBlockUser(BuildContext context, UserModel user) async {
    final bool? shouldBlock = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Block User?'),
          content: Text(
            'Are you sure you want to block ${user.username}? They won\'t be able to message you or see your profile.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Block',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );

    if (shouldBlock == true && mounted) {
      HapticFeedback.mediumImpact();

      // Block user
      context.read<FriendsBloc>().add(BlockUser(user.id));

      // Listen for success/error
      final subscription = context.read<FriendsBloc>().stream.listen((state) {
        if (state is FriendsActionSuccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${user.username} has been blocked.'),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );

            // Reload friends data to reflect changes
            context.read<FriendsBloc>().add(LoadFriends());

            // Navigate back after a short delay
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            });
          }
        } else if (state is FriendsActionError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
            // Don't navigate back on error
          }
        }
      });

      // Cancel subscription after handling one event
      Future.delayed(const Duration(seconds: 5), () {
        subscription.cancel();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRepository = locator<UserRepository>();
    // final postRepository = locator<PostRepository>(); // Remove PostRepository instance
    final isCurrentUserProfile =
        FirebaseAuth.instance.currentUser?.uid == widget.userId;

    return Scaffold(
      body: StreamBuilder<UserModel>(
        stream: userRepository.getUserStream(widget.userId),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData) {
            return const Center(child: Text('User not found.'));
          }
          if (userSnapshot.hasError) {
            return Center(child: Text('Error: ${userSnapshot.error}'));
          }

          final user = userSnapshot.data!;

          // Modern CustomScrollView with professional design
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                // Match FreegramAppBar branding style
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Full "Freegram" branding
                    Text(
                      'Freegram',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: SonarPulseTheme.primaryAccent,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 2,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                centerTitle: true,
                floating: true,
                pinned: true,
                expandedHeight: 0, // No extra height
                actions: [
                  if (isCurrentUserProfile)
                    IconButton(
                      icon: const Icon(Icons.qr_code_2_outlined),
                      tooltip: 'My QR Code',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        locator<NavigationService>().navigateTo(
                          QrDisplayScreen(user: user),
                          transition: PageTransition.scale,
                        );
                      },
                    )
                  else
                    // Options menu for other users
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded),
                      tooltip: 'More options',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _showProfileOptions(context, user);
                      },
                    ),
                  const SizedBox(width: 4),
                ],
              ),
              SliverToBoxAdapter(
                child: _ModernProfileHeader(
                  user: user,
                  isCurrentUserProfile: isCurrentUserProfile,
                  onStartChat: () => _startChat(context, user),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

// Removed _buildPostsGrid method
}

/// Modern profile header with professional UX and card-based layout
class _ModernProfileHeader extends StatelessWidget {
  final UserModel user;
  final bool isCurrentUserProfile;
  final VoidCallback onStartChat;

  const _ModernProfileHeader({
    required this.user,
    required this.isCurrentUserProfile,
    required this.onStartChat,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Hero Section - Avatar and Name
        _buildHeroSection(context),

        SizedBox(height: DesignTokens.spaceXL),

        // Action Buttons
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
          child: isCurrentUserProfile
              ? _buildCurrentUserActions(context)
              : _buildOtherUserActions(context),
        ),

        SizedBox(height: DesignTokens.spaceXL),

        // Stats Card
        _buildStatsCard(context),

        SizedBox(height: DesignTokens.spaceMD),

        // Mutual Friends/Interests Card (for other users)
        if (!isCurrentUserProfile)
          BlocBuilder<FriendsBloc, FriendsState>(
            builder: (context, state) {
              if (state is FriendsLoaded) {
                return _buildMutualConnectionsCard(context, state.user);
              }
              return const SizedBox.shrink();
            },
          ),

        if (!isCurrentUserProfile) SizedBox(height: DesignTokens.spaceMD),

        // Bio Card (if available)
        if (user.bio.isNotEmpty) ...[
          _buildBioCard(context),
          SizedBox(height: DesignTokens.spaceMD),
        ],

        // Info Card
        _buildInfoCard(context),

        SizedBox(height: DesignTokens.spaceMD),

        // Interests Card (if available)
        if (user.interests.isNotEmpty) ...[
          _buildInterestsCard(context),
          SizedBox(height: DesignTokens.spaceMD),
        ],

        SizedBox(height: DesignTokens.spaceXL),
      ],
    );
  }

  /// Hero section with centered avatar and username
  Widget _buildHeroSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.spaceXL),
      child: Column(
        children: [
          // Profile Avatar
          Hero(
            tag: 'profile_${user.id}',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: SonarPulseTheme.primaryAccent.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: user.photoUrl.isNotEmpty
                    ? CachedNetworkImageProvider(user.photoUrl)
                    : null,
                child: user.photoUrl.isEmpty
                    ? Text(
                        user.username.isNotEmpty
                            ? user.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ),

          SizedBox(height: DesignTokens.spaceMD),

          // Username
          Text(
            user.username,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
            textAlign: TextAlign.center,
          ),

          if (user.country.isNotEmpty) ...[
            SizedBox(height: DesignTokens.spaceSM),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                SizedBox(width: DesignTokens.spaceXS),
                Text(
                  user.country,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Action buttons for current user (Edit Profile)
  Widget _buildCurrentUserActions(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        HapticFeedback.lightImpact();
        locator<NavigationService>().navigateTo(
          EditProfileScreen(currentUserData: user.toMap()),
          transition: PageTransition.slide,
        );
      },
      icon: const Icon(Icons.edit_outlined, size: 20),
      label: const Text('Edit Profile'),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceLG,
          vertical: DesignTokens.spaceMD,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        ),
      ),
    );
  }

  /// Action buttons for other users (Add Friend, Message, etc.)
  Widget _buildOtherUserActions(BuildContext context) {
    // ⭐ FIX: Use BlocConsumer to handle transient states without showing spinner
    return BlocConsumer<FriendsBloc, FriendsState>(
      listener: (context, state) {
        // Handle transient success/error states with snackbars
        if (state is FriendsActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (state is FriendsActionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      buildWhen: (previous, current) {
        // Only rebuild for loaded states, ignore transient states
        return current is FriendsLoaded ||
            current is FriendsInitial ||
            current is FriendsLoading ||
            current is FriendsError;
      },
      builder: (context, state) {
        if (state is FriendsLoaded) {
          final currentUser = state.user;
          bool isFriend = currentUser.friends.contains(user.id);
          bool requestSent = currentUser.friendRequestsSent.contains(user.id);
          bool requestReceived =
              currentUser.friendRequestsReceived.contains(user.id);
          bool isBlocked = currentUser.blockedUsers.contains(user.id);

          if (isBlocked) {
            return OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.read<FriendsBloc>().add(UnblockUser(user.id));
              },
              icon: const Icon(Icons.block_outlined, size: 20),
              label: const Text('Unblock'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceLG,
                  vertical: DesignTokens.spaceMD,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                ),
              ),
            );
          }

          if (requestReceived) {
            return ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.read<FriendsBloc>().add(AcceptFriendRequest(user.id));
              },
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Accept Friend Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceLG,
                  vertical: DesignTokens.spaceMD,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                ),
              ),
            );
          }

          return Row(
            children: [
              Expanded(
                child: isFriend || requestSent
                    ? OutlinedButton.icon(
                        onPressed: isFriend
                            ? () {
                                HapticFeedback.lightImpact();
                                _confirmRemoveFriend(context);
                              }
                            : null,
                        icon: Icon(
                          isFriend ? Icons.check : Icons.schedule,
                          size: 20,
                        ),
                        label: Text(isFriend ? 'Friends' : 'Pending'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceMD,
                            vertical: DesignTokens.spaceMD,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusMD),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context
                              .read<FriendsBloc>()
                              .add(SendFriendRequest(user.id));
                        },
                        icon: const Icon(Icons.person_add_outlined, size: 20),
                        label: const Text('Add Friend'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceMD,
                            vertical: DesignTokens.spaceMD,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusMD),
                          ),
                        ),
                      ),
              ),
              SizedBox(width: DesignTokens.spaceMD),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onStartChat();
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceMD,
                      vertical: DesignTokens.spaceMD,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMD),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Only show loading spinner for initial load or actual loading state
        if (state is FriendsLoading || state is FriendsInitial) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        // For error state, show a simplified button layout
        return ElevatedButton.icon(
          onPressed: null, // Disabled
          icon: const Icon(Icons.error_outline, size: 20),
          label: const Text('Unable to load'),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceLG,
              vertical: DesignTokens.spaceMD,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            ),
          ),
        );
      },
    );
  }

  // _confirmRemoveFriend remains the same
  Future<void> _confirmRemoveFriend(BuildContext context) async {
    final bool? shouldRemove = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Friend?'),
          content: Text(
              'Are you sure you want to remove ${user.username} as a friend?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldRemove == true) {
      context.read<FriendsBloc>().add(RemoveFriend(user.id));
    }
  }

  /// Stats card with friends count
  Widget _buildStatsCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
      padding: EdgeInsets.all(DesignTokens.spaceLG),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            icon: Icons.people_outline,
            label: 'Friends',
            value: user.friends.length.toString(),
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).dividerColor,
          ),
          _buildStatItem(
            context,
            icon: Icons.cake_outlined,
            label: 'Age',
            value: user.age > 0 ? user.age.toString() : 'N/A',
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).dividerColor,
          ),
          _buildStatItem(
            context,
            icon: user.gender.toLowerCase() == 'male'
                ? Icons.man_outlined
                : user.gender.toLowerCase() == 'female'
                    ? Icons.woman_outlined
                    : Icons.person_outline,
            label: 'Gender',
            value: user.gender.isNotEmpty ? user.gender : 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 28,
          color: SonarPulseTheme.primaryAccent,
        ),
        SizedBox(height: DesignTokens.spaceXS),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: DesignTokens.spaceXS),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
        ),
      ],
    );
  }

  /// Bio card
  Widget _buildBioCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
      padding: EdgeInsets.all(DesignTokens.spaceLG),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: SonarPulseTheme.primaryAccent,
              ),
              SizedBox(width: DesignTokens.spaceSM),
              Text(
                'About',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.spaceMD),
          Text(
            user.bio,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// Info card with personal details
  Widget _buildInfoCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
      padding: EdgeInsets.all(DesignTokens.spaceLG),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.badge_outlined,
                size: 20,
                color: SonarPulseTheme.primaryAccent,
              ),
              SizedBox(width: DesignTokens.spaceSM),
              Text(
                'Information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.spaceMD),
          _buildInfoRow(
            context,
            icon: Icons.person_outline,
            label: 'Username',
            value: user.username,
          ),
          if (user.age > 0) ...[
            SizedBox(height: DesignTokens.spaceSM),
            _buildInfoRow(
              context,
              icon: Icons.cake_outlined,
              label: 'Age',
              value: user.age.toString(),
            ),
          ],
          if (user.gender.isNotEmpty) ...[
            SizedBox(height: DesignTokens.spaceSM),
            _buildInfoRow(
              context,
              icon: user.gender.toLowerCase() == 'male'
                  ? Icons.man_outlined
                  : user.gender.toLowerCase() == 'female'
                      ? Icons.woman_outlined
                      : Icons.person_outline,
              label: 'Gender',
              value: user.gender,
            ),
          ],
          if (user.country.isNotEmpty) ...[
            SizedBox(height: DesignTokens.spaceSM),
            _buildInfoRow(
              context,
              icon: Icons.location_on_outlined,
              label: 'Country',
              value: user.country,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        SizedBox(width: DesignTokens.spaceSM),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
        ),
        SizedBox(width: DesignTokens.spaceXS),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }

  /// Mutual friends and interests card
  Widget _buildMutualConnectionsCard(
      BuildContext context, UserModel currentUser) {
    final mutualFriendsCount = MutualFriendsHelper.getMutualFriendsCount(
        currentUser.friends, user.friends);
    final mutualInterests = MutualFriendsHelper.getMutualInterests(
        currentUser.interests, user.interests);

    if (mutualFriendsCount == 0 && mutualInterests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
      padding: EdgeInsets.all(DesignTokens.spaceLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SonarPulseTheme.primaryAccent.withOpacity(0.1),
            SonarPulseTheme.primaryAccent.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        border: Border.all(
          color: SonarPulseTheme.primaryAccent.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite,
                size: 20,
                color: SonarPulseTheme.primaryAccent,
              ),
              SizedBox(width: DesignTokens.spaceSM),
              Text(
                'You Have in Common',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: SonarPulseTheme.primaryAccent,
                    ),
              ),
            ],
          ),

          SizedBox(height: DesignTokens.spaceMD),

          // Mutual friends
          if (mutualFriendsCount > 0) ...[
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                SizedBox(width: DesignTokens.spaceSM),
                Text(
                  MutualFriendsHelper.formatMutualFriendsText(
                      mutualFriendsCount),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ],

          // Mutual interests
          if (mutualInterests.isNotEmpty) ...[
            if (mutualFriendsCount > 0) SizedBox(height: DesignTokens.spaceMD),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.interests,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                SizedBox(width: DesignTokens.spaceSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        MutualFriendsHelper.formatMutualInterestsText(
                            mutualInterests),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      SizedBox(height: DesignTokens.spaceSM),
                      Wrap(
                        spacing: DesignTokens.spaceSM,
                        runSpacing: DesignTokens.spaceSM,
                        children: mutualInterests.take(5).map((interest) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceMD,
                              vertical: DesignTokens.spaceXS,
                            ),
                            decoration: BoxDecoration(
                              color: SonarPulseTheme.primaryAccent
                                  .withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusSM),
                            ),
                            child: Text(
                              interest,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: SonarPulseTheme.primaryAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (mutualInterests.length > 5) ...[
                        SizedBox(height: DesignTokens.spaceXS),
                        Text(
                          '+${mutualInterests.length - 5} more',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Interests card
  Widget _buildInterestsCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: DesignTokens.spaceLG),
      padding: EdgeInsets.all(DesignTokens.spaceLG),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite_outline,
                size: 20,
                color: SonarPulseTheme.primaryAccent,
              ),
              SizedBox(width: DesignTokens.spaceSM),
              Text(
                'Interests',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          SizedBox(height: DesignTokens.spaceMD),
          Wrap(
            spacing: DesignTokens.spaceSM,
            runSpacing: DesignTokens.spaceSM,
            children: user.interests.map((interest) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMD,
                  vertical: DesignTokens.spaceSM,
                ),
                decoration: BoxDecoration(
                  color: SonarPulseTheme.primaryAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                  border: Border.all(
                    color: SonarPulseTheme.primaryAccent.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  interest,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SonarPulseTheme.primaryAccent,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
