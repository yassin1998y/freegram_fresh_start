// lib/widgets/reels/reels_profile_preview_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/navigation/app_routes.dart';
import 'package:freegram/screens/improved_chat_screen.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/common/app_bottom_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReelsProfilePreviewBottomSheet extends StatelessWidget {
  final String userId;

  const ReelsProfilePreviewBottomSheet({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userRepository = locator<UserRepository>();

    return StreamBuilder<UserModel?>(
      stream: userRepository.getUserStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppBottomSheet(
            isDraggable: true,
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            showDragHandle: true,
            isComplexLayout: false,
            padding: EdgeInsets.zero,
            child: Center(
              child: AppProgressIndicator(
                color: SonarPulseTheme.primaryAccent,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.hasError) {
          return AppBottomSheet(
            isDraggable: true,
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            showDragHandle: true,
            isComplexLayout: false,
            padding: EdgeInsets.zero,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: DesignTokens.iconXXL,
                  ),
                  const SizedBox(height: DesignTokens.spaceMD),
                  Text(
                    'Unable to load profile',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        final user = snapshot.data!;

        return AppBottomSheet(
          isDraggable: true,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          showDragHandle: true,
          isComplexLayout: false,
          padding: const EdgeInsets.all(DesignTokens.spaceLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Row(
                children: [
                  // Avatar
                  Hero(
                    tag: 'profile_preview_${user.id}',
                    child: CircleAvatar(
                      radius: AvatarSize.large.size / 2,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: user.photoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(user.photoUrl)
                          : null,
                      child: user.photoUrl.isEmpty
                          ? Text(
                              user.username.isNotEmpty
                                  ? user.username[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: DesignTokens.fontSizeXXL,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceMD),
                  // Username and info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (user.country.isNotEmpty) ...[
                          const SizedBox(height: DesignTokens.spaceXS),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: DesignTokens.iconSM,
                                color: theme.colorScheme.onSurface.withValues(
                                    alpha: DesignTokens.opacityMedium),
                              ),
                              const SizedBox(width: DesignTokens.spaceXS),
                              Text(
                                user.country,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                      alpha: DesignTokens.opacityMedium),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Close button
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceLG),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                        locator<NavigationService>().navigateNamed(
                          AppRoutes.profile,
                          arguments: {'userId': user.id},
                        );
                      },
                      icon: const Icon(
                        Icons.person_outline,
                        size: DesignTokens.iconMD,
                      ),
                      label: const Text('View Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SonarPulseTheme.primaryAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: DesignTokens.spaceMD,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusMD,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceMD),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        try {
                          final chatId =
                              await locator<ChatRepository>().startOrGetChat(
                            user.id,
                            user.username,
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            locator<NavigationService>().navigateTo(
                              ImprovedChatScreen(
                                chatId: chatId,
                                otherUsername: user.username,
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint(
                              'ReelsProfilePreviewBottomSheet: Error starting chat: $e');
                        }
                      },
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        size: DesignTokens.iconMD,
                      ),
                      label: const Text('Message'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: DesignTokens.spaceMD,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusMD,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceLG),
              // Stats
              Container(
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
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
                      height: 30,
                      color: theme.dividerColor,
                    ),
                    _buildStatItem(
                      context,
                      icon: Icons.cake_outlined,
                      label: 'Age',
                      value: user.age > 0 ? user.age.toString() : 'N/A',
                    ),
                  ],
                ),
              ),
              // Bio
              if (user.bio.isNotEmpty) ...[
                const SizedBox(height: DesignTokens.spaceMD),
                Container(
                  padding: const EdgeInsets.all(DesignTokens.spaceMD),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceSM),
                      Text(
                        user.bio,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
              // Interests
              if (user.interests.isNotEmpty) ...[
                const SizedBox(height: DesignTokens.spaceMD),
                Container(
                  padding: const EdgeInsets.all(DesignTokens.spaceMD),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interests',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceSM),
                      Wrap(
                        spacing: DesignTokens.spaceSM,
                        runSpacing: DesignTokens.spaceSM,
                        children: user.interests.take(6).map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceMD,
                              vertical: DesignTokens.spaceXS,
                            ),
                            decoration: BoxDecoration(
                              color: SonarPulseTheme.primaryAccent
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                DesignTokens.radiusSM,
                              ),
                              border: Border.all(
                                color: SonarPulseTheme.primaryAccent
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              interest,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: SonarPulseTheme.primaryAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          icon,
          size: DesignTokens.iconLG,
          color: SonarPulseTheme.primaryAccent,
        ),
        const SizedBox(height: DesignTokens.spaceXS),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: DesignTokens.spaceXS / 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(
              alpha: DesignTokens.opacityMedium,
            ),
          ),
        ),
      ],
    );
  }
}
